import '../enums/app_enums.dart';

enum MatchAnswer { yes, no, unknown }

enum IdentificationStatus {
  readablePlate,
  unreadablePlate,
  noPlate,
  differentCode,
}

enum RtkStatus { simulatedFixed, simulatedFloat, autonomous, unavailable }

enum RoadType { pavement, dirtRoad, trail, parcel, other }

enum PhysicalCondition { good, fair, bad, critical, unknown }

enum OperationState { works, doesNotWork, unverified, unavailable }

enum FinalClassification { operational, observations, nonOperational, critical }

class HydrantIdentification {
  const HydrantIdentification({
    this.assignedCode,
    this.observedCode,
    this.matchesAssignment,
    this.status,
    this.identificationPhotoId,
    this.comments = '',
  });
  final String? assignedCode, observedCode, identificationPhotoId;
  final MatchAnswer? matchesAssignment;
  final IdentificationStatus? status;
  final String comments;
  Map<String, dynamic> toJson() => {
    'assignedCode': assignedCode,
    'observedCode': observedCode,
    'matchesAssignment': matchesAssignment?.name,
    'status': status?.name,
    'identificationPhotoId': identificationPhotoId,
    'comments': comments,
  };
  factory HydrantIdentification.fromJson(Map<String, dynamic> j) =>
      HydrantIdentification(
        assignedCode: j['assignedCode'] as String?,
        observedCode: j['observedCode'] as String?,
        matchesAssignment: _enumOrNull(
          MatchAnswer.values,
          j['matchesAssignment'],
        ),
        status: _enumOrNull(IdentificationStatus.values, j['status']),
        identificationPhotoId: j['identificationPhotoId'] as String?,
        comments: j['comments'] as String? ?? '',
      );
}

class GeoReference {
  const GeoReference({
    this.latitude,
    this.longitude,
    this.utmEast,
    this.utmNorth,
    this.utmZone,
    this.datum = 'WGS84',
    this.elevation,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.rtkStatus = RtkStatus.unavailable,
    this.capturedAt,
    this.capturedBy,
    this.omissionJustification,
    this.pendingGeoreference = false,
    this.comments = '',
  });
  final double? latitude,
      longitude,
      utmEast,
      utmNorth,
      elevation,
      horizontalAccuracy,
      verticalAccuracy;
  final String? utmZone, capturedBy, omissionJustification;
  final String datum, comments;
  final RtkStatus rtkStatus;
  final DateTime? capturedAt;
  final bool pendingGeoreference;
  bool get hasValidPosition =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'utmEast': utmEast,
    'utmNorth': utmNorth,
    'utmZone': utmZone,
    'datum': datum,
    'elevation': elevation,
    'horizontalAccuracy': horizontalAccuracy,
    'verticalAccuracy': verticalAccuracy,
    'rtkStatus': rtkStatus.name,
    'capturedAt': capturedAt?.toUtc().toIso8601String(),
    'capturedBy': capturedBy,
    'omissionJustification': omissionJustification,
    'pendingGeoreference': pendingGeoreference,
    'comments': comments,
  };
  factory GeoReference.fromJson(Map<String, dynamic> j) => GeoReference(
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    utmEast: (j['utmEast'] as num?)?.toDouble(),
    utmNorth: (j['utmNorth'] as num?)?.toDouble(),
    utmZone: j['utmZone'] as String?,
    datum: j['datum'] as String? ?? 'WGS84',
    elevation: (j['elevation'] as num?)?.toDouble(),
    horizontalAccuracy: (j['horizontalAccuracy'] as num?)?.toDouble(),
    verticalAccuracy: (j['verticalAccuracy'] as num?)?.toDouble(),
    rtkStatus: _enum(RtkStatus.values, j['rtkStatus'], RtkStatus.unavailable),
    capturedAt: DateTime.tryParse(j['capturedAt'] as String? ?? '')?.toUtc(),
    capturedBy: j['capturedBy'] as String?,
    omissionJustification: j['omissionJustification'] as String?,
    pendingGeoreference: j['pendingGeoreference'] as bool? ?? false,
    comments: j['comments'] as String? ?? '',
  );
}

class AccessAssessment {
  const AccessAssessment({
    this.accessType,
    this.roadType,
    this.condition,
    this.risks = const [],
    this.comments = '',
  });
  final AccessType? accessType;
  final RoadType? roadType;
  final PhysicalCondition? condition;
  final List<String> risks;
  final String comments;
  Map<String, dynamic> toJson() => {
    'accessType': accessType?.name,
    'roadType': roadType?.name,
    'condition': condition?.name,
    'risks': risks,
    'comments': comments,
  };
  factory AccessAssessment.fromJson(Map<String, dynamic> j) => AccessAssessment(
    accessType: _enumOrNull(AccessType.values, j['accessType']),
    roadType: _enumOrNull(RoadType.values, j['roadType']),
    condition: _enumOrNull(PhysicalCondition.values, j['condition']),
    risks: (j['risks'] as List? ?? []).cast<String>(),
    comments: j['comments'] as String? ?? '',
  );
}

