import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../../core/persistence/versioned_json_codec.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/inspections/visual_inspection.dart';
import '../../domain/models/app_models.dart';

class VisualInspectionRepository {
  VisualInspectionRepository({required this.documents, required this.index});

  final Box<String> documents;
  final Box<String> index;

  String _indexKey(String hydrantId) => '$hydrantId:f02A';

  bool hasLocalInspection(String hydrantId) {
    final id = index.get(_indexKey(hydrantId));
    return id != null && documents.containsKey(id);
  }

  Future<VisualInspection> openOrCreate(Hydrant hydrant, AppUser user) async {
    final existingId = index.get(_indexKey(hydrant.id));
    if (existingId != null) {
      final raw = documents.get(existingId);
      if (raw != null) {
        return VisualInspection.fromJson(
          VersionedJsonCodec.decode(raw).payload,
        );
      }
    }
    if (hydrant.f02a.status == InspectionStatus.completed) {
      for (final raw in documents.values) {
        try {
          final candidate = VisualInspection.fromJson(
            VersionedJsonCodec.decode(raw).payload,
          );
          if (candidate.hydrantId == hydrant.id &&
              candidate.status == InspectionStatus.completed) {
            return candidate;
          }
        } on FormatException {
          continue;
        }
      }
    }
    final now = DateTime.now().toUtc();
    final inspection = VisualInspection(
      id: const Uuid().v4(),
      hydrantId: hydrant.id,
      assignmentId: hydrant.source == HydrantSource.assigned
          ? hydrant.id
          : null,
      source: hydrant.source,
      inspectorId: user.id,
      inspectorName: user.fullName,
      brigadeId: user.brigadeId,
      brigadeName: user.brigadeName,
      deviceId: user.deviceId,
      startedAt: now,
      createdAt: now,
      createdBy: user.id,
      updatedAt: now,
      updatedBy: user.id,
      identification: HydrantIdentification(assignedCode: hydrant.code),
    );
    await save(inspection);
    await index.put(_indexKey(hydrant.id), inspection.id);
    return inspection;
  }

  Future<void> save(VisualInspection inspection) async {
    final encoded = VersionedJsonCodec.encode(
      schemaVersion: inspection.schemaVersion,
      payload: inspection.toJson(),
    );
    final previous = documents.get(inspection.id);
    if (previous != null &&
        VersionedJsonCodec.decode(previous).schemaVersion !=
            inspection.schemaVersion) {
      final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
      await documents.put('${inspection.id}:previous:$stamp', previous);
    }
    await documents.put(inspection.id, encoded);
    final confirmed = documents.get(inspection.id);
    if (confirmed == null) {
      throw StateError('No fue posible confirmar la escritura del borrador.');
    }
    VersionedJsonCodec.decode(confirmed);
  }

  Future<void> finalize(VisualInspection inspection) async {
    await save(inspection);
    final confirmed = documents.get(inspection.id);
    if (confirmed == null ||
        VisualInspection.fromJson(
              VersionedJsonCodec.decode(confirmed).payload,
            ).status !=
            InspectionStatus.completed) {
      throw StateError('No fue posible confirmar la finalización local.');
    }
    await index.delete(_indexKey(inspection.hydrantId));
  }
}
