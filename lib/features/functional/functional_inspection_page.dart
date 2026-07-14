import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/report_type_labels.dart';
import '../../core/media/reliable_photo_service.dart';
import '../../core/measurements/measurement_units.dart';
import '../../core/persistence/versioned_json_codec.dart';
import '../../core/services/app_state.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/catalogs/functional_catalogs.dart';
import '../../domain/functional/functional_models.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/inspections/visual_inspection.dart';
import '../../domain/media/inspection_photo.dart';
import 'calculation/functional_result_engine.dart';

class FunctionalInspectionPage extends StatefulWidget {
  const FunctionalInspectionPage({required this.hydrantId, super.key});
  final String hydrantId;
  @override
  State<FunctionalInspectionPage> createState() =>
      _FunctionalInspectionPageState();
}

class _FunctionalInspectionPageState extends State<FunctionalInspectionPage> {
  static const _titles = [
    'Identificación y preparación',
    'Instrumentos y montaje',
    'Presión y caudal',
    'Válvulas y reductora',
    'Solenoides y actuación',
    'Energía',
    'Comunicaciones y telemetría',
    'Alarmas, estanqueidad y fugas',
    'Evidencias y revisión',
    'Resultado y cierre',
  ];
  FunctionalInspection? inspection;
  bool loading = true, saving = false;
  bool readOnly = false;
  String saveState = 'Guardado';
  String? error;
  final photoService = ReliablePhotoService();
  final Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final value in controllers.values) {
      value.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) {
    return controllers.putIfAbsent(
      key,
      () => TextEditingController(text: '${inspection?.stepData[key] ?? ''}'),
    );
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final active = state.functionalInspectionRepository.activeFor(
        widget.hydrantId,
      );
      final history = state.functionalInspectionRepository.forHydrant(
        widget.hydrantId,
      );
      final completed = history
          .where(
            (value) => value.status == FunctionalInspectionStatus.completed,
          )
          .firstOrNull;
      var value =
          active ??
          completed ??
          await state.functionalInspectionRepository.openOrCreate(
            state.hydrant(widget.hydrantId),
            state.user,
          );
      if (value.provenance.isEmpty &&
          value.status != FunctionalInspectionStatus.completed) {
        value = await _inheritVisualContext(value, state);
      }
      if (!mounted) return;
      inspection = value;
      readOnly = active == null && completed?.id == value.id;
      for (final entry in value.stepData.entries) {
        _controller(entry.key).text = '${entry.value}';
      }
      await state.trace(
        'functional_draft_recovered',
        readOnly
            ? '${ReportTypeLabels.functionalFull} finalizado abierto'
            : value.currentStep > 1
            ? 'Borrador de ${ReportTypeLabels.functionalFull} recuperado'
            : '${ReportTypeLabels.functionalFull} iniciado',
        hydrantId: widget.hydrantId,
      );
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<FunctionalInspection> _inheritVisualContext(
    FunctionalInspection value,
    AppState state,
  ) async {
    final candidates = <VisualInspection>[];
    for (final raw in Hive.box<String>('visual_inspections_v1').values) {
      try {
        final visual = VisualInspection.fromJson(
          VersionedJsonCodec.decode(raw).payload,
        );
        if (visual.hydrantId == value.hydrantId) candidates.add(visual);
      } on Object {
        continue;
      }
    }
    if (candidates.isEmpty) {
      final hydrant = state.hydrant(value.hydrantId);
      final updated = value.copyWith(
        stepData: {
          ...value.stepData,
          'functionalObservedCode': hydrant.code,
          'functionalLatitude': '${hydrant.latitude}',
          'functionalLongitude': '${hydrant.longitude}',
        },
      );
      await state.functionalInspectionRepository.save(updated);
      return updated;
    }
    candidates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visual = candidates.first;
    final now = DateTime.now().toUtc();
    final inherited = <String, dynamic>{
      ...value.stepData,
      'inheritedVisualInspectionId': visual.id,
      'inheritedAssignedCode': visual.identification.assignedCode ?? '',
      'inheritedObservedCode': visual.identification.observedCode ?? '',
      'inheritedLatitude': visual.geoReference.latitude,
      'inheritedLongitude': visual.geoReference.longitude,
      'inheritedFlowMeterBrand': visual.flowMeter.brand ?? '',
      'inheritedFlowMeterModel': visual.flowMeter.model ?? '',
      'inheritedFlowMeterSerial': visual.flowMeter.serialNumber ?? '',
      'inheritedDamageIds': visual.damageIds,
      'referencePhotoIds': visual.photoIds,
    };
    final provenance = <FunctionalFieldProvenance>[
      FunctionalFieldProvenance(
        fieldKey: 'identification',
        visualInspectionId: visual.id,
        inheritedValue: visual.identification.toJson(),
        observedValue: null,
        observedBy: state.user.id,
        observedAt: now,
      ),
      FunctionalFieldProvenance(
        fieldKey: 'location',
        visualInspectionId: visual.id,
        inheritedValue: visual.geoReference.toJson(),
        observedValue: null,
        observedBy: state.user.id,
        observedAt: now,
      ),
      FunctionalFieldProvenance(
        fieldKey: 'flowMeter',
        visualInspectionId: visual.id,
        inheritedValue: visual.flowMeter.toJson(),
        observedValue: null,
        observedBy: state.user.id,
        observedAt: now,
      ),
    ];
    final updated = value.copyWith(stepData: inherited, provenance: provenance);
    await state.functionalInspectionRepository.save(updated);
    await state.trace(
      'functional_visual_context_inherited',
      'Datos de REPORTE VISUAL reutilizados como referencia',
      hydrantId: value.hydrantId,
      inspectionId: value.id,
      metadata: {'visualInspectionId': visual.id},
    );
    return updated;
  }

  Map<String, dynamic> _currentData() {
    final data = Map<String, dynamic>.from(inspection!.stepData);
    for (final entry in controllers.entries) {
      data[entry.key] = entry.value.text.trim();
    }
    return data;
  }

  List<FunctionalFieldProvenance> _currentProvenance(
    Map<String, dynamic> data,
  ) {
    if (inspection!.provenance.isEmpty) return const [];
    final now = DateTime.now().toUtc();
    return [
      for (final value in inspection!.provenance)
        if (value.fieldKey == 'identification')
          FunctionalFieldProvenance(
            fieldKey: value.fieldKey,
            visualInspectionId: value.visualInspectionId,
            inheritedValue: value.inheritedValue,
            observedValue: data['functionalObservedCode'],
            reason: '${data['identificationDifferenceReason'] ?? ''}',
            observedBy: context.read<AppState>().user.id,
            observedAt: now,
            reviewRequired: '${data['identificationDifferenceReason'] ?? ''}'
                .trim()
                .isNotEmpty,
          )
        else if (value.fieldKey == 'location')
          FunctionalFieldProvenance(
            fieldKey: value.fieldKey,
            visualInspectionId: value.visualInspectionId,
            inheritedValue: value.inheritedValue,
            observedValue: {
              'latitude': data['functionalLatitude'],
              'longitude': data['functionalLongitude'],
            },
            reason: '${data['locationDifferenceReason'] ?? ''}',
            observedBy: context.read<AppState>().user.id,
            observedAt: now,
            reviewRequired: '${data['locationDifferenceReason'] ?? ''}'
                .trim()
                .isNotEmpty,
          )
        else if (value.fieldKey == 'flowMeter')
          FunctionalFieldProvenance(
            fieldKey: value.fieldKey,
            visualInspectionId: value.visualInspectionId,
            inheritedValue: value.inheritedValue,
            observedValue: {
              'brandText': data['functionalFlowMeterBrand'],
              'modelText': data['functionalFlowMeterModel'],
              'serialNumber': data['functionalFlowMeterSerial'],
            },
            reason: '${data['flowMeterDifferenceReason'] ?? ''}',
            observedBy: context.read<AppState>().user.id,
            observedAt: now,
            reviewRequired: '${data['flowMeterDifferenceReason'] ?? ''}'
                .trim()
                .isNotEmpty,
          )
        else
          value,
    ];
  }

  Future<bool> _save({int? step, FunctionalInspectionStatus? status}) async {
    if (inspection == null) return false;
    final state = context.read<AppState>();
    setState(() {
      saving = true;
      saveState = 'Guardando';
    });
    try {
      final data = _currentData();
      final value = inspection!.copyWith(
        currentStep: step,
        status: status,
        stepData: data,
        provenance: _currentProvenance(data),
        updatedAt: DateTime.now().toUtc(),
      );
      await state.functionalInspectionRepository.save(value);
      await state.enqueueSync(
        entityType: 'functionalInspection',
        entityId: value.id,
        inspectionId: value.id,
        hydrantId: value.hydrantId,
      );
      inspection = value;
      if (mounted) setState(() => saveState = 'Guardado');
      return true;
    } catch (e) {
      if (mounted) setState(() => saveState = 'Error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _validate() {
    final step = inspection!.currentStep, data = _currentData();
    if (step == 1 &&
        !inspection!.preconditions.criticalReady &&
        !inspection!.visitWithoutTest) {
      return 'Completa las precondiciones críticas o guarda la visita sin prueba.';
    }
    if (step == 1 &&
        inspection!.stepData['inheritedVisualInspectionId'] == null &&
        ('${data['functionalObservedCode'] ?? ''}'.trim().isEmpty ||
            double.tryParse('${data['functionalLatitude'] ?? ''}') == null ||
            double.tryParse('${data['functionalLongitude'] ?? ''}') == null)) {
      return 'Captura identificación y ubicación mínima para REPORTE FUNCIONAL.';
    }
    if (step == 2 &&
        _activeInstrumentIds.isEmpty &&
        !inspection!.visitWithoutTest) {
      return 'Agrega al menos un instrumento.';
    }
    if (step >= 3 &&
        step <= 8 &&
        (data['step${step}Status'] ?? '').toString().isEmpty &&
        !inspection!.visitWithoutTest) {
      return 'Selecciona el estado de esta prueba.';
    }
    if (step >= 3 && step <= 8) {
      final status = '${data['step${step}Status'] ?? ''}';
      if ((status == 'notPerformed' || status == 'notApplicable') &&
          '${data['step${step}Comments'] ?? ''}'.trim().isEmpty) {
        return 'No aplica y No realizada exigen motivo.';
      }
    }
    if (step == 3 &&
        _series.any((value) => value.isActive) &&
        !inspection!.visitWithoutTest) {
      return 'Finaliza o descarta la serie activa antes de continuar.';
    }
    if (step == 3 &&
        '${data['step3Status'] ?? ''}' == 'completed' &&
        _series.where((value) => !value.isActive).isEmpty) {
      return 'Una prueba realizada requiere al menos una serie finalizada.';
    }
    if (step == 9) {
      for (final item in inspection!.evidenceRequirements) {
        if (item.status == EvidenceRequirementStatus.pending &&
            !inspection!.visitWithoutTest) {
          return 'Resuelve toda la matriz de evidencia.';
        }
        if (item.status != EvidenceRequirementStatus.provided &&
            item.reason.trim().isEmpty) {
          return 'No aplica y No realizada exigen motivo.';
        }
      }
    }
    if (step == 10 && (data['finalComments'] ?? '').toString().isEmpty) {
      return 'Agrega comentarios finales.';
    }
    if (step == 10 &&
        '${data['resultOverride'] ?? ''}'.isNotEmpty &&
        '${data['resultOverrideReason'] ?? ''}'.trim().isEmpty) {
      return 'Modificar el resultado calculado exige motivo.';
    }
    if (step == 10 &&
        '${data['leakageLevel'] ?? 'none'}' != 'none' &&
        !inspection!.evidenceRequirements.any(
          (value) =>
              value.category == 'fuga' &&
              value.status == EvidenceRequirementStatus.provided,
        )) {
      return 'Toda fuga requiere evidencia fotográfica.';
    }
    if (step == 10) {
      final photoBox = Hive.box<String>('inspection_photos_v1');
      for (final id in inspection!.photoIds) {
        final raw = photoBox.get(id);
        if (raw == null) {
          return 'Existe evidencia fotográfica sin registro local.';
        }
        try {
          final photo = InspectionPhoto.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
          if (!File(photo.localPath).existsSync() ||
              photo.fileSize <= 0 ||
              photo.sha256.isEmpty) {
            return 'Existe una fotografía faltante o sin integridad.';
          }
        } on Object {
          return 'Existe una fotografía corrupta.';
        }
      }
    }
    return null;
  }

  Future<void> _persistTechnicalStep(int step) async {
    if (step < 4 || step > 8 || inspection!.visitWithoutTest) return;
    final state = context.read<AppState>();
    final data = _currentData();
    final records = <String, FunctionalTestRecord>{};
    if (step == 4) {
      final valveId = '${inspection!.id}:valve:1';
      records[valveId] = FunctionalValveTest(
        id: valveId,
        inspectionId: inspection!.id,
        valveId: '${data['valveIdentifier'] ?? 'VAL-1'}',
        diameter: '${data['valveDiameter'] ?? ''}',
        openingTimeSeconds: '${data['valveOpeningTime'] ?? ''}',
        closingTimeSeconds: '${data['valveClosingTime'] ?? ''}',
        numberOfCycles: int.tryParse('${data['valveCycles'] ?? '1'}') ?? 1,
        manualOperation: '${data['valveManualOperation'] ?? ''}',
        automaticOperation: '${data['valveAutomaticOperation'] ?? ''}',
        effort: '${data['valveEffort'] ?? ''}',
        blockage: data['valveBlockage'] == 'yes',
        noise: data['valveNoise'] == 'yes',
        vibration: data['valveVibration'] == 'yes',
        leakageLevel: '${data['valveLeakage'] ?? 'none'}',
        pressureBehavior: '${data['valvePressureBehavior'] ?? ''}',
        result: '${data['step4Status'] ?? ''}',
        comments: '${data['step4Comments'] ?? ''}',
      );
      final reducerId = '${inspection!.id}:reducer:1';
      records[reducerId] = ReducerTest(
        id: reducerId,
        inspectionId: inspection!.id,
        runs: [
          {
            'inletPressure': '${data['reducerInletPressure'] ?? ''}',
            'targetPressure': '${data['reducerTargetPressure'] ?? ''}',
            'outletPressure': '${data['reducerOutletPressure'] ?? ''}',
            'flow': '${data['reducerFlow'] ?? ''}',
            'adjustment': '${data['reducerAdjustment'] ?? ''}',
            'stability': '${data['reducerStability'] ?? ''}',
            'response': '${data['reducerResponse'] ?? ''}',
            'leakage': '${data['reducerLeakage'] ?? ''}',
            'blockage': '${data['reducerBlockage'] ?? ''}',
          },
        ],
        result: '${data['step4Status'] ?? ''}',
        comments: '${data['step4Comments'] ?? ''}',
      );
    } else if (step == 5) {
      final id = '${inspection!.id}:solenoid:1';
      records[id] = SolenoidTest(
        id: id,
        inspectionId: inspection!.id,
        values: {
          'type': '${data['solenoidType'] ?? ''}',
          'nominalVoltage': '${data['solenoidNominalVoltage'] ?? ''}',
          'measuredVoltage': '${data['solenoidMeasuredVoltage'] ?? ''}',
          'current': '${data['solenoidCurrent'] ?? ''}',
          'resistance': '${data['solenoidResistance'] ?? ''}',
          'signal': '${data['solenoidSignal'] ?? ''}',
          'localActuation': '${data['solenoidLocalActuation'] ?? ''}',
          'remoteActuation': 'simulated',
          'actuationTime': '${data['solenoidActuationTime'] ?? ''}',
          'response': '${data['solenoidResponse'] ?? ''}',
        },
        result: '${data['step5Status'] ?? ''}',
        comments: '${data['step5Comments'] ?? ''}',
      );
    } else if (step == 6) {
      final id = '${inspection!.id}:energy:1';
      records[id] = EnergyTest(
        id: id,
        inspectionId: inspection!.id,
        values: {
          'source': '${data['energySource'] ?? ''}',
          'voltage': '${data['energyVoltage'] ?? ''}',
          'current': '${data['energyCurrent'] ?? ''}',
          'battery': '${data['energyBattery'] ?? ''}',
          'solarPanel': '${data['energySolarPanel'] ?? ''}',
          'controller': '${data['energyController'] ?? ''}',
          'grid': '${data['energyGrid'] ?? ''}',
          'backup': '${data['energyBackup'] ?? ''}',
          'stability': '${data['energyStability'] ?? ''}',
          'consumption': '${data['energyConsumption'] ?? ''}',
          'voltageDrop': '${data['energyVoltageDrop'] ?? ''}',
        },
        notPerformedReason: '${data['step6Comments'] ?? ''}',
        result: '${data['step6Status'] ?? ''}',
        comments: '${data['step6Comments'] ?? ''}',
      );
    } else if (step == 7) {
      final id = '${inspection!.id}:communication:1';
      records[id] = CommunicationTest(
        id: id,
        inspectionId: inspection!.id,
        values: {
          'technology': '${data['communicationTechnology'] ?? ''}',
          'operator': '${data['communicationOperator'] ?? ''}',
          'signal': '${data['communicationSignal'] ?? ''}',
          'quality': '${data['communicationQuality'] ?? ''}',
          'latencyMs': '${data['communicationLatency'] ?? ''}',
          'networkRegistration': '${data['communicationRegistration'] ?? ''}',
          'connectivity': '${data['communicationConnectivity'] ?? ''}',
          'dataSent': '${data['communicationDataSent'] ?? ''}',
          'commandReceived': '${data['communicationCommandReceived'] ?? ''}',
          'modbusAddress': '${data['modbusAddress'] ?? ''}',
          'baudRate': '${data['modbusBaudRate'] ?? ''}',
          'parity': '${data['modbusParity'] ?? ''}',
          'timeoutMs': '${data['modbusTimeout'] ?? ''}',
          'retries': '${data['modbusRetries'] ?? ''}',
          'mode': 'manualOrSimulated',
        },
        result: '${data['step7Status'] ?? ''}',
        comments: '${data['step7Comments'] ?? ''}',
      );
    } else if (step == 8) {
      final alarmId = '${inspection!.id}:alarm:1';
      records[alarmId] = AlarmTest(
        id: alarmId,
        inspectionId: inspection!.id,
        alarmType: '${data['alarmType'] ?? ''}',
        generated: data['alarmGenerated'] == 'yes',
        detectedLocally: data['alarmDetected'] == 'yes',
        reported: data['alarmReported'] == 'yes',
        generatedAt: data['alarmGenerated'] == 'yes'
            ? DateTime.now().toUtc()
            : null,
        latencyMs: '${data['alarmLatency'] ?? ''}',
        acknowledged: data['alarmAcknowledged'] == 'yes',
        result: '${data['alarmResult'] ?? ''}',
        comments: '${data['step8Comments'] ?? ''}',
      );
      final leakageId = '${inspection!.id}:leakage:1';
      records[leakageId] = LeakageTest(
        id: leakageId,
        inspectionId: inspection!.id,
        level: '${data['leakageLevel'] ?? 'none'}',
        location: '${data['leakageLocation'] ?? ''}',
        componentId: '${data['leakageComponent'] ?? ''}',
        pressure: '${data['leakagePressure'] ?? ''}',
        durationSeconds: '${data['leakageDuration'] ?? ''}',
        estimatedLoss: '${data['leakageEstimatedLoss'] ?? ''}',
        recommendedAction: '${data['leakageAction'] ?? ''}',
        photoIds: inspection!.evidenceRequirements
            .where((value) => value.category == 'fuga')
            .expand((value) => value.photoIds)
            .toList(),
        result: '${data['step8Status'] ?? ''}',
        comments: '${data['step8Comments'] ?? ''}',
      );
    }
    if (records.isEmpty) return;
    final testIds = {...inspection!.testRecordIds};
    for (final entry in records.entries) {
      final boxName = entry.value is FunctionalValveTest
          ? 'functional_valve_tests_v1'
          : entry.value is AlarmTest
          ? 'alarm_tests_v1'
          : 'functional_test_records_v1';
      await Hive.box<String>(boxName).put(
        entry.key,
        VersionedJsonCodec.encode(
          schemaVersion: entry.value.schemaVersion,
          payload: entry.value.toJson(),
        ),
      );
      testIds.add(entry.key);
      await state.enqueueSync(
        entityType: entry.value.runtimeType.toString(),
        entityId: entry.key,
        inspectionId: inspection!.id,
        hydrantId: inspection!.hydrantId,
        dependencyIds: ['functionalInspection:${inspection!.id}'],
      );
      await state.trace(
        'functional_test_saved',
        'Prueba guardada: ${entry.value.runtimeType}',
        hydrantId: inspection!.hydrantId,
        inspectionId: inspection!.id,
        entityType: entry.value.runtimeType.toString(),
        entityId: entry.key,
      );
    }
    inspection = inspection!.copyWith(testRecordIds: testIds.toList());
  }

  void _ensureConditionalEvidence() {
    final data = _currentData();
    final categories = <String>{
      for (final value in inspection!.evidenceRequirements) value.category,
    };
    final required = <String>{};
    if (inspection!.measurementSeriesIds.any((id) {
      final series = _series.where((value) => value.id == id).firstOrNull;
      return series != null &&
          series.testType.toLowerCase().contains('pressure');
    })) {
      required.add('presión');
    }
    if (inspection!.measurementSeriesIds.any((id) {
      final series = _series.where((value) => value.id == id).firstOrNull;
      return series != null && series.testType.toLowerCase().contains('flow');
    })) {
      required.addAll({'caudal', 'caudalímetro patrón'});
    }
    if ('${data['step4Status'] ?? ''}' == 'completed' ||
        '${data['step4Status'] ?? ''}' == 'failed') {
      required.addAll({'válvula abierta', 'válvula cerrada', 'reductora'});
    }
    if ('${data['step5Status'] ?? ''}' == 'completed' ||
        '${data['step5Status'] ?? ''}' == 'failed') {
      required.add('solenoide');
    }
    if ('${data['step6Status'] ?? ''}' == 'completed' ||
        '${data['step6Status'] ?? ''}' == 'failed') {
      required.add('energía');
    }
    if ('${data['step7Status'] ?? ''}' == 'completed' ||
        '${data['step7Status'] ?? ''}' == 'failed') {
      required.addAll({'comunicación', 'telemetría'});
    }
    if ('${data['alarmResult'] ?? ''}' == 'approved' ||
        '${data['alarmResult'] ?? ''}' == 'failed') {
      required.add('alarma');
    }
    if ('${data['leakageLevel'] ?? 'none'}' != 'none') {
      required.add('fuga');
    }
    final values = [...inspection!.evidenceRequirements];
    for (final category in required.difference(categories)) {
      values.add(
        EvidenceRequirement(id: const Uuid().v4(), category: category),
      );
    }
    inspection = inspection!.copyWith(evidenceRequirements: values);
  }

  Future<void> _next() async {
    final state = context.read<AppState>();
    final issue = _validate();
    if (issue != null) {
      if (inspection!.currentStep == 1) {
        await state.trace(
          'functional_test_blocked',
          issue,
          hydrantId: inspection!.hydrantId,
          inspectionId: inspection!.id,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(issue)));
      return;
    }
    await _persistTechnicalStep(inspection!.currentStep);
    _ensureConditionalEvidence();
    if (inspection!.currentStep < 10) {
      await _save(
        step: inspection!.currentStep + 1,
        status: FunctionalInspectionStatus.inProgress,
      );
      return;
    }
    final calculation = FunctionalResultEngine.calculate(
      inspection!.copyWith(stepData: _currentData()),
    );
    final calculated = calculation.result;
    final overrideName = _controller('resultOverride').text;
    final selected = overrideName.isEmpty
        ? calculated
        : FunctionalOverallResult.values.byName(overrideName);
    final overrideReason = _controller('resultOverrideReason').text.trim();
    final result = FunctionalInspectionResult(
      overallResult: selected,
      calculatedResult: calculated,
      hydraulicResult: _domainStatus(3),
      mechanicalResult: _domainStatus(4),
      electricalResult: _combineStatuses([5, 6]),
      communicationResult: _domainStatus(7),
      safetyResult: inspection!.preconditions.criticalReady
          ? 'Cumple'
          : 'Prueba no realizada',
      calibrationResult: inspection!.visitWithoutTest
          ? 'No evaluable'
          : 'Revisada',
      finalComments: _controller('finalComments').text.trim(),
      calculationRulesVersion: calculation.rulesVersion,
      inspectorOverrideReason: overrideReason,
      requiresRepair: selected == FunctionalOverallResult.requiresRepair,
      requiresReplacement:
          selected == FunctionalOverallResult.requiresReplacement,
      requiresAdjustment:
          selected == FunctionalOverallResult.requiresAdjustment,
      requiresRepeatTest: selected == FunctionalOverallResult.incompleteTest,
      requiresSupervisorReview:
          selected != calculated ||
          selected == FunctionalOverallResult.requiresRepair ||
          selected == FunctionalOverallResult.requiresReplacement,
      recommendedActions: calculation.reasons,
      completedAt: DateTime.now().toUtc(),
      completedBy: state.user.id,
    );
    final completed = inspection!.copyWith(
      status: FunctionalInspectionStatus.completed,
      completedAt: DateTime.now().toUtc(),
      stepData: _currentData(),
      result: result,
    );
    try {
      await state.functionalInspectionRepository.finalize(completed);
      inspection = completed;
      await Hive.box<String>('functional_results_v1').put(
        completed.id,
        VersionedJsonCodec.encode(
          schemaVersion: completed.schemaVersion,
          payload: result.toJson(),
        ),
      );
      await state.enqueueSync(
        entityType: 'functionalResult',
        entityId: completed.id,
        inspectionId: completed.id,
        hydrantId: completed.hydrantId,
        dependencyIds: ['functionalInspection:${completed.id}'],
      );
      await state.trace(
        'functional_result_calculated',
        'Resultado calculado: ${calculated.name}',
        hydrantId: completed.hydrantId,
        inspectionId: completed.id,
        entityType: 'functionalResult',
        entityId: completed.id,
      );
      if (selected != calculated) {
        await state.trace(
          'functional_result_modified',
          'Resultado modificado a ${selected.name}',
          hydrantId: completed.hydrantId,
          inspectionId: completed.id,
          entityType: 'functionalResult',
          entityId: completed.id,
          reason: overrideReason,
        );
      }
      await state.enqueueSync(
        entityType: 'functionalInspection',
        entityId: completed.id,
        inspectionId: completed.id,
        hydrantId: completed.hydrantId,
      );
      await state.trace(
        'functional_inspection_completed',
        '${ReportTypeLabels.functionalFull} finalizado',
        hydrantId: widget.hydrantId,
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('${ReportTypeLabels.functionalFull} finalizado'),
            content: const Text(
              'El reporte quedó guardado localmente y pendiente de sincronización.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No fue posible finalizar: $e')));
      }
    }
  }

  String _domainStatus(int step) =>
      '${_currentData()['step${step}Status'] ?? 'notPerformed'}';

  String _combineStatuses(List<int> steps) {
    final values = steps.map(_domainStatus).toList();
    if (values.contains('failed')) return 'failed';
    if (values.contains('notPerformed')) return 'notPerformed';
    if (values.every((value) => value == 'notApplicable')) {
      return 'notApplicable';
    }
    return 'completed';
  }

  Future<void> _back() async {
    if (inspection!.currentStep > 1) {
      await _save(step: inspection!.currentStep - 1);
      return;
    }
    await _save();
    if (mounted) context.pop();
  }

  Future<void> _suspend() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Suspender REPORTE FUNCIONAL'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Suspender prueba'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    inspection = inspection!.copyWith(
      status: FunctionalInspectionStatus.suspended,
      suspensionReason: reason,
      stepData: _currentData(),
    );
    await _save(status: FunctionalInspectionStatus.suspended);
    await state.trace(
      'functional_inspection_suspended',
      'Prueba suspendida: $reason',
      hydrantId: widget.hydrantId,
    );
    if (mounted) context.pop();
  }

  Future<void> _pause() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pausar REPORTE FUNCIONAL'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Pausar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    inspection = inspection!.copyWith(
      status: FunctionalInspectionStatus.paused,
      pauseReason: reason,
      stepData: _currentData(),
    );
    await _save(status: FunctionalInspectionStatus.paused);
    await state.trace(
      'functional_inspection_paused',
      'Prueba pausada: $reason',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
    );
    if (mounted) context.pop();
  }

  Future<void> _cancel() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar REPORTE FUNCIONAL'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Cancelar reporte'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    inspection = inspection!.copyWith(
      status: FunctionalInspectionStatus.cancelled,
      suspensionReason: reason,
      stepData: _currentData(),
    );
    await state.functionalInspectionRepository.deactivate(inspection!);
    await state.trace(
      'functional_inspection_cancelled',
      'REPORTE FUNCIONAL cancelado',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
      reason: reason,
    );
    if (mounted) context.pop();
  }

  Future<void> _resume() async {
    final state = context.read<AppState>();
    inspection = inspection!.copyWith(
      status: FunctionalInspectionStatus.inProgress,
      pauseReason: '',
      suspensionReason: '',
    );
    await _save(status: FunctionalInspectionStatus.inProgress);
    await state.trace(
      'functional_inspection_resumed',
      'REPORTE FUNCIONAL reanudado',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
    );
  }

  Future<void> _visitWithoutTest() async {
    final state = context.read<AppState>();
    final reason = _controller('visitWithoutTestReason').text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura el motivo de la visita sin prueba.'),
        ),
      );
      return;
    }
    final evidence = [
      for (final value in inspection!.evidenceRequirements)
        const {
              'banco de pruebas',
              'montaje general',
              'instrumentos',
            }.contains(value.category)
            ? EvidenceRequirement(
                id: value.id,
                category: value.category,
                status: EvidenceRequirementStatus.notPerformed,
                reason: reason,
                photoIds: value.photoIds,
                testId: value.testId,
              )
            : value,
      if (!inspection!.evidenceRequirements.any(
        (value) => value.category == 'condición impeditiva',
      ))
        EvidenceRequirement(
          id: const Uuid().v4(),
          category: 'condición impeditiva',
        ),
    ];
    inspection = inspection!.copyWith(
      visitWithoutTest: true,
      preconditions: FunctionalPreconditions.fromJson({
        ...inspection!.preconditions.toJson(),
        'visitWithoutTest': true,
        'blockingReason': reason,
        'reschedulingRequired': true,
      }),
      evidenceRequirements: evidence,
    );
    await _save();
    await state.trace(
      'functional_visit_without_test',
      'Visita sin prueba: $reason',
      hydrantId: widget.hydrantId,
    );
  }

  Future<void> _addInstrument() async {
    final state = context.read<AppState>();
    String type = FunctionalCatalogs.instrumentTypes.first;
    String identification = InstrumentIdentificationStatus.identified.name;
    String calibrationStatus = CalibrationStatus.unknown.name;
    final asset = TextEditingController(),
        brand = TextEditingController(),
        model = TextEditingController(),
        serial = TextEditingController(),
        range = TextEditingController(),
        unit = TextEditingController(),
        accuracy = TextEditingController(),
        calibrationDate = TextEditingController(),
        calibrationDueDate = TextEditingController(),
        certificate = TextEditingController(),
        condition = TextEditingController(),
        comments = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Agregar instrumento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: [
                    for (final v in FunctionalCatalogs.instrumentTypes)
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: (v) => setLocal(() => type = v!),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                TextField(
                  controller: asset,
                  decoration: const InputDecoration(
                    labelText: 'Código de activo',
                  ),
                ),
                TextField(
                  controller: brand,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                TextField(
                  controller: model,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
                TextField(
                  controller: serial,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Número de serie',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: identification,
                  items: [
                    for (final v in InstrumentIdentificationStatus.values)
                      DropdownMenuItem(
                        value: v.name,
                        child: Text(_identificationLabel(v)),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => identification = v!),
                  decoration: const InputDecoration(
                    labelText: 'Estado de identificación',
                  ),
                ),
                TextField(
                  controller: range,
                  decoration: const InputDecoration(
                    labelText: 'Rango de medición',
                  ),
                ),
                TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                ),
                TextField(
                  controller: accuracy,
                  decoration: const InputDecoration(
                    labelText: 'Clase de precisión',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: calibrationStatus,
                  items: [
                    for (final value in CalibrationStatus.values)
                      DropdownMenuItem(
                        value: value.name,
                        child: Text(_calibrationLabel(value)),
                      ),
                  ],
                  onChanged: (value) =>
                      setLocal(() => calibrationStatus = value!),
                  decoration: const InputDecoration(
                    labelText: 'Estado de calibración',
                  ),
                ),
                TextField(
                  controller: calibrationDate,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de calibración (AAAA-MM-DD)',
                  ),
                ),
                TextField(
                  controller: calibrationDueDate,
                  decoration: const InputDecoration(
                    labelText: 'Vencimiento (AAAA-MM-DD)',
                  ),
                ),
                TextField(
                  controller: certificate,
                  decoration: const InputDecoration(
                    labelText: 'Certificado de calibración',
                  ),
                ),
                TextField(
                  controller: condition,
                  decoration: const InputDecoration(labelText: 'Condición'),
                ),
                TextField(
                  controller: comments,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Comentarios'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      for (final c in [
        asset,
        brand,
        model,
        serial,
        range,
        unit,
        accuracy,
        calibrationDate,
        calibrationDueDate,
        certificate,
        condition,
        comments,
      ]) {
        c.dispose();
      }
      return;
    }
    final id = const Uuid().v4();
    final record = InstrumentRecord(
      id: id,
      inspectionId: inspection!.id,
      type: type,
      assetCode: asset.text.trim(),
      brandText: brand.text.trim(),
      modelText: model.text.trim(),
      serialNumber: serial.text.trim(),
      identificationStatus: InstrumentIdentificationStatus.values.byName(
        identification,
      ),
      measurementRange: range.text.trim(),
      unit: unit.text.trim(),
      accuracyClass: accuracy.text.trim(),
      calibrationDate: DateTime.tryParse(calibrationDate.text.trim())?.toUtc(),
      calibrationDueDate: DateTime.tryParse(
        calibrationDueDate.text.trim(),
      )?.toUtc(),
      calibrationCertificate: certificate.text.trim(),
      calibrationStatus: CalibrationStatus.values.byName(calibrationStatus),
      condition: condition.text.trim(),
      operatorId: state.user.id,
      comments: comments.text.trim(),
    );
    await Hive.box<String>('instrument_records_v1').put(
      id,
      VersionedJsonCodec.encode(
        schemaVersion: record.schemaVersion,
        payload: record.toJson(),
      ),
    );
    inspection = inspection!.copyWith(
      instrumentIds: [...inspection!.instrumentIds, id],
    );
    await _save();
    await state.enqueueSync(
      entityType: 'instrument',
      entityId: id,
      inspectionId: inspection!.id,
      hydrantId: inspection!.hydrantId,
      dependencyIds: ['functionalInspection:${inspection!.id}'],
    );
    if (FunctionalCatalogs.calibrationBlocksOfficialMeasurement(
      record.type,
      record.calibrationStatus,
    )) {
      await state.trace(
        'functional_calibration_expired',
        'Instrumento bloqueado por calibración ${record.calibrationStatus.name}',
        hydrantId: widget.hydrantId,
        inspectionId: inspection!.id,
        entityType: 'instrument',
        entityId: id,
      );
    }
    await state.trace(
      'functional_instrument_added',
      'Instrumento agregado: $type',
      hydrantId: widget.hydrantId,
    );
    for (final c in [
      asset,
      brand,
      model,
      serial,
      range,
      unit,
      accuracy,
      calibrationDate,
      calibrationDueDate,
      certificate,
      condition,
      comments,
    ]) {
      c.dispose();
    }
  }

  Future<void> _captureEvidence(EvidenceRequirement requirement) async {
    final state = context.read<AppState>();
    final data = _currentData();
    final relatedSeries = _series
        .where(
          (value) => requirement.category == 'presión'
              ? value.testType.toLowerCase().contains('pressure')
              : requirement.category == 'caudal'
              ? value.testType.toLowerCase().contains('flow')
              : false,
        )
        .firstOrNull;
    final testId = switch (requirement.category) {
      'válvula abierta' || 'válvula cerrada' => '${inspection!.id}:valve:1',
      'reductora' => '${inspection!.id}:reducer:1',
      'solenoide' => '${inspection!.id}:solenoid:1',
      'energía' => '${inspection!.id}:energy:1',
      'comunicación' || 'telemetría' => '${inspection!.id}:communication:1',
      'alarma' => '${inspection!.id}:alarm:1',
      'fuga' => '${inspection!.id}:leakage:1',
      _ => null,
    };
    final photo = await photoService.acquire(
      pickerSource: ImageSource.camera,
      hydrantId: widget.hydrantId,
      inspectionId: inspection!.id,
      inspectionType: 'f02B',
      category: requirement.category,
      testId: testId,
      componentId: requirement.category == 'fuga'
          ? '${data['leakageComponent'] ?? ''}'
          : requirement.category.startsWith('válvula')
          ? '${data['valveIdentifier'] ?? ''}'
          : null,
      instrumentId:
          requirement.category == 'instrumentos' &&
              inspection!.instrumentIds.isNotEmpty
          ? inspection!.instrumentIds.first
          : relatedSeries?.instrumentId,
      measurementSeriesId: relatedSeries?.id,
      evidenceRequirementId: requirement.id,
      userId: state.user.id,
      userName: state.user.fullName,
      brigadeId: state.user.brigadeId,
      deviceId: state.user.deviceId,
    );
    if (photo == null) return;
    final requirements = [
      for (final item in inspection!.evidenceRequirements)
        item.id == requirement.id
            ? EvidenceRequirement(
                id: item.id,
                category: item.category,
                status: EvidenceRequirementStatus.provided,
                reason: item.reason,
                photoIds: [...item.photoIds, photo.id],
                testId: item.testId,
              )
            : item,
    ];
    inspection = inspection!.copyWith(
      photoIds: [...inspection!.photoIds, photo.id],
      evidenceRequirements: requirements,
    );
    await state.mediaBox.put(photo.id, photo.syncStatus.name);
    await _save();
    await state.trace(
      'functional_photo_captured',
      'Fotografía RF: ${requirement.category}',
      hydrantId: widget.hydrantId,
    );
  }

  List<MeasurementSeries> get _series => [
    for (final id in inspection!.measurementSeriesIds)
      if (Hive.box<String>('measurement_series_v1').get(id)
          case final String raw)
        MeasurementSeries.fromJson(VersionedJsonCodec.decode(raw).payload),
  ];

  InstrumentRecord? _instrument(String id) {
    final raw = Hive.box<String>('instrument_records_v1').get(id);
    if (raw == null) return null;
    try {
      return InstrumentRecord.fromJson(VersionedJsonCodec.decode(raw).payload);
    } on Object {
      return null;
    }
  }

  List<String> get _activeInstrumentIds => inspection!.instrumentIds
      .where((id) => _instrument(id)?.deletedAt == null)
      .toList();

  Future<void> _removeInstrument(InstrumentRecord record) async {
    final state = context.read<AppState>();
    if (_series.any(
      (value) => value.instrumentId == record.id && value.isActive,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede retirar un instrumento con serie activa.'),
        ),
      );
      return;
    }
    final deleted = record.copyWith(deletedAt: DateTime.now().toUtc());
    await Hive.box<String>('instrument_records_v1').put(
      record.id,
      VersionedJsonCodec.encode(
        schemaVersion: deleted.schemaVersion,
        payload: deleted.toJson(),
      ),
    );
    await state.enqueueSync(
      entityType: 'instrument',
      entityId: record.id,
      inspectionId: inspection!.id,
      hydrantId: inspection!.hydrantId,
    );
    await state.trace(
      'functional_instrument_removed',
      'Instrumento retirado lógicamente',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
      entityType: 'instrument',
      entityId: record.id,
    );
    if (mounted) setState(() {});
  }

  Future<void> _addSeries() async {
    final state = context.read<AppState>();
    if (_activeInstrumentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega primero un instrumento.')),
      );
      return;
    }
    var type = 'staticPressure';
    var instrumentId = _activeInstrumentIds.first;
    var unit = 'kPa';
    final valueController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nueva serie de medición'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: 'staticPressure',
                      child: Text('Presión estática'),
                    ),
                    DropdownMenuItem(
                      value: 'dynamicPressure',
                      child: Text('Presión dinámica'),
                    ),
                    DropdownMenuItem(
                      value: 'upstreamPressure',
                      child: Text('Presión aguas arriba'),
                    ),
                    DropdownMenuItem(
                      value: 'downstreamPressure',
                      child: Text('Presión aguas abajo'),
                    ),
                    DropdownMenuItem(
                      value: 'hydrantFlow',
                      child: Text('Caudal del hidrante'),
                    ),
                    DropdownMenuItem(
                      value: 'patternFlow',
                      child: Text('Caudal patrón'),
                    ),
                  ],
                  onChanged: (value) {
                    setLocal(() {
                      type = value!;
                      unit = type.toLowerCase().contains('flow')
                          ? 'L/s'
                          : 'kPa';
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Prueba'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: instrumentId,
                  items: [
                    for (final id in _activeInstrumentIds)
                      DropdownMenuItem(value: id, child: Text(id)),
                  ],
                  onChanged: (value) => instrumentId = value!,
                  decoration: const InputDecoration(labelText: 'Instrumento'),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(unit),
                  initialValue: unit,
                  items: [
                    for (final value
                        in type.toLowerCase().contains('flow')
                            ? FunctionalCatalogs.flowUnits
                            : FunctionalCatalogs.pressureUnits)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => unit = value!,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                ),
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Lectura inicial',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Iniciar serie'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      valueController.dispose();
      return;
    }
    final instrumentRaw = Hive.box<String>(
      'instrument_records_v1',
    ).get(instrumentId);
    if (instrumentRaw == null) {
      valueController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El instrumento ya no está disponible.'),
          ),
        );
      }
      return;
    }
    final selectedInstrument = InstrumentRecord.fromJson(
      VersionedJsonCodec.decode(instrumentRaw).payload,
    );
    if (FunctionalCatalogs.calibrationBlocksOfficialMeasurement(
      selectedInstrument.type,
      selectedInstrument.calibrationStatus,
    )) {
      valueController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedInstrument.type}: calibración ${_calibrationLabel(selectedInstrument.calibrationStatus).toLowerCase()}. La medición oficial DEMO está bloqueada; guarda una visita sin prueba o usa un instrumento vigente.',
            ),
          ),
        );
      }
      await state.trace(
        'functional_test_blocked',
        'Serie bloqueada por calibración ${selectedInstrument.calibrationStatus.name}',
        hydrantId: inspection!.hydrantId,
        inspectionId: inspection!.id,
        entityType: 'instrument',
        entityId: selectedInstrument.id,
      );
      return;
    }
    final dimension = type.toLowerCase().contains('flow')
        ? MeasurementDimension.flow
        : MeasurementDimension.pressure;
    NormalizedMeasurement normalized;
    try {
      normalized = MeasurementUnits.normalize(
        valueController.text,
        unit,
        dimension,
      );
    } on FormatException catch (error) {
      valueController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (!await _confirmPhysicalRange(normalized)) {
      valueController.dispose();
      return;
    }
    final now = DateTime.now().toUtc();
    final seriesId = const Uuid().v4();
    final reading = MeasurementReading(
      id: const Uuid().v4(),
      timestamp: now,
      originalValue: normalized.originalValue,
      originalUnit: normalized.originalUnit,
      normalizedValue: normalized.normalizedValue,
      normalizedUnit: normalized.baseUnit,
      precision: normalized.precision,
      instrumentId: instrumentId,
      sequence: 1,
      stable: true,
    );
    final series = MeasurementSeries(
      id: seriesId,
      inspectionId: inspection!.id,
      testType: type,
      instrumentId: instrumentId,
      startedAt: now,
      unit: normalized.baseUnit,
      readings: [reading],
      createdBy: state.user.id,
      deviceId: state.user.deviceId,
    );
    await Hive.box<String>('measurement_series_v1').put(
      seriesId,
      VersionedJsonCodec.encode(
        schemaVersion: series.schemaVersion,
        payload: series.toJson(),
      ),
    );
    inspection = inspection!.copyWith(
      measurementSeriesIds: [...inspection!.measurementSeriesIds, seriesId],
    );
    _controller('step3Status').text = 'completed';
    await _save();
    await state.enqueueSync(
      entityType: 'measurementSeries',
      entityId: seriesId,
      inspectionId: inspection!.id,
      hydrantId: inspection!.hydrantId,
      dependencyIds: ['functionalInspection:${inspection!.id}'],
    );
    await state.trace(
      'functional_series_started',
      'Serie iniciada: $type',
      hydrantId: widget.hydrantId,
      inspectionId: inspection!.id,
      entityType: 'measurementSeries',
      entityId: seriesId,
    );
    valueController.dispose();
  }

  Future<void> _writeSeries(MeasurementSeries series) async {
    await Hive.box<String>('measurement_series_v1').put(
      series.id,
      VersionedJsonCodec.encode(
        schemaVersion: series.schemaVersion,
        payload: series.toJson(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addReading(MeasurementSeries series) async {
    final state = context.read<AppState>();
    final valueController = TextEditingController();
    var unit = series.testType.toLowerCase().contains('flow') ? 'L/s' : 'kPa';
    var stable = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Agregar lectura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: unit,
                items: [
                  for (final value
                      in series.testType.toLowerCase().contains('flow')
                          ? FunctionalCatalogs.flowUnits
                          : FunctionalCatalogs.pressureUnits)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => unit = value!,
                decoration: const InputDecoration(labelText: 'Unidad'),
              ),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: stable,
                title: const Text('Lectura estabilizada'),
                onChanged: (value) => setLocal(() => stable = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      valueController.dispose();
      return;
    }
    try {
      final normalized = MeasurementUnits.normalize(
        valueController.text,
        unit,
        series.testType.toLowerCase().contains('flow')
            ? MeasurementDimension.flow
            : MeasurementDimension.pressure,
      );
      if (!await _confirmPhysicalRange(normalized)) return;
      final reading = MeasurementReading(
        id: const Uuid().v4(),
        timestamp: DateTime.now().toUtc(),
        originalValue: normalized.originalValue,
        originalUnit: normalized.originalUnit,
        normalizedValue: normalized.normalizedValue,
        normalizedUnit: normalized.baseUnit,
        precision: normalized.precision,
        instrumentId: series.instrumentId,
        sequence: series.readings.length + 1,
        stable: stable,
      );
      await _writeSeries(
        series.copyWith(readings: [...series.readings, reading]),
      );
      await state.enqueueSync(
        entityType: 'measurementReading',
        entityId: reading.id,
        inspectionId: inspection!.id,
        hydrantId: inspection!.hydrantId,
        dependencyIds: ['measurementSeries:${series.id}'],
      );
      await state.trace(
        'functional_reading_added',
        'Lectura agregada a ${series.testType}',
        hydrantId: inspection!.hydrantId,
        inspectionId: inspection!.id,
        entityType: 'measurementReading',
        entityId: reading.id,
      );
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      valueController.dispose();
    }
  }

  Future<bool> _confirmPhysicalRange(NormalizedMeasurement value) async {
    final numeric = double.tryParse(value.normalizedValue);
    if (numeric == null || numeric >= 0) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Valor fuera del rango físico esperado'),
        content: Text(
          '${value.originalValue} ${value.originalUnit} requiere confirmación y quedará trazado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Corregir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar valor'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final state = context.read<AppState>();
      await state.trace(
        'functional_out_of_range_confirmed',
        'Valor fuera de rango confirmado',
        hydrantId: inspection!.hydrantId,
        inspectionId: inspection!.id,
        metadata: {
          'value': value.originalValue,
          'unit': value.originalUnit,
          'normalizedValue': value.normalizedValue,
          'normalizedUnit': value.baseUnit,
        },
      );
    }
    return confirmed ?? false;
  }

  Future<void> _rejectReading(
    MeasurementSeries series,
    MeasurementReading reading,
  ) async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar lectura'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await _writeSeries(
      series.copyWith(
        readings: [
          for (final value in series.readings)
            value.id == reading.id
                ? value.copyWith(accepted: false, rejectedReason: reason)
                : value,
        ],
      ),
    );
    await state.trace(
      'functional_reading_rejected',
      'Lectura rechazada: $reason',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
      entityType: 'measurementReading',
      entityId: reading.id,
    );
  }

  Future<void> _acceptReading(
    MeasurementSeries series,
    MeasurementReading reading,
  ) async {
    final state = context.read<AppState>();
    await _writeSeries(
      series.copyWith(
        readings: [
          for (final value in series.readings)
            value.id == reading.id
                ? value.copyWith(accepted: true, rejectedReason: '')
                : value,
        ],
      ),
    );
    await state.trace(
      'functional_reading_accepted',
      'Lectura aceptada',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
      entityType: 'measurementReading',
      entityId: reading.id,
    );
  }

  Future<void> _finishSeries(MeasurementSeries series) async {
    final state = context.read<AppState>();
    final accepted = series.readings.where((value) => value.accepted).toList();
    if (accepted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La serie no tiene lecturas aceptadas.')),
      );
      return;
    }
    final statistics = SeriesStatistics.calculate(
      accepted.map((value) => value.normalizedValue),
    );
    final result = statistics == null
        ? 'No calculable'
        : 'mín=${statistics.minimum};máx=${statistics.maximum};prom=${statistics.average};rango=${statistics.range};desv=${statistics.sampleStandardDeviation ?? 'No calculable'}';
    await _writeSeries(
      series.copyWith(completedAt: DateTime.now().toUtc(), result: result),
    );
    _updateMeasurementCalculations();
    await _save();
    await state.trace(
      'functional_series_finished',
      'Serie finalizada: $result',
      hydrantId: inspection!.hydrantId,
      inspectionId: inspection!.id,
      entityType: 'measurementSeries',
      entityId: series.id,
    );
  }

  void _updateMeasurementCalculations() {
    final completed = _series.where((value) => !value.isActive).toList();
    double? averageFor(String type) {
      final series = completed
          .where((value) => value.testType == type)
          .firstOrNull;
      if (series == null) return null;
      return SeriesStatistics.calculate(
        series.readings
            .where((value) => value.accepted)
            .map((value) => value.normalizedValue),
      )?.average;
    }

    final hydrantFlow = averageFor('hydrantFlow');
    final patternFlow = averageFor('patternFlow');
    if (hydrantFlow != null && patternFlow != null) {
      final error = SeriesStatistics.percentageError(hydrantFlow, patternFlow);
      _controller('flowAbsoluteError').text = '${hydrantFlow - patternFlow}';
      _controller('flowErrorPercent').text =
          error?.toString() ?? 'No calculable';
      final tolerance = FunctionalCatalogs.demoTolerances.firstWhere(
        (value) => value.testType == 'flow',
      );
      _controller('flowToleranceVersion').text = tolerance.version;
      _controller('flowToleranceResult').text = error == null
          ? 'notCalculable'
          : error <= tolerance.maximumDeviationPercent
          ? 'demoWithinTolerance'
          : 'demoOutsideTolerance';
    }
    final upstream = averageFor('upstreamPressure');
    final downstream = averageFor('downstreamPressure');
    if (upstream != null && downstream != null) {
      _controller('pressureDifferential').text = '${upstream - downstream}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null || inspection == null) {
      return Scaffold(
        appBar: const AppPageHeader(title: ReportTypeLabels.functionalFull),
        body: Center(child: Text(error ?? 'No fue posible abrir el reporte.')),
      );
    }
    final step = inspection!.currentStep;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppPageHeader(
          title: ReportTypeLabels.functionalFull,
          subtitle: 'Paso $step de 10 · ${_titles[step - 1]}',
          actions: [
            if (!readOnly)
              PopupMenuButton<String>(
                tooltip: 'Acciones de prueba',
                onSelected: (value) => switch (value) {
                  'pause' => _pause(),
                  'suspend' => _suspend(),
                  _ => _cancel(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pause', child: Text('Pausar prueba')),
                  PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspender prueba'),
                  ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancelar reporte'),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: inspection!.progress,
              color: AppColors.violet,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Subpaso ${inspection!.currentSubstep}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const Spacer(),
                  Icon(
                    saving
                        ? Icons.sync
                        : saveState == 'Error'
                        ? Icons.error_outline
                        : Icons.cloud_done_outlined,
                    size: 17,
                    color: saveState == 'Error'
                        ? AppColors.red
                        : AppColors.green,
                  ),
                  const SizedBox(width: 5),
                  Text(saveState),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (context
                          .read<AppState>()
                          .hydrant(widget.hydrantId)
                          .source ==
                      HydrantSource.fieldCreated)
                    const SectionCard(
                      child: Text(
                        'Hidrante pendiente de validación',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (inspection!.status ==
                          FunctionalInspectionStatus.suspended ||
                      inspection!.status ==
                          FunctionalInspectionStatus.paused) ...[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inspection!.status ==
                                    FunctionalInspectionStatus.suspended
                                ? 'REPORTE FUNCIONAL suspendido'
                                : 'REPORTE FUNCIONAL pausado',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            inspection!.status ==
                                    FunctionalInspectionStatus.suspended
                                ? inspection!.suspensionReason
                                : inspection!.pauseReason,
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _resume,
                            child: const Text('Reanudar prueba'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _stepBody(step),
                ],
              ),
            ),
            if (!readOnly)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : _back,
                          child: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: saving ? null : _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: step == 10
                                ? AppColors.green
                                : AppColors.violet,
                          ),
                          child: Text(
                            step == 10
                                ? 'Finalizar ${ReportTypeLabels.functionalFull}'
                                : 'Guardar y continuar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver a la ficha'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody(int step) => switch (step) {
    1 => _preconditions(),
    2 => _instruments(),
    3 => _measurementStep(),
    4 => _valvesAndReducerStep(),
    5 => _solenoidStep(),
    6 => _energyStep(),
    7 => _communicationStep(),
    8 => _alarmsAndLeakageStep(),
    9 => _evidence(),
    _ => _result(),
  };

  Widget _measurementStep() => Column(
    children: [
      const SectionCard(
        child: Text(
          'Las lecturas conservan valor y unidad capturados, valor normalizado, precisión y versión de conversión.',
        ),
      ),
      const SizedBox(height: 12),
      for (final series in _series)
        Card(
          child: ExpansionTile(
            title: Text(series.testType),
            subtitle: Text(
              '${series.readings.length} lectura(s) · ${series.unit} · ${series.isActive ? 'Activa' : 'Finalizada'}',
            ),
            children: [
              for (final reading in series.readings)
                ListTile(
                  title: Text(
                    '${reading.originalValue} ${reading.originalUnit}',
                  ),
                  subtitle: Text(
                    '${reading.normalizedValue} ${reading.normalizedUnit} · ${reading.stable ? 'Estable' : 'No estable'}${reading.accepted ? '' : ' · Rechazada: ${reading.rejectedReason}'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'accept'
                        ? _acceptReading(series, reading)
                        : _rejectReading(series, reading),
                    itemBuilder: (_) => [
                      if (!reading.accepted)
                        const PopupMenuItem(
                          value: 'accept',
                          child: Text('Aceptar'),
                        ),
                      if (reading.accepted)
                        const PopupMenuItem(
                          value: 'reject',
                          child: Text('Rechazar'),
                        ),
                    ],
                  ),
                ),
              if (series.result.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Resultado: ${series.result}'),
                ),
              if (series.isActive)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addReading(series),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar lectura'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _finishSeries(series),
                          child: const Text('Finalizar serie'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (_controller('flowErrorPercent').text.isNotEmpty ||
          _controller('pressureDifferential').text.isNotEmpty)
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cálculos',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_controller('pressureDifferential').text.isNotEmpty)
                Text(
                  'Diferencial de presión: ${_controller('pressureDifferential').text} kPa',
                ),
              if (_controller('flowErrorPercent').text.isNotEmpty)
                Text(
                  'Error contra patrón: ${_controller('flowErrorPercent').text} %',
                ),
              if (_controller('flowToleranceResult').text.isNotEmpty)
                Text(
                  '${_controller('flowToleranceResult').text} · ${_controller('flowToleranceVersion').text}',
                ),
            ],
          ),
        ),
      FilledButton.icon(
        onPressed: _addSeries,
        icon: const Icon(Icons.add_chart),
        label: const Text('Iniciar serie'),
      ),
      const SizedBox(height: 12),
      _stepStatus(3),
      const SizedBox(height: 12),
      const SectionCard(
        child: Text(
          FunctionalCatalogs.toleranceNotice,
          style: TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _textField(
    String key,
    String label, {
    String? suffix,
    bool numeric = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _controller(key),
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );

  Widget _selectField(
    String key,
    String label,
    List<(String, String)> options,
  ) {
    final current = _controller(key).text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: options.any((value) => value.$1 == current)
            ? current
            : null,
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        onChanged: (value) => _controller(key).text = value ?? '',
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _stepStatus(int step) => Column(
    children: [
      _selectField('step${step}Status', 'Estado de la sección', const [
        ('completed', 'Realizada'),
        ('notPerformed', 'No realizada'),
        ('notApplicable', 'No aplica'),
        ('failed', 'Con falla'),
      ]),
      _textField('step${step}Comments', 'Observaciones o motivo', maxLines: 3),
    ],
  );

  Widget _valvesAndReducerStep() => Column(
    children: [
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Válvula',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _textField('valveIdentifier', 'Identificador'),
            _textField('valveDiameter', 'Diámetro'),
            _textField(
              'valveOpeningTime',
              'Tiempo de apertura',
              suffix: 's',
              numeric: true,
            ),
            _textField(
              'valveClosingTime',
              'Tiempo de cierre',
              suffix: 's',
              numeric: true,
            ),
            _textField('valveCycles', 'Número de ciclos', numeric: true),
            _selectField('valveManualOperation', 'Operación manual', const [
              ('approved', 'Aprobada'),
              ('failed', 'Fallida'),
              ('notPerformed', 'No realizada'),
            ]),
            _selectField(
              'valveAutomaticOperation',
              'Operación automática',
              const [
                ('approved', 'Aprobada'),
                ('failed', 'Fallida'),
                ('notPerformed', 'No realizada'),
              ],
            ),
            _selectField('valveEffort', 'Esfuerzo aparente', const [
              ('normal', 'Normal'),
              ('high', 'Alto'),
              ('blocked', 'Bloqueada'),
            ]),
            _selectField('valveBlockage', 'Bloqueo', const [
              ('no', 'No'),
              ('yes', 'Sí'),
            ]),
            _selectField('valveNoise', 'Ruido', const [
              ('no', 'No'),
              ('yes', 'Sí'),
            ]),
            _selectField('valveVibration', 'Vibración', const [
              ('no', 'No'),
              ('yes', 'Sí'),
            ]),
            _selectField('valveLeakage', 'Fuga', const [
              ('none', 'Sin fuga'),
              ('seepage', 'Rezume'),
              ('minor', 'Leve'),
              ('moderate', 'Moderada'),
              ('severe', 'Severa'),
            ]),
            _textField('valvePressureBehavior', 'Comportamiento de presión'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text(
            'Válvula reductora · corrida 1',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _textField(
              'reducerInletPressure',
              'Presión de entrada',
              suffix: 'kPa',
              numeric: true,
            ),
            _textField(
              'reducerTargetPressure',
              'Presión objetivo',
              suffix: 'kPa',
              numeric: true,
            ),
            _textField(
              'reducerOutletPressure',
              'Presión de salida',
              suffix: 'kPa',
              numeric: true,
            ),
            _textField(
              'reducerFlow',
              'Caudal de la corrida',
              suffix: 'L/s',
              numeric: true,
            ),
            _textField('reducerAdjustment', 'Ajuste'),
            _textField('reducerStability', 'Estabilidad'),
            _textField('reducerResponse', 'Respuesta'),
            _selectField('reducerLeakage', 'Fuga', const [
              ('none', 'Sin fuga'),
              ('minor', 'Leve'),
              ('moderate', 'Moderada'),
              ('severe', 'Severa'),
            ]),
            _selectField('reducerBlockage', 'Bloqueo', const [
              ('no', 'No'),
              ('yes', 'Sí'),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _stepStatus(4),
    ],
  );

  Widget _solenoidStep() => Column(
    children: [
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Solenoide y actuación',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _textField('solenoidType', 'Tipo'),
            _textField(
              'solenoidNominalVoltage',
              'Tensión nominal',
              suffix: 'V',
              numeric: true,
            ),
            _textField(
              'solenoidMeasuredVoltage',
              'Tensión medida',
              suffix: 'V',
              numeric: true,
            ),
            _textField(
              'solenoidCurrent',
              'Corriente',
              suffix: 'A',
              numeric: true,
            ),
            _textField(
              'solenoidResistance',
              'Resistencia',
              suffix: 'Ω',
              numeric: true,
            ),
            _selectField('solenoidSignal', 'Señal', const [
              ('correct', 'Correcta'),
              ('incorrect', 'Incorrecta'),
              ('none', 'Sin señal'),
              ('notPerformed', 'No realizada'),
            ]),
            _selectField('solenoidLocalActuation', 'Actuación local', const [
              ('works', 'Responde'),
              ('failed', 'Fallida'),
              ('notPerformed', 'No realizada'),
            ]),
            const ListTile(
              leading: Icon(Icons.science_outlined),
              title: Text('Actuación remota'),
              subtitle: Text(
                'Solo registro manual o simulación; sin comando real.',
              ),
            ),
            _textField(
              'solenoidActuationTime',
              'Tiempo de actuación',
              suffix: 's',
              numeric: true,
            ),
            _textField('solenoidResponse', 'Respuesta observada'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _stepStatus(5),
    ],
  );

  Widget _energyStep() => Column(
    children: [
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Energía',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _textField('energySource', 'Fuente'),
            _textField('energyVoltage', 'Tensión', suffix: 'V', numeric: true),
            _textField(
              'energyCurrent',
              'Corriente',
              suffix: 'A',
              numeric: true,
            ),
            _textField('energyBattery', 'Batería'),
            _textField('energySolarPanel', 'Panel solar'),
            _textField('energyController', 'Controlador'),
            _textField('energyGrid', 'Alimentación de red'),
            _textField('energyBackup', 'Respaldo'),
            _textField('energyStability', 'Estabilidad'),
            _textField(
              'energyConsumption',
              'Consumo',
              suffix: 'W',
              numeric: true,
            ),
            _textField(
              'energyVoltageDrop',
              'Caída de tensión',
              suffix: 'V',
              numeric: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _stepStatus(6),
    ],
  );

  Widget _communicationStep() => Column(
    children: [
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Comunicaciones y telemetría',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _textField('communicationTechnology', 'Tecnología'),
            _textField('communicationOperator', 'Operador'),
            _textField('communicationSignal', 'Intensidad de señal'),
            _textField('communicationQuality', 'Calidad'),
            _textField(
              'communicationLatency',
              'Latencia',
              suffix: 'ms',
              numeric: true,
            ),
            _textField('communicationRegistration', 'Registro en red'),
            _textField('communicationConnectivity', 'Conectividad'),
            _selectField('communicationDataSent', 'Envío de dato', const [
              ('simulatedSuccess', 'Simulado exitoso'),
              ('simulatedFailed', 'Simulado fallido'),
              ('notPerformed', 'No realizado'),
            ]),
            _selectField(
              'communicationCommandReceived',
              'Recepción de comando',
              const [
                ('simulatedSuccess', 'Simulada exitosa'),
                ('simulatedFailed', 'Simulada fallida'),
                ('notPerformed', 'No realizada'),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text('Parámetros manuales Modbus'),
          subtitle: const Text('No se establece conexión real.'),
          children: [
            _textField('modbusAddress', 'Dirección'),
            _textField('modbusBaudRate', 'Baud rate', numeric: true),
            _textField('modbusParity', 'Paridad'),
            _textField('modbusTimeout', 'Timeout', suffix: 'ms', numeric: true),
            _textField('modbusRetries', 'Reintentos', numeric: true),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _stepStatus(7),
    ],
  );

  Widget _alarmsAndLeakageStep() => Column(
    children: [
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text(
            'Prueba de alarma',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            _selectField('alarmType', 'Alarma', [
              for (final value in FunctionalCatalogs.alarmTypes) (value, value),
            ]),
            _selectField('alarmGenerated', 'Generada', const [
              ('yes', 'Sí'),
              ('no', 'No'),
            ]),
            _selectField('alarmDetected', 'Detectada localmente', const [
              ('yes', 'Sí'),
              ('no', 'No'),
            ]),
            _selectField('alarmReported', 'Reportada', const [
              ('yes', 'Sí'),
              ('no', 'No'),
            ]),
            _textField('alarmLatency', 'Latencia', suffix: 'ms', numeric: true),
            _selectField('alarmAcknowledged', 'Reconocida', const [
              ('yes', 'Sí'),
              ('no', 'No'),
            ]),
            _selectField('alarmResult', 'Resultado', const [
              ('approved', 'Aprobada'),
              ('failed', 'Fallida'),
              ('notPerformed', 'No realizada'),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text('Estanqueidad y fugas'),
          children: [
            _selectField('leakageLevel', 'Nivel', const [
              ('none', 'Sin fuga'),
              ('seepage', 'Rezume'),
              ('minor', 'Leve'),
              ('moderate', 'Moderada'),
              ('severe', 'Severa'),
            ]),
            _textField('leakageLocation', 'Ubicación'),
            _textField('leakageComponent', 'Componente'),
            _textField(
              'leakagePressure',
              'Presión durante observación',
              suffix: 'kPa',
              numeric: true,
            ),
            _textField(
              'leakageDuration',
              'Duración',
              suffix: 's',
              numeric: true,
            ),
            _textField('leakageEstimatedLoss', 'Pérdida estimada'),
            _textField('leakageAction', 'Acción recomendada'),
            const ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: Text('Evidencia de fuga'),
              subtitle: Text('Será obligatoria en Evidencias y revisión.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _stepStatus(8),
    ],
  );
  Widget _preconditions() {
    final p = inspection!.preconditions;
    Widget check(String label, bool? value, String key) => CheckboxListTile(
      value: value ?? false,
      title: Text(label),
      onChanged: (v) {
        final json = p.toJson()..[key] = v;
        setState(
          () => inspection = inspection!.copyWith(
            preconditions: FunctionalPreconditions.fromJson(json),
          ),
        );
        context.read<AppState>().trace(
          'functional_precondition_marked',
          '$key=${v ?? false}',
          hydrantId: inspection!.hydrantId,
          inspectionId: inspection!.id,
          entityType: 'precondition',
          entityId: key,
        );
      },
    );
    return Column(
      children: [
        if (inspection!.stepData['inheritedVisualInspectionId'] != null) ...[
          SectionCard(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'Datos heredados de REPORTE VISUAL',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Son referencias; REPORTE FUNCIONAL no sobrescribe el reporte anterior.',
              ),
              children: [
                ListTile(
                  title: const Text('Código observado'),
                  subtitle: Text(
                    '${inspection!.stepData['inheritedObservedCode'] ?? inspection!.stepData['inheritedAssignedCode'] ?? ''}',
                  ),
                ),
                ListTile(
                  title: const Text('Ubicación'),
                  subtitle: Text(
                    '${inspection!.stepData['inheritedLatitude'] ?? ''}, ${inspection!.stepData['inheritedLongitude'] ?? ''}',
                  ),
                ),
                ListTile(
                  title: const Text('Flujómetro instalado'),
                  subtitle: Text(
                    'Marca: ${inspection!.stepData['inheritedFlowMeterBrand'] ?? ''}\nModelo: ${inspection!.stepData['inheritedFlowMeterModel'] ?? ''}\nSerie: ${inspection!.stepData['inheritedFlowMeterSerial'] ?? ''}',
                  ),
                ),
                _textField(
                  'functionalObservedCode',
                  'Código observado durante RF',
                ),
                _textField(
                  'identificationDifferenceReason',
                  'Motivo de diferencia de identificación',
                ),
                _textField(
                  'functionalLatitude',
                  'Latitud observada durante RF',
                  numeric: true,
                ),
                _textField(
                  'functionalLongitude',
                  'Longitud observada durante RF',
                  numeric: true,
                ),
                _textField(
                  'locationDifferenceReason',
                  'Motivo de diferencia de ubicación',
                ),
                _textField(
                  'functionalFlowMeterBrand',
                  'Marca observada durante RF',
                ),
                _textField(
                  'functionalFlowMeterModel',
                  'Modelo observado durante RF',
                ),
                _textField(
                  'functionalFlowMeterSerial',
                  'Número de serie observado durante RF',
                ),
                _textField(
                  'flowMeterDifferenceReason',
                  'Motivo de diferencia del flujómetro',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          SectionCard(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'Identificación mínima',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'No existe REPORTE VISUAL previo; captura el contexto mínimo.',
              ),
              children: [
                _textField('functionalObservedCode', 'Código observado'),
                _textField('functionalLatitude', 'Latitud', numeric: true),
                _textField('functionalLongitude', 'Longitud', numeric: true),
                _textField('functionalFlowMeterBrand', 'Marca del flujómetro'),
                _textField('functionalFlowMeterModel', 'Modelo del flujómetro'),
                _textField(
                  'functionalFlowMeterSerial',
                  'Número de serie del flujómetro',
                ),
                _selectField(
                  'functionalFlowMeterIdentificationStatus',
                  'Estado de identificación',
                  const [
                    ('identified', 'Identificado'),
                    ('notIdentifiable', 'No identificable'),
                    ('unreadable', 'No legible'),
                    ('noPlate', 'Sin placa'),
                    ('notIdentified', 'No identificado'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verificación de seguridad',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              check('Sitio seguro', p.siteSafe, 'siteSafe'),
              check('Acceso permitido', p.accessAllowed, 'accessAllowed'),
              check(
                'Personal autorizado',
                p.authorizedPersonnel,
                'authorizedPersonnel',
              ),
              check(
                'Responsable identificado',
                p.responsibleIdentified,
                'responsibleIdentified',
              ),
              check(
                'Equipo de protección',
                p.protectiveEquipment,
                'protectiveEquipment',
              ),
              check(
                'Condiciones hidráulicas disponibles',
                p.hydraulicConditions,
                'hydraulicConditions',
              ),
              check(
                'Descarga controlada',
                p.controlledDischarge,
                'controlledDischarge',
              ),
              check(
                'Banco de pruebas disponible',
                p.testBenchAvailable,
                'testBenchAvailable',
              ),
              check(
                'Instrumentos disponibles',
                p.instrumentsAvailable,
                'instrumentsAvailable',
              ),
              check(
                'Calibración válida cuando aplica',
                p.calibrationValid,
                'calibrationValid',
              ),
              check('Energía segura', p.safeEnergy, 'safeEnergy'),
              check(
                'Autorización disponible',
                p.authorizationAvailable,
                'authorizationAvailable',
              ),
              check(
                'Válvulas identificadas',
                p.valvesIdentified,
                'valvesIdentified',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            children: [
              TextField(
                controller: _controller('visitWithoutTestReason'),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo si no puede realizarse la prueba',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _visitWithoutTest,
                icon: const Icon(Icons.event_busy),
                label: const Text('Guardar visita sin prueba'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _instruments() => Column(
    children: [
      const SectionCard(
        child: Text(
          'Marca y Modelo son textos libres. No se usan catálogos precargados de marcas o modelos. La calibración desconocida de manómetros y caudalímetros patrón bloquea mediciones oficiales demo.',
        ),
      ),
      const SizedBox(height: 12),
      for (final id in _activeInstrumentIds) _instrumentTile(id),
      FilledButton.icon(
        onPressed: _addInstrument,
        icon: const Icon(Icons.add),
        label: const Text('Agregar instrumento'),
      ),
    ],
  );
  Widget _instrumentTile(String id) {
    final item = _instrument(id);
    if (item == null || item.deletedAt != null) {
      return const ListTile(title: Text('Instrumento no disponible'));
    }
    return Card(
      child: ListTile(
        title: Text(item.type),
        subtitle: Text(
          'Marca: ${item.brandText.isEmpty ? 'No identificada' : item.brandText}\nModelo: ${item.modelText.isEmpty ? 'No identificado' : item.modelText}\nCalibración: ${item.calibrationStatus.name}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (_) => _removeInstrument(item),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'remove', child: Text('Retirar instrumento')),
          ],
          icon:
              FunctionalCatalogs.calibrationBlocksOfficialMeasurement(
                item.type,
                item.calibrationStatus,
              )
              ? const Icon(Icons.warning_amber, color: AppColors.red)
              : const Icon(Icons.more_vert),
        ),
      ),
    );
  }

  Future<void> _setEvidenceStatus(
    EvidenceRequirement item,
    EvidenceRequirementStatus status,
  ) async {
    final reasonController = TextEditingController();
    if (status != EvidenceRequirementStatus.provided) {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            status == EvidenceRequirementStatus.notApplicable
                ? 'Marcar No aplica'
                : 'Marcar No realizada',
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, reasonController.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (reason == null || reason.isEmpty) return;
      final values = [
        for (final value in inspection!.evidenceRequirements)
          value.id == item.id
              ? EvidenceRequirement(
                  id: value.id,
                  category: value.category,
                  status: status,
                  reason: reason,
                  photoIds: value.photoIds,
                  testId: value.testId,
                )
              : value,
      ];
      inspection = inspection!.copyWith(evidenceRequirements: values);
      await _save();
    }
  }

  Widget _evidence() => Column(
    children: [
      for (final item in inspection!.evidenceRequirements)
        Card(
          child: ListTile(
            title: Text(item.category),
            subtitle: Text(item.status.name),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'photo') {
                  _captureEvidence(item);
                } else {
                  _setEvidenceStatus(
                    item,
                    value == 'na'
                        ? EvidenceRequirementStatus.notApplicable
                        : EvidenceRequirementStatus.notPerformed,
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'photo', child: Text('Tomar fotografía')),
                PopupMenuItem(value: 'na', child: Text('No aplica')),
                PopupMenuItem(value: 'nr', child: Text('No realizada')),
              ],
            ),
          ),
        ),
    ],
  );
  Widget _result() => Column(
    children: [
      const SectionCard(
        child: Text(
          'El resultado combina seguridad, calibración, pruebas realizadas, omisiones, fallas y tolerancias versionadas. Las tolerancias actuales son DEMO y no constituyen aprobación técnica oficial.',
        ),
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (_) {
          final calculation = FunctionalResultEngine.calculate(
            inspection!.copyWith(stepData: _currentData()),
          );
          return SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resultado calculado',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(_resultLabel(calculation.result)),
                for (final reason in calculation.reasons)
                  Text('• $reason', style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _selectField(
        'resultOverride',
        'Modificar resultado calculado (opcional)',
        [
          for (final value in FunctionalOverallResult.values)
            (value.name, _resultLabel(value)),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _controller('finalComments'),
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Comentarios finales'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _controller('resultOverrideReason'),
        maxLines: 2,
        decoration: const InputDecoration(
          labelText:
              'Motivo de modificación del resultado calculado (si aplica)',
        ),
      ),
    ],
  );
  static String _identificationLabel(InstrumentIdentificationStatus value) =>
      switch (value) {
        InstrumentIdentificationStatus.identified => 'Identificado',
        InstrumentIdentificationStatus.notIdentifiable => 'No identificable',
        InstrumentIdentificationStatus.unreadable => 'No legible',
        InstrumentIdentificationStatus.noPlate => 'Sin placa',
        InstrumentIdentificationStatus.notIdentified => 'No identificado',
      };

  static String _calibrationLabel(CalibrationStatus value) => switch (value) {
    CalibrationStatus.valid => 'Vigente',
    CalibrationStatus.dueSoon => 'Próxima a vencer',
    CalibrationStatus.expired => 'Vencida',
    CalibrationStatus.unknown => 'Desconocida',
    CalibrationStatus.notApplicable => 'No aplica',
  };

  static String _resultLabel(FunctionalOverallResult value) => switch (value) {
    FunctionalOverallResult.approved => 'Aprobado',
    FunctionalOverallResult.approvedWithObservations =>
      'Aprobado con observaciones',
    FunctionalOverallResult.partialOperation => 'Funcionamiento parcial',
    FunctionalOverallResult.requiresAdjustment => 'Requiere ajuste',
    FunctionalOverallResult.requiresRepair => 'Requiere reparación',
    FunctionalOverallResult.requiresReplacement => 'Requiere reemplazo',
    FunctionalOverallResult.incompleteTest => 'Prueba incompleta',
    FunctionalOverallResult.notEvaluable => 'No evaluable',
    FunctionalOverallResult.suspended => 'Suspendido',
  };
}