class FlowMeterAssessment {
  const FlowMeterAssessment({
    this.exists,
    this.condition,
    this.operation,
    this.diameter,
    this.brand,
    this.model,
    this.serialNumber,
    this.serialCaptureMethod,
    this.sendsMobileSignal,
    this.hasModbus,
    this.wiringCondition,
    this.comments = '',
  });
  final bool? exists, sendsMobileSignal, hasModbus;
  final PhysicalCondition? condition, wiringCondition;
  final OperationState? operation;
  final String? diameter, brand, model, serialNumber, serialCaptureMethod;
  final String comments;
  Map<String, dynamic> toJson() => {
    'exists': exists,
    'condition': condition?.name,
    'operation': operation?.name,
    'diameter': diameter,
    'brand': brand,
    'model': model,
    'serialNumber': serialNumber,
    'serialCaptureMethod': serialCaptureMethod,
    'sendsMobileSignal': sendsMobileSignal,
    'hasModbus': hasModbus,
    'wiringCondition': wiringCondition?.name,
    'comments': comments,
  };
  factory FlowMeterAssessment.fromJson(Map<String, dynamic> j) =>
      FlowMeterAssessment(
        exists: j['exists'] as bool?,
        condition: _enumOrNull(PhysicalCondition.values, j['condition']),
        operation: _enumOrNull(OperationState.values, j['operation']),
        diameter: j['diameter'] as String?,
        brand: j['brand'] as String?,
        model: j['model'] as String?,
        serialNumber: j['serialNumber'] as String?,
        serialCaptureMethod: j['serialCaptureMethod'] as String?,
        sendsMobileSignal: j['sendsMobileSignal'] as bool?,
        hasModbus: j['hasModbus'] as bool?,
        wiringCondition: _enumOrNull(
          PhysicalCondition.values,
          j['wiringCondition'],
        ),
        comments: j['comments'] as String? ?? '',
      );
}

class PressureValveAssessment {
  const PressureValveAssessment({
    this.exists,
    this.quantity = 0,
    this.condition,
    this.manualOperation,
    this.automaticOperation,
    this.solenoidExists,
    this.solenoidQuantity = 0,
    this.solenoidType,
    this.automaticSignal,
    this.communicationType,
    this.leakageLevel,
    this.comments = '',
  });
  final bool? exists, solenoidExists, automaticSignal;
  final int quantity, solenoidQuantity;
  final PhysicalCondition? condition;
  final OperationState? manualOperation, automaticOperation;
  final String? solenoidType, communicationType, leakageLevel;
  final String comments;
  Map<String, dynamic> toJson() => {
    'exists': exists,
    'quantity': quantity,
    'condition': condition?.name,
    'manualOperation': manualOperation?.name,
    'automaticOperation': automaticOperation?.name,
    'solenoidExists': solenoidExists,
    'solenoidQuantity': solenoidQuantity,
    'solenoidType': solenoidType,
    'automaticSignal': automaticSignal,
    'communicationType': communicationType,
    'leakageLevel': leakageLevel,
    'comments': comments,
  };
  factory PressureValveAssessment.fromJson(Map<String, dynamic> j) =>
      PressureValveAssessment(
        exists: j['exists'] as bool?,
        quantity: j['quantity'] as int? ?? 0,
        condition: _enumOrNull(PhysicalCondition.values, j['condition']),
        manualOperation: _enumOrNull(
          OperationState.values,
          j['manualOperation'],
        ),
        automaticOperation: _enumOrNull(
          OperationState.values,
          j['automaticOperation'],
        ),
        solenoidExists: j['solenoidExists'] as bool?,
        solenoidQuantity: j['solenoidQuantity'] as int? ?? 0,
        solenoidType: j['solenoidType'] as String?,
        automaticSignal: j['automaticSignal'] as bool?,
        communicationType: j['communicationType'] as String?,
        leakageLevel: j['leakageLevel'] as String?,
        comments: j['comments'] as String? ?? '',
      );
}

