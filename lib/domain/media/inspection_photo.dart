import 'media_sync_status.dart';

class InspectionPhoto {
  const InspectionPhoto({
    required this.id,
    required this.hydrantId,
    required this.inspectionId,
    required this.category,
    required this.localPath,
    required this.mimeType,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.sha256,
    required this.processingProfileVersion,
    required this.capturedAt,
    required this.capturedByUserId,
    required this.brigadeId,
    required this.deviceId,
    required this.syncStatus,
    this.thumbnailPath,
  });
  final String id,
      hydrantId,
      inspectionId,
      category,
      localPath,
      mimeType,
      sha256,
      processingProfileVersion,
      capturedByUserId,
      brigadeId,
      deviceId;
  final String? thumbnailPath;
  final int fileSize, width, height;
  final DateTime capturedAt;
  final MediaSyncStatus syncStatus;
  bool get isSynchronized => syncStatus.isSynchronized;
}
