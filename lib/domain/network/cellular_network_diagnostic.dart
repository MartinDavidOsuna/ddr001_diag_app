enum CellularDiagnosticStatus {
  idle,
  preparing,
  analyzing,
  available,
  noCellularNetworksAvailable,
  indeterminate,
  cancelled,
  failed,
}

enum CellularDiagnosticStage {
  preparing,
  checkingPermissions,
  checkingCellularInterface,
  waitingForRegistration,
  analyzingSignal,
  checkingCellularConnectivity,
  calculatingResult,
  completed,
}

enum CellularInternetStatus {
  available,
  unavailable,
  indeterminate,
  pending,
  cancelled,
}

class CellularNetworkDiagnostic {
  const CellularNetworkDiagnostic({
    required this.id,
    required this.inspectionId,
    this.status = CellularDiagnosticStatus.idle,
    this.stage = CellularDiagnosticStage.preparing,
    this.startedAt,
    this.completedAt,
    this.timeoutSeconds = 60,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 60,
    this.timeoutReached = false,
    this.interfaceAvailable,
    this.registeredOnNetwork,
    this.operatorName,
    this.networkTechnology,
    this.signalValue,
    this.signalUnit,
    this.qualityScore,
    this.qualityLabel,
    this.internetStatus = CellularInternetStatus.pending,
    this.latencyMs,
    this.attempts = 0,
    this.successfulAttempts = 0,
    this.effectivenessPercentage,
    this.method = 'cellular-diagnostics-demo-v1',
    this.errorCode,
    this.errorMessage,
    this.permissionState = 'notRequiredByCurrentApi',
    this.platformLimitations = const [],
    this.progress = 0,
    this.schemaVersion = 1,
  });

  final String id, inspectionId, method, permissionState;
  final CellularDiagnosticStatus status;
  final CellularDiagnosticStage stage;
  final DateTime? startedAt, completedAt;
  final int timeoutSeconds, elapsedSeconds, remainingSeconds, attempts;
  final int successfulAttempts, schemaVersion;
  final bool timeoutReached;
  final bool? interfaceAvailable, registeredOnNetwork;
  final String? operatorName, networkTechnology, signalUnit, qualityLabel;
  final String? errorCode, errorMessage;
  final double? signalValue, effectivenessPercentage, progress;
  final int? qualityScore, latencyMs;
  final CellularInternetStatus internetStatus;
  final List<String> platformLimitations;

  bool get isRunning =>
      status == CellularDiagnosticStatus.preparing ||
      status == CellularDiagnosticStatus.analyzing;

  CellularNetworkDiagnostic copyWith({
    CellularDiagnosticStatus? status,
    CellularDiagnosticStage? stage,
    DateTime? startedAt,
    DateTime? completedAt,
    int? elapsedSeconds,
    int? remainingSeconds,
    bool? timeoutReached,
    bool? interfaceAvailable,
    bool? registeredOnNetwork,
    String? operatorName,
    String? networkTechnology,
    double? signalValue,
    String? signalUnit,
    int? qualityScore,
    String? qualityLabel,
    CellularInternetStatus? internetStatus,
    int? latencyMs,
    int? attempts,
    int? successfulAttempts,
    double? effectivenessPercentage,
    String? errorCode,
    String? errorMessage,
    List<String>? platformLimitations,
    double? progress,
  }) => CellularNetworkDiagnostic(
    id: id,
    inspectionId: inspectionId,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    timeoutSeconds: timeoutSeconds,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    timeoutReached: timeoutReached ?? this.timeoutReached,
    interfaceAvailable: interfaceAvailable ?? this.interfaceAvailable,
    registeredOnNetwork: registeredOnNetwork ?? this.registeredOnNetwork,
    operatorName: operatorName ?? this.operatorName,
    networkTechnology: networkTechnology ?? this.networkTechnology,
    signalValue: signalValue ?? this.signalValue,
    signalUnit: signalUnit ?? this.signalUnit,
    qualityScore: qualityScore ?? this.qualityScore,
    qualityLabel: qualityLabel ?? this.qualityLabel,
    internetStatus: internetStatus ?? this.internetStatus,
    latencyMs: latencyMs ?? this.latencyMs,
    attempts: attempts ?? this.attempts,
    successfulAttempts: successfulAttempts ?? this.successfulAttempts,
    effectivenessPercentage:
        effectivenessPercentage ?? this.effectivenessPercentage,
    method: method,
    errorCode: errorCode ?? this.errorCode,
    errorMessage: errorMessage ?? this.errorMessage,
    permissionState: permissionState,
    platformLimitations: platformLimitations ?? this.platformLimitations,
    progress: progress ?? this.progress,
    schemaVersion: schemaVersion,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'status': status.name,
    'stage': stage.name,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'timeoutSeconds': timeoutSeconds,
    'elapsedSeconds': elapsedSeconds,
    'remainingSeconds': remainingSeconds,
    'timeoutReached': timeoutReached,
    'interfaceAvailable': interfaceAvailable,
    'registeredOnNetwork': registeredOnNetwork,
    'operatorName': operatorName,
    'networkTechnology': networkTechnology,
    'signalValue': signalValue,
    'signalUnit': signalUnit,
    'qualityScore': qualityScore,
    'qualityLabel': qualityLabel,
    'internetStatus': internetStatus.name,
    'latencyMs': latencyMs,
    'attempts': attempts,
    'successfulAttempts': successfulAttempts,
    'effectivenessPercentage': effectivenessPercentage,
    'method': method,
    'errorCode': errorCode,
    'errorMessage': errorMessage,
    'permissionState': permissionState,
    'platformLimitations': platformLimitations,
    'progress': progress,
    'schemaVersion': schemaVersion,
  };