class EnergyCommunicationAssessment {
  const EnergyCommunicationAssessment({
    this.energyAvailable,
    this.sources = const [],
    this.voltage,
    this.nearbyPole,
    this.transformerExists,
    this.transformerCapacity,
    this.availableNetworks = const [],
    this.signalStrength,
    this.modemStatus,
    this.internetAvailable,
    this.comments = '',
  });
  final bool? energyAvailable, nearbyPole, transformerExists, internetAvailable;
  final List<String> sources, availableNetworks;
  final String? voltage, transformerCapacity, signalStrength, modemStatus;
  final String comments;
  Map<String, dynamic> toJson() => {
    'energyAvailable': energyAvailable,
    'sources': sources,
    'voltage': voltage,
    'nearbyPole': nearbyPole,
    'transformerExists': transformerExists,
    'transformerCapacity': transformerCapacity,
    'availableNetworks': availableNetworks,
    'signalStrength': signalStrength,
    'modemStatus': modemStatus,
    'internetAvailable': internetAvailable,
    'comments': comments,
  };
  factory EnergyCommunicationAssessment.fromJson(Map<String, dynamic> j) =>
      EnergyCommunicationAssessment(
        energyAvailable: j['energyAvailable'] as bool?,
        sources: (j['sources'] as List? ?? []).cast<String>(),
        voltage: j['voltage'] as String?,
        nearbyPole: j['nearbyPole'] as bool?,
        transformerExists: j['transformerExists'] as bool?,
        transformerCapacity: j['transformerCapacity'] as String?,
        availableNetworks: (j['availableNetworks'] as List? ?? [])
            .cast<String>(),
        signalStrength: j['signalStrength'] as String?,
        modemStatus: j['modemStatus'] as String?,
        internetAvailable: j['internetAvailable'] as bool?,
        comments: j['comments'] as String? ?? '',
      );
}

class VisualInspectionResult {
  const VisualInspectionResult({
    this.classification,
    this.requiresTechnicalInspection = false,
    this.technicalInspectionReasons = const [],
    this.supervisorReviewRequired = false,
    this.finalComments = '',
  });
  final FinalClassification? classification;
  final bool requiresTechnicalInspection, supervisorReviewRequired;
  final List<String> technicalInspectionReasons;
  final String finalComments;
  Map<String, dynamic> toJson() => {
    'classification': classification?.name,
    'requiresTechnicalInspection': requiresTechnicalInspection,
    'technicalInspectionReasons': technicalInspectionReasons,
    'supervisorReviewRequired': supervisorReviewRequired,
    'finalComments': finalComments,
  };
  factory VisualInspectionResult.fromJson(Map<String, dynamic> j) =>
      VisualInspectionResult(
        classification: _enumOrNull(
          FinalClassification.values,
          j['classification'],
        ),
        requiresTechnicalInspection:
            j['requiresTechnicalInspection'] as bool? ?? false,
        technicalInspectionReasons:
            (j['technicalInspectionReasons'] as List? ?? []).cast<String>(),
        supervisorReviewRequired:
            j['supervisorReviewRequired'] as bool? ?? false,
        finalComments: j['finalComments'] as String? ?? '',
      );
}

