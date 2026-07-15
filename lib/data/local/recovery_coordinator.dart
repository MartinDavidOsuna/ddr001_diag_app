import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../../core/persistence/versioned_json_codec.dart';
import '../../domain/integrity/integrity_models.dart';
import '../../domain/integrity/operation_journal.dart';
import 'integrity_audit_service.dart';
import 'operation_journal_repository.dart';
import 'quarantine_repository.dart';

class RecoverySummary {
  const RecoverySummary({
    required this.audit,
    required this.repaired,
    required this.quarantined,
    required this.requiresManualReview,
  });
  final IntegrityAuditReport audit;
  final int repaired, quarantined, requiresManualReview;
}

class RecoveryCoordinator {
  const RecoveryCoordinator({
    required this.auditService,
    required this.journal,
    required this.quarantine,
  });
  final IntegrityAuditService auditService;
  final OperationJournalRepository journal;
  final QuarantineRepository quarantine;

  Future<RecoverySummary> runLightweight() async {
    final report = auditService.runLightweight();
    var repaired = 0, quarantined = 0, manual = 0;
    for (final issue in report.issues) {
      switch (issue.recommendedAction) {
        case RecoveryAction.recreateIndex:
          final box = issue.entityType == 'visualInspection'
              ? Hive.box<String>('active_inspection_index_v1')
              : Hive.box<String>('active_functional_inspection_index_v1');
          final documents = issue.entityType == 'visualInspection'
              ? Hive.box<String>('visual_inspections_v1')
              : Hive.box<String>('functional_inspections_v1');
          final raw = documents.get(issue.entityId);
          if (raw != null) {
            final payload = VersionedJsonCodec.decode(raw).payload;
            final hydrantId = payload['hydrantId'] as String?;
            if (hydrantId != null) {
              await box.put(
                '$hydrantId:${issue.entityType == 'visualInspection' ? 'f02A' : 'f02B'}',
                issue.entityId,
              );
              repaired++;
            }
          }
        case RecoveryAction.removeOrphanIndex:
          final box = issue.entityType == 'visualInspection'
              ? Hive.box<String>('active_inspection_index_v1')
              : Hive.box<String>('active_functional_inspection_index_v1');
          final keys = box.keys.where((key) => box.get(key) == issue.entityId);
          for (final key in keys.toList()) {
            await box.delete(key);
          }
          repaired++;
        case RecoveryAction.enqueuePhoto:
          await Hive.box<String>('media_work_queue_v1').put(
            issue.entityId,
            jsonEncode({
              'photoId': issue.entityId,
              'status': 'pendingRecovery',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
          );
          repaired++;
        case RecoveryAction.quarantineDocument:
          final box = Hive.box<String>(issue.entityType);
          final raw = box.get(issue.entityId);
          if (raw != null) {
            await quarantine.preserve(
              sourceBox: issue.entityType,
              sourceKey: issue.entityId,
              originalDocument: raw,
              errorType: issue.type.name,
              technicalMessage: issue.technicalMessage,
            );
            quarantined++;
          }
        default:
          manual++;
      }
    }
    for (final entry in journal.pending()) {
      if (entry.status == JournalStatus.queueWritten) {
        await journal.save(entry.advance(JournalStatus.committed));
        repaired++;
      } else if (entry.status != JournalStatus.needsRecovery) {
        await journal.save(
          entry.advance(
            JournalStatus.needsRecovery,
            error:
                'Revisión ligera no pudo completar la operación inequívocamente.',
          ),
        );
      }
    }
    return RecoverySummary(
      audit: report,
      repaired: repaired,
      quarantined: quarantined,
      requiresManualReview: manual,
    );
  }
}