  factory CellularNetworkDiagnostic.fromJson(Map<String, dynamic> json) =>
      CellularNetworkDiagnostic(
        id: json['id'] as String? ?? '',
        inspectionId: json['inspectionId'] as String? ?? '',
        status: _enumValue(
          CellularDiagnosticStatus.values,
          json['status'],
          CellularDiagnosticStatus.idle,
        ),
        stage: _enumValue(
          CellularDiagnosticStage.values,
          json['stage'],
          CellularDiagnosticStage.preparing,
        ),
        startedAt: DateTime.tryParse(
          json['startedAt'] as String? ?? '',
        )?.toUtc(),
        completedAt: DateTime.tryParse(
          json['completedAt'] as String? ?? '',
        )?.toUtc(),
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 60,
        elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
        remainingSeconds: json['remainingSeconds'] as int? ?? 60,
        timeoutReached: json['timeoutReached'] as bool? ?? false,
        interfaceAvailable: json['interfaceAvailable'] as bool?,
        registeredOnNetwork: json['registeredOnNetwork'] as bool?,
        operatorName: json['operatorName'] as String?,
        networkTechnology: json['networkTechnology'] as String?,
        signalValue: (json['signalValue'] as num?)?.toDouble(),
        signalUnit: json['signalUnit'] as String?,
        qualityScore: json['qualityScore'] as int?,
        qualityLabel: json['qualityLabel'] as String?,
        internetStatus: _enumValue(
          CellularInternetStatus.values,
          json['internetStatus'],
          CellularInternetStatus.pending,
        ),
        latencyMs: json['latencyMs'] as int?,
        attempts: json['attempts'] as int? ?? 0,
        successfulAttempts: json['successfulAttempts'] as int? ?? 0,
        effectivenessPercentage: (json['effectivenessPercentage'] as num?)
            ?.toDouble(),
        method: json['method'] as String? ?? 'cellular-diagnostics-demo-v1',
        errorCode: json['errorCode'] as String?,
        errorMessage: json['errorMessage'] as String?,
        permissionState:
            json['permissionState'] as String? ?? 'notRequiredByCurrentApi',
        platformLimitations: (json['platformLimitations'] as List? ?? [])
            .cast<String>(),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        schemaVersion: json['schemaVersion'] as int? ?? 1,
      );
}

class CellularNetworkQualityCalculator {
  const CellularNetworkQualityCalculator._();
  static const version = 'cellular-quality-demo-v1';

  static int? qualityFromDbm(double? dbm) {
    if (dbm == null) return null;
    if (dbm >= -70) return 10;
    if (dbm <= -120) return 1;
    return (((dbm + 120) / 50) * 9 + 1).round().clamp(1, 10);
  }

  static String? label(int? score) => switch (score) {
    1 || 2 => 'Muy mala',
    3 || 4 => 'Mala',
    5 || 6 => 'Regular',
    7 || 8 => 'Buena',
    9 || 10 => 'Excelente',
    _ => null,
  };

  static double? effectiveness({
    required bool? interfaceAvailable,
    required bool? registered,
    required int? qualityScore,
    required CellularInternetStatus internet,
    required int attempts,
    required int successfulAttempts,
  }) {
    final known = <({double earned, double possible})>[];
    if (interfaceAvailable != null) {
      known.add((earned: interfaceAvailable ? 25 : 0, possible: 25));
    }
    if (registered != null) {
      known.add((earned: registered ? 20 : 0, possible: 20));
    }
    if (qualityScore != null) {
      known.add((earned: qualityScore * 2.5, possible: 25));
    }
    if (internet != CellularInternetStatus.indeterminate &&
        internet != CellularInternetStatus.pending &&
        internet != CellularInternetStatus.cancelled) {
      known.add((
        earned: internet == CellularInternetStatus.available ? 20 : 0,
        possible: 20,
      ));
    }
    if (attempts > 0) {
      known.add((
        earned: (successfulAttempts / attempts).clamp(0, 1) * 10,
        possible: 10,
      ));
    }
    if (known.length < 3) return null;
    final earned = known.fold<double>(0, (sum, item) => sum + item.earned);
    final possible = known.fold<double>(0, (sum, item) => sum + item.possible);
    return (earned / possible * 100).clamp(0, 100);
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((value) => value.name == raw).firstOrNull ?? fallback;
