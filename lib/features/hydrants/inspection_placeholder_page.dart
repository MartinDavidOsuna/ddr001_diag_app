import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/report_type_labels.dart';
import '../../core/location/coordinate_conversion_service.dart';
import '../../core/location/location_service.dart';
import '../../core/media/reliable_photo_service.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/catalogs/f02a_catalogs.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/inspections/visual_inspection.dart';
import '../../domain/inspections/visual_inspection_step_validator.dart';
import '../../domain/media/inspection_photo.dart';
import '../../domain/media/media_sync_status.dart';
import '../../domain/functional/functional_models.dart';

class InspectionPlaceholderPage extends StatefulWidget {
  const InspectionPlaceholderPage({
    required this.hydrantId,
    required this.type,
    super.key,
  });
  final String hydrantId, type;
  @override
  State<InspectionPlaceholderPage> createState() =>
      _InspectionPlaceholderPageState();
}

class _InspectionPlaceholderPageState extends State<InspectionPlaceholderPage> {
  VisualInspection? inspection;
  bool loading = true, dirty = false, saving = false;
  String? error;
  List<InspectionValidationError> validationErrors = [];
  final ScrollController _scrollController = ScrollController();
  double? dragStart;

  static const titles = [
    'Identificación',
    'Ubicación y georreferencia',
    'Acceso',
    'Medidor de caudal',
    'Válvula reductora y solenoide',
    'Energía y comunicaciones',
    'Estado físico y daños',
    'Fotografías y cierre',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.type != 'a') {
      setState(() => loading = false);
      return;
    }
    final state = context.read<AppState>();
    final value = await state.visualInspectionRepository.openOrCreate(
      state.hydrant(widget.hydrantId),
      state.user,
    );
    await state.trace(
      'draft_recovered',
      'Borrador de ${ReportTypeLabels.visualFull} abierto',
      hydrantId: widget.hydrantId,
    );
    if (mounted) {
      setState(() {
        inspection = value;
        loading = false;
      });
    }
  }

  void _setSectionValue(String section, String key, Object? value) {
    final json = inspection!.toJson();
    if (section == 'root') {
      json[key] = value;
    } else {
      final nested = Map<String, dynamic>.from(json[section] as Map? ?? {});
      nested[key] = value;
      json[section] = nested;
    }
    json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    setState(() {
      inspection = VisualInspection.fromJson(json);
      dirty = true;
      error = null;
      validationErrors = [];
    });
  }

  Future<void> _save({int? nextStep}) async {
    final state = context.read<AppState>();
    setState(() => saving = true);
    final updated = inspection!.copyWith(
      currentStep: nextStep ?? inspection!.currentStep,
    );
    await state.visualInspectionRepository.save(updated);
    await state.trace(
      'inspection_step_saved',
      'Paso ${updated.currentStep} guardado',
      hydrantId: widget.hydrantId,
    );
    if (mounted) {
      setState(() {
        inspection = updated;
        dirty = false;
        saving = false;
      });
    }
  }

  Future<void> _back() async {
    if (dirty) {
      final leave =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Guardar cambios'),
              content: const Text(
                'Los cambios se guardarán como borrador antes de regresar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Continuar aquí'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Guardar y regresar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!leave || !mounted) return;
      await _save();
    }
    if (!mounted) return;
    if (inspection != null && inspection!.currentStep > 1) {
      await _save(nextStep: inspection!.currentStep - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/hydrants/${widget.hydrantId}');
    }
  }

  Future<void> _next() async {
    final state = context.read<AppState>();
    final validator = VisualInspectionStepValidator.fromHive(inspection!);
    final currentResult = validator.validateStep(
      inspection!,
      inspection!.currentStep,
    );
    if (!currentResult.isValid) {
      await _save();
      if (!mounted) return;
      setState(() => validationErrors = currentResult.errors);
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    if (inspection!.currentStep < 8) {
      await _save(nextStep: inspection!.currentStep + 1);
      return;
    }
    final globalResult = validator.validateAll(inspection!);
    if (!globalResult.isValid) {
      await state.trace(
        'visual_report_finish_failed',
        'Intento de finalización con datos incompletos',
        hydrantId: widget.hydrantId,
      );
      if (!mounted) return;
      setState(() => validationErrors = globalResult.errors);
      return;
    }
    setState(() => saving = true);
    final json = inspection!.toJson();
    json['status'] = InspectionStatus.completed.name;
    json['completedAt'] = DateTime.now().toUtc().toIso8601String();
    json['currentStep'] = 8;
    final completed = VisualInspection.fromJson(json);
    try {
      await state.visualInspectionRepository.finalize(completed);
      if (completed.result.requiresTechnicalInspection) {
        final now = DateTime.now().toUtc();
        await state.functionalEligibilityRepository.save(
          FunctionalReportEligibility(
            hydrantId: widget.hydrantId,
            allowed: true,
            source: FunctionalEligibilitySource.requiredByVisualResult,
            reason: completed.result.technicalInspectionReasons.join(', '),
            authorizedBy: state.user.id,
            authorizedRole: state.user.role,
            deviceId: state.user.deviceId,
            authorizedAt: now,
            pendingValidation: true,
            supervisorValidationRequired: true,
            visualReportId: completed.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await state.enqueueSync(
          entityType: 'functionalEligibility',
          entityId: widget.hydrantId,
          hydrantId: widget.hydrantId,
        );
        await state.trace(
          'functional_eligibility_created',
          'RF requerido por resultado de REPORTE VISUAL',
          hydrantId: widget.hydrantId,
          inspectionId: completed.id,
        );
      }
      await state.syncBox.put(completed.id, 'Guardado localmente');
      state.markVisualReportCompleted(widget.hydrantId);
      await state.trace(
        'visual_report_completed',
        '${ReportTypeLabels.visualFull} finalizado',
        hydrantId: widget.hydrantId,
      );
      if (!mounted) return;
      setState(() {
        inspection = completed;
        saving = false;
        dirty = false;
      });
      await _showCompletion(completed);
    } catch (failure) {
      await state.trace(
        'visual_report_persistence_failed',
        '$failure',
        hydrantId: widget.hydrantId,
      );
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'No fue posible finalizar el reporte. El borrador permanece guardado.\n$failure';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.type != 'a') return const _F02BPlaceholder();
    final value = inspection!;
    final step = value.currentStep;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppPageHeader(
          title: '${ReportTypeLabels.visualFull} · ${titles[step - 1]}',
          subtitle:
              '${context.read<AppState>().hydrant(widget.hydrantId).code} · Paso $step de 8',
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatusBadge(
                saving
                    ? 'Guardando'
                    : dirty
                    ? 'Sin guardar'
                    : 'Guardado',
                color: saving || dirty ? AppColors.orange : AppColors.green,
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (details) =>
              dragStart = details.globalPosition.dx,
          onHorizontalDragEnd: (details) {
            final start = dragStart ?? 0;
            if ((details.primaryVelocity ?? 0) > 400 && start > 28) _back();
            dragStart = null;
          },
          child: Column(
            children: [
              LinearProgressIndicator(value: step / 8, color: AppColors.teal),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (validationErrors.isNotEmpty)
                      _ValidationSummary(
                        errors: validationErrors,
                        onSelected: _goToValidationError,
                      ),
                    _StepBody(
                      inspection: value,
                      setValue: _setSectionValue,
                      captureLocation: _captureLocation,
                      capturePhoto: _capturePhoto,
                      deletePhoto: _deletePhoto,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SectionCard(
                          child: Text(
                            error!,
                            style: const TextStyle(color: AppColors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: saving ? null : _back,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: value.status == InspectionStatus.completed
                            ? FilledButton(
                                onPressed: () => context.pop(),
                                child: const Text('Volver al hidrante'),
                              )
                            : FilledButton(
                                onPressed: saving ? null : _next,
                                child: Text(
                                  step == 8
                                      ? 'Finalizar ${ReportTypeLabels.visualFull}'
                                      : 'Guardar y continuar',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureLocation() async {
    final state = context.read<AppState>();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final position = await LocationService().capture();
      final utm = CoordinateConversionService().wgs84ToUtm(
        position.latitude,
        position.longitude,
      );
      final json = inspection!.toJson();
      json['geoReference'] = {
        ...Map<String, dynamic>.from(json['geoReference'] as Map),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'elevation': position.altitude,
        'horizontalAccuracy': position.accuracy,
        'verticalAccuracy': position.altitudeAccuracy,
        'capturedAt': position.timestamp.toUtc().toIso8601String(),
        'capturedBy': state.user.id,
        'utmEast': utm.easting,
        'utmNorth': utm.northing,
        'utmZone': utm.zone,
        'rtkStatus': RtkStatus.unavailable.name,
      };
      setState(() {
        inspection = VisualInspection.fromJson(json);
        dirty = true;
        saving = false;
      });
      await state.trace(
        'location_captured',
        'Ubicación GPS real capturada',
        hydrantId: widget.hydrantId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
      await state.trace('location_error', '$e', hydrantId: widget.hydrantId);
    }
  }

  Future<void> _capturePhoto(String category, ImageSource source) async {
    final state = context.read<AppState>();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final photo = await ReliablePhotoService().acquire(
        pickerSource: source,
        hydrantId: widget.hydrantId,
        inspectionId: inspection!.id,
        category: category,
        userId: state.user.id,
        userName: state.user.fullName,
        brigadeId: state.user.brigadeId,
        deviceId: state.user.deviceId,
      );
      if (photo != null) {
        final ids = [...inspection!.photoIds, photo.id];
        setState(() {
          inspection = inspection!.copyWith(photoIds: ids);
          dirty = true;
        });
        await state.mediaBox.put(photo.id, photo.syncStatus.name);
        await state.trace(
          'photo_stored',
          'Fotografía $category almacenada y en cola',
          hydrantId: widget.hydrantId,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
      await state.trace(
        'photo_processing_error',
        '$e',
        hydrantId: widget.hydrantId,
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> _deletePhoto(InspectionPhoto photo) async {
    if (inspection!.status == InspectionStatus.completed) return;
    final state = context.read<AppState>();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Retirar fotografía'),
            content: const Text(
              'Se retirará del reporte y quedará en papelera lógica local.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retirar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final box = Hive.box<String>('inspection_photos_v1');
    final raw = box.get(photo.id);
    if (raw == null) return;
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    json['deletedAt'] = DateTime.now().toUtc().toIso8601String();
    json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await box.put(photo.id, jsonEncode(json));
    final ids = [...inspection!.photoIds]..remove(photo.id);
    setState(() {
      inspection = inspection!.copyWith(photoIds: ids);
      dirty = true;
      validationErrors = [];
    });
    await state.trace(
      'photo_deleted',
      'Fotografía retirada a papelera lógica',
      hydrantId: widget.hydrantId,
    );
  }

  Future<void> _showCompletion(VisualInspection completed) async {
    final state = context.read<AppState>();
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('${ReportTypeLabels.visualFull} finalizado'),
        content: Text(
          'Hidrante: ${state.hydrant(widget.hydrantId).code}\n'
          'Fecha: ${completed.completedAt?.toLocal()}\n'
          'Clasificación: ${completed.result.classification?.name ?? 'Sin clasificación'}\n'
          'Fotografías: ${completed.photoIds.length}\n'
          'Estado: pendiente de sincronización\n'
          'Requiere ${ReportTypeLabels.functionalFull}: ${completed.result.requiresTechnicalInspection ? 'Sí' : 'No'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'summary'),
            child: const Text('Ver resumen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'sync'),
            child: const Text('Abrir sincronización'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'hydrant'),
            child: const Text('Volver al hidrante'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'sync') {
      context.push('/sync?return=/hydrants/${widget.hydrantId}');
    } else {
      context.go('/hydrants/${widget.hydrantId}');
    }
  }

  Future<void> _goToValidationError(InspectionValidationError issue) async {
    if (issue.stepNumber == inspection!.currentStep) return;
    await _save(nextStep: issue.stepNumber);
    if (mounted) setState(() => validationErrors = []);
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.errors, required this.onSelected});
  final List<InspectionValidationError> errors;
  final ValueChanged<InspectionValidationError> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completa los siguientes datos para continuar',
            style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final issue in errors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Paso ${issue.stepNumber} · ${issue.message}',
                style: const TextStyle(color: AppColors.red),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.red),
              onTap: () => onSelected(issue),
            ),
        ],
      ),
    ),
  );
}

typedef SetValue = void Function(String section, String key, Object? value);

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.inspection,
    required this.setValue,
    required this.captureLocation,
    required this.capturePhoto,
    required this.deletePhoto,
  });
  final VisualInspection inspection;
  final SetValue setValue;
  final VoidCallback captureLocation;
  final void Function(String category, ImageSource source) capturePhoto;
  final Future<void> Function(InspectionPhoto photo) deletePhoto;

  @override
  Widget build(BuildContext context) {
    final step = inspection.currentStep;
    final children = <Widget>[];
    switch (step) {
      case 1:
        children.addAll([
          const Text('¿El código observado corresponde con la asignación?'),
          _choices(
            ['Sí', 'No', 'No se puede confirmar'],
            inspection.identification.matchesAssignment?.name,
            (v) => setValue(
              'identification',
              'matchesAssignment',
              ['yes', 'no', 'unknown'][v],
            ),
          ),
          const Text('Estado de identificación'),
          _choices(
            const [
              'Placa legible',
              'Placa ilegible',
              'Sin placa',
              'Código diferente',
            ],
            inspection.identification.status?.name,
            (v) => setValue(
              'identification',
              'status',
              IdentificationStatus.values[v].name,
            ),
          ),
          TextFormField(
            initialValue: inspection.identification.observedCode,
            decoration: const InputDecoration(labelText: 'Código observado'),
            onChanged: (v) => setValue('identification', 'observedCode', v),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      capturePhoto('identificación', ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Foto de identificación'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Seleccionar de biblioteca',
                onPressed: () =>
                    capturePhoto('identificación', ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ],
          ),
        ]);
      case 2:
        final geo = inspection.geoReference;
        children.addAll([
          FilledButton.icon(
            onPressed: captureLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Capturar ubicación GPS real'),
          ),
          if (geo.hasValidPosition)
            ListTile(
              title: Text(
                '${geo.latitude!.toStringAsFixed(6)}, ${geo.longitude!.toStringAsFixed(6)}',
              ),
              subtitle: Text(
                'Precisión ${geo.horizontalAccuracy?.toStringAsFixed(1)} m · UTM ${geo.utmZone}\nRTK simulado: no disponible',
              ),
            ),
          TextFormField(
            initialValue: geo.omissionJustification,
            decoration: const InputDecoration(
              labelText: 'Justificación si no es posible capturar',
            ),
            onChanged: (v) => _setLocationException(v),
          ),
        ]);
      case 3:
        children.addAll([
          const Text('Tipo de acceso'),
          _choices(
            F02aCatalogs.accessTypes,
            inspection.access.accessType?.name,
            (v) => setValue('access', 'accessType', AccessType.values[v].name),
          ),
          const Text('Condición'),
          _choices(
            F02aCatalogs.conditions,
            inspection.access.condition?.name,
            (v) => setValue(
              'access',
              'condition',
              PhysicalCondition.values[v].name,
            ),
          ),
          const Text('Tipo de camino'),
          _choices(
            const ['Pavimento', 'Terracería', 'Sendero', 'Parcela', 'Otro'],
            inspection.access.roadType?.name,
            (v) => setValue('access', 'roadType', RoadType.values[v].name),
          ),
          const Text('Riesgos'),
          Wrap(
            spacing: 6,
            children:
                [
                      'Ninguno',
                      'Lodo',
                      'Vegetación',
                      'Inundación',
                      'Acceso restringido',
                    ]
                    .map(
                      (risk) => FilterChip(
                        label: Text(risk),
                        selected: inspection.access.risks.contains(risk),
                        onSelected: (_) {
                          final values = [...inspection.access.risks];
                          if (values.contains(risk)) {
                            values.remove(risk);
                          } else {
                            if (risk == 'Ninguno') values.clear();
                            values.remove('Ninguno');
                            values.add(risk);
                          }
                          setValue('access', 'risks', values);
                        },
                      ),
                    )
                    .toList(),
          ),
        ]);
      case 4:
        children.addAll(
          _equipment(
            'flowMeter',
            inspection.flowMeter.exists,
            '¿Existe medidor de caudal?',
          ),
        );
        if (inspection.flowMeter.exists == true) {
          children.addAll([
            const Text('Condición física'),
            _choices(
              F02aCatalogs.conditions,
              inspection.flowMeter.condition?.name,
              (v) => setValue(
                'flowMeter',
                'condition',
                PhysicalCondition.values[v].name,
              ),
            ),
            const Text('Funcionamiento aparente'),
            _choices(
              const [
                'Funciona',
                'No funciona',
                'No verificado',
                'No disponible',
              ],
              inspection.flowMeter.operation?.name,
              (v) => setValue(
                'flowMeter',
                'operation',
                OperationState.values[v].name,
              ),
            ),
          ]);
        }
      case 5:
        children.addAll(
          _equipment(
            'pressureValve',
            inspection.pressureValve.exists,
            '¿Existe válvula reductora?',
          ),
        );
        if (inspection.pressureValve.exists == true) {
          children.addAll([
            TextFormField(
              initialValue: '${inspection.pressureValve.quantity}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              onChanged: (v) =>
                  setValue('pressureValve', 'quantity', int.tryParse(v) ?? 0),
            ),
            const Text('Condición física'),
            _choices(
              F02aCatalogs.conditions,
              inspection.pressureValve.condition?.name,
              (v) => setValue(
                'pressureValve',
                'condition',
                PhysicalCondition.values[v].name,
              ),
            ),
            TextFormField(
              initialValue: inspection.pressureValve.leakageLevel,
              decoration: const InputDecoration(labelText: 'Nivel de fuga'),
              onChanged: (v) => setValue('pressureValve', 'leakageLevel', v),
            ),
            const Text('¿Existe solenoide?'),
            _choices(
              const ['Sí', 'No', 'No verificado'],
              inspection.pressureValve.solenoidExists == null
                  ? null
                  : inspection.pressureValve.solenoidExists!
                  ? 'Sí'
                  : 'No',
              (v) => setValue(
                'pressureValve',
                'solenoidExists',
                v == 0
                    ? true
                    : v == 1
                    ? false
                    : null,
              ),
            ),
            if (inspection.pressureValve.solenoidExists == true)
              TextFormField(
                initialValue: inspection.pressureValve.solenoidType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de solenoide',
                ),
                onChanged: (v) => setValue('pressureValve', 'solenoidType', v),
              ),
          ]);
        }
      case 6:
        children.addAll(
          _equipment(
            'energyCommunication',
            inspection.energyCommunication.energyAvailable,
            '¿Hay energía disponible?',
            key: 'energyAvailable',
          ),
        );
        if (inspection.energyCommunication.energyAvailable == true) {
          children.addAll([
            const Text('Fuentes de energía'),
            _multiSelect(
              F02aCatalogs.energySources,
              inspection.energyCommunication.sources,
              (v) => setValue('energyCommunication', 'sources', v),
            ),
            TextFormField(
              initialValue: inspection.energyCommunication.voltage,
              decoration: const InputDecoration(labelText: 'Voltaje observado'),
              onChanged: (v) => setValue('energyCommunication', 'voltage', v),
            ),
          ]);
        }
        children.addAll([
          const Text('Redes disponibles'),
          _multiSelect(
            [...F02aCatalogs.communications, 'Ninguna'],
            inspection.energyCommunication.availableNetworks,
            (v) => setValue('energyCommunication', 'availableNetworks', v),
          ),
          const Text('¿Hay internet disponible?'),
          _choices(
            const ['Sí', 'No', 'No verificado'],
            inspection.energyCommunication.internetAvailable == null
                ? null
                : inspection.energyCommunication.internetAvailable!
                ? 'Sí'
                : 'No',
            (v) => setValue(
              'energyCommunication',
              'internetAvailable',
              v == 0
                  ? true
                  : v == 1
                  ? false
                  : null,
            ),
          ),
        ]);
      case 7:
        children.addAll([
          SwitchListTile(
            title: const Text('Sin daños visibles'),
            value: inspection.noVisibleDamageConfirmed,
            onChanged: inspection.damageIds.isEmpty
                ? (v) => setValue('root', 'noVisibleDamageConfirmed', v)
                : null,
          ),
          Text('${inspection.damageIds.length} daños registrados'),
          const Text('Cada daño exige componente, severidad y fotografía.'),
        ]);
      case 8:
        children.add(const Text('Fotografías obligatorias'));
        for (final category in _requiredPhotoCategories()) {
          final photos = _photosFor(category);
          final count = photos.length;
          children.add(
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categoryLabel(category),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextButton.icon(
                            onPressed: count == 0
                                ? null
                                : () => _openCategoryPhotos(
                                    context,
                                    category,
                                    photos,
                                  ),
                            icon: Icon(
                              count > 0
                                  ? Icons.check_circle
                                  : Icons.photo_outlined,
                              size: 18,
                            ),
                            label: Text(
                              '$count ${count == 1 ? 'tomada' : 'tomadas'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cámara',
                      onPressed: () =>
                          capturePhoto(category, ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    IconButton(
                      tooltip: 'Biblioteca',
                      onPressed: () =>
                          capturePhoto(category, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        children.add(const Text('Clasificación final'));
        children.add(
          _choices(
            F02aCatalogs.classifications,
            inspection.result.classification?.name,
            (v) => setValue(
              'result',
              'classification',
              FinalClassification.values[v].name,
            ),
          ),
        );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _Comments(
          initial: _comments(step),
          onChanged: (v) => setValue(
            _section(step),
            step == 8 ? 'finalComments' : 'comments',
            v,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (e) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: e),
          )
          .toList(),
    );
  }

  void _setLocationException(String value) {
    setValue('geoReference', 'omissionJustification', value);
    setValue('geoReference', 'pendingGeoreference', value.trim().isNotEmpty);
    setValue('result', 'supervisorReviewRequired', value.trim().isNotEmpty);
  }

  Widget _multiSelect(
    List<String> options,
    List<String> selected,
    ValueChanged<List<String>> changed,
  ) => Wrap(
    spacing: 6,
    children: options
        .map(
          (option) => FilterChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: (_) {
              final values = [...selected];
              values.contains(option)
                  ? values.remove(option)
                  : values.add(option);
              changed(values);
            },
          ),
        )
        .toList(),
  );

  List<InspectionPhoto> _photosFor(String category) {
    final box = Hive.box<String>('inspection_photos_v1');
    const accepted = {
      MediaSyncStatus.storedLocal,
      MediaSyncStatus.pendingUpload,
      MediaSyncStatus.uploading,
      MediaSyncStatus.uploadedUnverified,
      MediaSyncStatus.verified,
    };
    return [
          for (final id in inspection.photoIds)
            if (box.get(id) case final String raw)
              InspectionPhoto.fromJson(
                Map<String, dynamic>.from(jsonDecode(raw) as Map),
              ),
        ]
        .where(
          (photo) =>
              photo.inspectionId == inspection.id &&
              photo.category == category &&
              !photo.isDeleted &&
              File(photo.localPath).existsSync() &&
              photo.fileSize > 0 &&
              photo.sha256.isNotEmpty &&
              accepted.contains(photo.syncStatus),
        )
        .toList();
  }

  void _openCategoryPhotos(
    BuildContext context,
    String category,
    List<InspectionPhoto> photos,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _categoryLabel(category),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final photo in photos)
              Card(
                child: ListTile(
                  leading: Image.file(
                    File(photo.thumbnailPath),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                  title: Text('${photo.width} × ${photo.height}'),
                  subtitle: Text(
                    '${photo.capturedAt.toLocal()}\n${photo.syncStatus.name}',
                  ),
                  onTap: () => showDialog<void>(
                    context: sheetContext,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: Image.file(File(photo.localPath)),
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      Navigator.pop(sheetContext);
                      if (action == 'repeat') {
                        capturePhoto(category, ImageSource.camera);
                      } else {
                        await deletePhoto(photo);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'repeat', child: Text('Repetir')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String category) => switch (category) {
    'vistaGeneral' => 'Vista general',
    _ => '${category[0].toUpperCase()}${category.substring(1)}',
  };

  List<String> _requiredPhotoCategories() => [
    'acceso',
    'panorámica',
    'vistaGeneral',
    'identificación',
    if (inspection.flowMeter.exists == true) 'medidor',
    if (inspection.pressureValve.exists == true) 'válvula',
    if (inspection.pressureValve.solenoidExists == true) 'solenoide',
    if (inspection.energyCommunication.energyAvailable == true) 'energía',
    if (inspection.energyCommunication.availableNetworks.any(
      (item) => item != 'Ninguna',
    ))
      'comunicación',
  ];

  List<Widget> _equipment(
    String section,
    bool? exists,
    String label, {
    String key = 'exists',
  }) => [
    Text(label),
    _choices(
      ['Sí', 'No', 'No verificado'],
      exists == null
          ? null
          : exists
          ? 'Sí'
          : 'No',
      (v) => setValue(
        section,
        key,
        v == 0
            ? true
            : v == 1
            ? false
            : null,
      ),
    ),
  ];
  Widget _choices(
    List<String> values,
    String? selected,
    ValueChanged<int> onSelected,
  ) => Wrap(
    spacing: 8,
    children: [
      for (var i = 0; i < values.length; i++)
        ChoiceChip(
          label: Text(values[i]),
          selected: selected == values[i] || selected == _normalized(values[i]),
          onSelected: (_) => onSelected(i),
        ),
    ],
  );
  String _normalized(String text) =>
      const {
        'Sí': 'yes',
        'No': 'no',
        'Vehicular': 'vehicle',
        'Peatonal': 'walking',
        'Ambos': 'both',
        'Bueno': 'good',
        'Regular': 'fair',
        'Malo': 'bad',
        'Crítico': 'critical',
        'No verificado': 'unknown',
        'Operativo': 'operational',
        'Operativo con observaciones': 'observations',
        'No operativo': 'nonOperational',
        'Riesgo crítico': 'critical',
        'Placa legible': 'readablePlate',
        'Placa ilegible': 'unreadablePlate',
        'Sin placa': 'noPlate',
        'Código diferente': 'differentCode',
        'Pavimento': 'pavement',
        'Terracería': 'dirtRoad',
        'Sendero': 'trail',
        'Parcela': 'parcel',
        'Otro': 'other',
        'Funciona': 'works',
        'No funciona': 'doesNotWork',
        'No disponible': 'unavailable',
      }[text] ??
      text.toLowerCase().replaceAll(' ', '');
  String _section(int step) => [
    'identification',
    'geoReference',
    'access',
    'flowMeter',
    'pressureValve',
    'energyCommunication',
    'result',
    'result',
  ][step - 1];
  String _comments(int step) => switch (step) {
    1 => inspection.identification.comments,
    2 => inspection.geoReference.comments,
    3 => inspection.access.comments,
    4 => inspection.flowMeter.comments,
    5 => inspection.pressureValve.comments,
    6 => inspection.energyCommunication.comments,
    7 => inspection.result.finalComments,
    _ => inspection.result.finalComments,
  };
}

class _Comments extends StatelessWidget {
  const _Comments({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Comentarios adicionales'),
    subtitle: Text('${initial.length}/500 · opcional'),
    children: [
      TextFormField(
        initialValue: initial,
        maxLength: 500,
        maxLines: 3,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Observaciones extraordinarias',
        ),
      ),
    ],
  );
}

class _F02BPlaceholder extends StatelessWidget {
  const _F02BPlaceholder();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppPageHeader(title: ReportTypeLabels.functionalFull),
    body: const Center(
      child: Text(
        '${ReportTypeLabels.functionalFull} se implementará en una etapa posterior.',
      ),
    ),
  );
}
