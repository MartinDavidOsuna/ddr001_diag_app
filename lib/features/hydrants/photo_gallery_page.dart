import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/constants/report_type_labels.dart';
import '../../domain/media/inspection_photo.dart';

class PhotoGalleryPage extends StatefulWidget {
  const PhotoGalleryPage({required this.hydrantId, super.key});
  final String hydrantId;
  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  String category = 'Todas';
  String report = 'Todos';

  List<InspectionPhoto> get photos {
    final result = Hive.box<String>('inspection_photos_v1').values
        .map(
          (value) => InspectionPhoto.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        )
        .where(
          (photo) => photo.hydrantId == widget.hydrantId && !photo.isDeleted,
        )
        .where(
          (photo) =>
              report == 'Todos' ||
              (report == ReportTypeLabels.visualShort &&
                  photo.inspectionType == 'f02A') ||
              (report == ReportTypeLabels.functionalShort &&
                  photo.inspectionType == 'f02B'),
        )
        .where((photo) => category == 'Todas' || photo.category == category)
        .toList();
    result.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = photos;
    return Scaffold(
      appBar: const AppPageHeader(
        title: 'Galería local',
        subtitle: 'Evidencia almacenada en el dispositivo',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Todos', label: Text('Todos')),
                ButtonSegment(
                  value: ReportTypeLabels.visualShort,
                  label: Text(ReportTypeLabels.visualShort),
                ),
                ButtonSegment(
                  value: ReportTypeLabels.functionalShort,
                  label: Text(ReportTypeLabels.functionalShort),
                ),
              ],
              selected: {report},
              onSelectionChanged: (value) =>
                  setState(() => report = value.first),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children:
                  [
                        'Todas',
                        'identificación',
                        'acceso',
                        'panorámica',
                        'vistaGeneral',
                        'medidor',
                        'válvula',
                        'daños',
                        'montaje general',
                        'banco de pruebas',
                        'instrumentos',
                        'manómetros',
                        'caudalímetro patrón',
                        'conexión',
                        'presión',
                        'caudal',
                        'válvula abierta',
                        'válvula cerrada',
                        'reductora',
                        'solenoide',
                        'energía',
                        'comunicación',
                        'telemetría',
                        'alarma',
                        'fuga',
                        'reparación',
                        'estado final',
                        'condición impeditiva',
                        'otro',
                      ]
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: category == item,
                            onSelected: (_) => setState(() => category = item),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No hay fotografías para este filtro.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, index) => _PhotoTile(photo: items[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final InspectionPhoto photo;
  @override
  Widget build(BuildContext context) {
    final file = File(photo.thumbnailPath);
    return Card(
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _PhotoViewer(photo: photo),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: AppColors.border,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.red,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${photo.category} · ${photo.syncStatus.name}',
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});
  final InspectionPhoto photo;
  String get shortHash => photo.sha256.length > 12
      ? '${photo.sha256.substring(0, 12)}…'
      : photo.sha256;
  String get reportLabel => photo.inspectionType == 'f02B'
      ? ReportTypeLabels.functionalFull
      : ReportTypeLabels.visualFull;
  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(photo.category),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Image.file(
            File(photo.localPath),
            errorBuilder: (_, _, _) => const SizedBox(
              height: 220,
              child: Center(
                child: Icon(Icons.broken_image, color: AppColors.red),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hidrante: ${photo.hydrantId}\nReporte: $reportLabel\nUsuario: ${photo.capturedByName}\nBrigada: ${photo.brigadeId}\nFecha: ${photo.capturedAt.toLocal()}\nTamaño: ${photo.fileSize} bytes\nDimensiones: ${photo.width} × ${photo.height}\nSHA-256: $shortHash\nEstado: ${photo.syncStatus.name}',
          ),
        ],
      ),
    ),
  );
}