class VisualInspection {
  const VisualInspection({
    required this.id,
    required this.hydrantId,
    this.assignmentId,
    required this.source,
    this.status = InspectionStatus.inProgress,
    this.currentStep = 1,
    this.inspectorId = '',
    this.inspectorName = '',
    this.brigadeId = '',
    this.brigadeName = '',
    this.deviceId = '',
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    this.createdBy = '',
    required this.updatedAt,
    this.updatedBy = '',
    this.schemaVersion = 1,
    this.identification = const HydrantIdentification(),
    this.geoReference = const GeoReference(),
    this.access = const AccessAssessment(),
    this.flowMeter = const FlowMeterAssessment(),
    this.pressureValve = const PressureValveAssessment(),
    this.energyCommunication = const EnergyCommunicationAssessment(),
    this.damageIds = const [],
    this.photoIds = const [],
    this.result = const VisualInspectionResult(),
    this.closureComments = '',
    this.noVisibleDamageConfirmed = false,
  });
  final String id,
      hydrantId,
      inspectorId,
      inspectorName,
      brigadeId,
      brigadeName,
      deviceId,
      createdBy,
      updatedBy,
      closureComments;
  final bool noVisibleDamageConfirmed;
  final String? assignmentId;
  final HydrantSource source;
  final InspectionStatus status;
  final int currentStep, schemaVersion;
  final DateTime startedAt, createdAt, updatedAt;
  final DateTime? completedAt;
  final HydrantIdentification identification;
  final GeoReference geoReference;
  final AccessAssessment access;
  final FlowMeterAssessment flowMeter;
  final PressureValveAssessment pressureValve;
  final EnergyCommunicationAssessment energyCommunication;
  final List<String> damageIds, photoIds;
  final VisualInspectionResult result;
  double get progress => currentStep.clamp(1, 8) / 8;
  VisualInspection copyWith({
    InspectionStatus? status,
    int? currentStep,
    DateTime? completedAt,
    DateTime? updatedAt,
    HydrantIdentification? identification,
    GeoReference? geoReference,
    AccessAssessment? access,
    FlowMeterAssessment? flowMeter,
    PressureValveAssessment? pressureValve,
    EnergyCommunicationAssessment? energyCommunication,
    List<String>? damageIds,
    List<String>? photoIds,
    VisualInspectionResult? result,
    String? closureComments,
    bool? noVisibleDamageConfirmed,
  }) => VisualInspection(
    id: id,
    hydrantId: hydrantId,
    assignmentId: assignmentId,
    source: source,
    status: status ?? this.status,
    currentStep: currentStep ?? this.currentStep,
    inspectorId: inspectorId,
    inspectorName: inspectorName,
    brigadeId: brigadeId,
    brigadeName: brigadeName,
    deviceId: deviceId,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    createdAt: createdAt,
    createdBy: createdBy,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    updatedBy: updatedBy,
    schemaVersion: schemaVersion,
    identification: identification ?? this.identification,
    geoReference: geoReference ?? this.geoReference,
    access: access ?? this.access,
    flowMeter: flowMeter ?? this.flowMeter,
    pressureValve: pressureValve ?? this.pressureValve,
    energyCommunication: energyCommunication ?? this.energyCommunication,
    damageIds: damageIds ?? this.damageIds,
    photoIds: photoIds ?? this.photoIds,
    result: result ?? this.result,
    closureComments: closureComments ?? this.closureComments,
    noVisibleDamageConfirmed:
        noVisibleDamageConfirmed ?? this.noVisibleDamageConfirmed,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'hydrantId': hydrantId,
    'assignmentId': assignmentId,
    'source': source.name,
    'status': status.name,
    'currentStep': currentStep,
    'inspectorId': inspectorId,
    'inspectorName': inspectorName,
    'brigadeId': brigadeId,
    'brigadeName': brigadeName,
    'deviceId': deviceId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'createdBy': createdBy,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedBy': updatedBy,
    'schemaVersion': schemaVersion,
    'identification': identification.toJson(),
    'geoReference': geoReference.toJson(),
    'access': access.toJson(),
    'flowMeter': flowMeter.toJson(),
    'pressureValve': pressureValve.toJson(),
    'energyCommunication': energyCommunication.toJson(),
    'damageIds': damageIds,
    'photoIds': photoIds,
    'result': result.toJson(),
    'closureComments': closureComments,
    'noVisibleDamageConfirmed': noVisibleDamageConfirmed,
  };
  factory VisualInspection.fromJson(Map<String, dynamic> j) => VisualInspection(
    id: j['id'] as String,
    hydrantId: j['hydrantId'] as String,
    assignmentId: j['assignmentId'] as String?,
    source: _enum(HydrantSource.values, j['source'], HydrantSource.assigned),
    status: _enum(
      InspectionStatus.values,
      j['status'],
      InspectionStatus.inProgress,
    ),
    currentStep: j['currentStep'] as int? ?? 1,
    inspectorId: j['inspectorId'] as String? ?? '',
    inspectorName: j['inspectorName'] as String? ?? '',
    brigadeId: j['brigadeId'] as String? ?? '',
    brigadeName: j['brigadeName'] as String? ?? '',
    deviceId: j['deviceId'] as String? ?? '',
    startedAt: _date(j['startedAt']),
    completedAt: DateTime.tryParse(j['completedAt'] as String? ?? '')?.toUtc(),
    createdAt: _date(j['createdAt']),
    createdBy: j['createdBy'] as String? ?? '',
    updatedAt: _date(j['updatedAt']),
    updatedBy: j['updatedBy'] as String? ?? '',
    schemaVersion: j['schemaVersion'] as int? ?? 1,
    identification: HydrantIdentification.fromJson(
      Map<String, dynamic>.from(j['identification'] as Map? ?? {}),
    ),
    geoReference: GeoReference.fromJson(
      Map<String, dynamic>.from(j['geoReference'] as Map? ?? {}),
    ),
    access: AccessAssessment.fromJson(
      Map<String, dynamic>.from(j['access'] as Map? ?? {}),
    ),
    flowMeter: FlowMeterAssessment.fromJson(
      Map<String, dynamic>.from(j['flowMeter'] as Map? ?? {}),
    ),
    pressureValve: PressureValveAssessment.fromJson(
      Map<String, dynamic>.from(j['pressureValve'] as Map? ?? {}),
    ),
    energyCommunication: EnergyCommunicationAssessment.fromJson(
      Map<String, dynamic>.from(j['energyCommunication'] as Map? ?? {}),
    ),
    damageIds: (j['damageIds'] as List? ?? []).cast<String>(),
    photoIds: (j['photoIds'] as List? ?? []).cast<String>(),
    result: VisualInspectionResult.fromJson(
      Map<String, dynamic>.from(j['result'] as Map? ?? {}),
    ),
    closureComments: j['closureComments'] as String? ?? '',
    noVisibleDamageConfirmed: j['noVisibleDamageConfirmed'] as bool? ?? false,
  );
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toUtc() ??
    DateTime.now().toUtc();
