import '../enums/app_enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.brigadeId,
    required this.brigadeName,
    required this.deviceId,
  });
  final String id, fullName, email, role, brigadeId, brigadeName, deviceId;
}

class InspectionSummary {
  const InspectionSummary({
    required this.type,
    required this.status,
    required this.progress,
  });
  final InspectionType type;
  final InspectionStatus status;
  final double progress;
}

class Hydrant {
  const Hydrant({
    required this.id,
    required this.code,
    required this.locality,
    required this.parcel,
    required this.priority,
    required this.access,
    required this.syncStatus,
    required this.f02a,
    required this.f02b,
    required this.latitude,
    required this.longitude,
    this.damageCount = 0,
    this.photoCount = 0,
  });
  final String id, code, locality, parcel;
  final PriorityLevel priority;
  final AccessType access;
  final SyncStatus syncStatus;
  final InspectionSummary f02a, f02b;
  final double latitude, longitude;
  final int damageCount, photoCount;
}

class TraceEvent {
  const TraceEvent({
    required this.id,
    required this.action,
    required this.description,
    required this.createdAt,
    required this.userId,
    required this.brigadeName,
    required this.deviceId,
    this.hydrantId,
    this.syncStatus = SyncStatus.pending,
  });
  final String id, action, description, userId, brigadeName, deviceId;
  final String? hydrantId;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'description': description,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'userId': userId,
    'brigadeName': brigadeName,
    'deviceId': deviceId,
    'hydrantId': hydrantId,
    'syncStatus': syncStatus.name,
  };
}

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.buildNumber,
    required this.title,
    required this.message,
    required this.status,
  });
  final String latestVersion, minimumSupportedVersion, title, message;
  final int buildNumber;
  final UpdateStatus status;
}
