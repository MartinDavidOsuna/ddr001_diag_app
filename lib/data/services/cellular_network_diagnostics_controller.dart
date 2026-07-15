import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/network/cellular_network_diagnostic.dart';

typedef CellularDiagnosticPersist =
    Future<void> Function(CellularNetworkDiagnostic diagnostic);

class CellularNetworkDiagnosticsController extends ChangeNotifier {
  CellularNetworkDiagnosticsController({
    required String inspectionId,
    required this._persist,
    Connectivity? connectivity,
    CellularNetworkDiagnostic? restored,
  }) : _connectivity = connectivity ?? Connectivity(),
       diagnostic =
           restored ??
           CellularNetworkDiagnostic(
             id: const Uuid().v4(),
             inspectionId: inspectionId,
           );

  final Connectivity _connectivity;
  final CellularDiagnosticPersist _persist;
  CellularNetworkDiagnostic diagnostic;
  Timer? _countdown;
  Timer? _probe;
  bool _disposed = false;
  bool _finishing = false;

  bool get isRunning => diagnostic.isRunning;

  Future<void> start() async {
    if (isRunning || _finishing) return;
    _cancelTimers();
    final now = DateTime.now().toUtc();
    diagnostic = CellularNetworkDiagnostic(
      id: const Uuid().v4(),
      inspectionId: diagnostic.inspectionId,
      status: CellularDiagnosticStatus.preparing,
      stage: CellularDiagnosticStage.preparing,
      startedAt: now,
      attempts: diagnostic.attempts + 1,
      progress: .08,
    );
    _emit();
    await _persist(diagnostic);
    if (!isRunning) return;

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isRunning) return;
      final remaining = (diagnostic.remainingSeconds - 1).clamp(0, 60);
      final elapsed = 60 - remaining;
      diagnostic = diagnostic.copyWith(
        status: CellularDiagnosticStatus.analyzing,
        elapsedSeconds: elapsed.clamp(0, 60),
        remainingSeconds: remaining,
      );
      _emit();
      if (remaining == 0) unawaited(_finishTimeout());
    });

    await _setStage(CellularDiagnosticStage.checkingPermissions, .18);
    // connectivity_plus does not require nearby-Wi-Fi or telephony permissions.
    await _setStage(CellularDiagnosticStage.checkingCellularInterface, .35);
    await _probeCellular();
    if (!isRunning) return;
    await _setStage(CellularDiagnosticStage.waitingForRegistration, .5);
    _probe = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_probeCellular()),
    );
  }

  Future<void> _probeCellular() async {
    if (!isRunning || _finishing) return;
    try {
      final interfaces = await _connectivity.checkConnectivity();
      if (!isRunning) return;
      if (interfaces.contains(ConnectivityResult.mobile)) {
        await _finishAvailable();
      }
    } catch (error) {
      await _finishIndeterminate('platformError', '$error');
    }
  }

  Future<void> _finishAvailable() async {
    if (!isRunning || _finishing) return;
    _finishing = true;
    _cancelTimers();
    await _setStage(CellularDiagnosticStage.analyzingSignal, .65);
    await _setStage(CellularDiagnosticStage.checkingCellularConnectivity, .8);
    await _setStage(CellularDiagnosticStage.calculatingResult, .92);
    final elapsed = _elapsedNow();
    const limitations = [
      'La API disponible confirma una interfaz móvil del teléfono, no el módem del hidrante.',
      'Operador, registro, tecnología y señal no están expuestos por la integración actual.',
      'No puede aislarse una prueba de internet exclusivamente sobre datos móviles.',
    ];
    final effectiveness = CellularNetworkQualityCalculator.effectiveness(
      interfaceAvailable: true,
      registered: null,
      qualityScore: null,
      internet: CellularInternetStatus.indeterminate,
      attempts: diagnostic.attempts,
      successfulAttempts: diagnostic.successfulAttempts + 1,
    );
    diagnostic = diagnostic.copyWith(
      status: CellularDiagnosticStatus.available,
      stage: CellularDiagnosticStage.completed,
      completedAt: DateTime.now().toUtc(),
      elapsedSeconds: elapsed,
      remainingSeconds: (60 - elapsed).clamp(0, 60),
      interfaceAvailable: true,
      registeredOnNetwork: null,
      internetStatus: CellularInternetStatus.indeterminate,
      successfulAttempts: diagnostic.successfulAttempts + 1,
      effectivenessPercentage: effectiveness,
      platformLimitations: limitations,
      progress: 1,
    );
    _finishing = false;
    _emit();
    await _persist(diagnostic);
  }

  Future<void> _finishTimeout() async {
    if (!isRunning || _finishing) return;
    _finishing = true;
    _cancelTimers();
    diagnostic = diagnostic.copyWith(
      status: CellularDiagnosticStatus.noCellularNetworksAvailable,
      stage: CellularDiagnosticStage.completed,
      completedAt: DateTime.now().toUtc(),
      elapsedSeconds: 60,
      remainingSeconds: 0,
      timeoutReached: true,
      interfaceAvailable: false,
      internetStatus: CellularInternetStatus.unavailable,
      errorCode: 'noCellularNetworkObservedDuringTimeout',
      errorMessage: 'No se detectó una interfaz celular durante 60 segundos.',
      platformLimitations: const [
        'El resultado describe las interfaces observables en el teléfono y no prueba por sí solo el módem del hidrante.',
      ],
      progress: 1,
    );
    _finishing = false;
    _emit();
    await _persist(diagnostic);
  }

  Future<void> _finishIndeterminate(String code, String message) async {
    if (!isRunning || _finishing) return;
    _finishing = true;
    _cancelTimers();
    diagnostic = diagnostic.copyWith(
      status: CellularDiagnosticStatus.indeterminate,
      stage: CellularDiagnosticStage.completed,
      completedAt: DateTime.now().toUtc(),
      elapsedSeconds: _elapsedNow(),
      internetStatus: CellularInternetStatus.indeterminate,
      errorCode: code,
      errorMessage: message,
      progress: 1,
    );
    _finishing = false;
    _emit();
    await _persist(diagnostic);
  }

  Future<void> cancel({bool interrupted = false}) async {
    if (!isRunning) return;
    _cancelTimers();
    diagnostic = diagnostic.copyWith(
      status: CellularDiagnosticStatus.cancelled,
      stage: CellularDiagnosticStage.completed,
      completedAt: DateTime.now().toUtc(),
      elapsedSeconds: _elapsedNow(),
      internetStatus: CellularInternetStatus.cancelled,
      errorCode: interrupted ? 'interrupted' : 'cancelledByUser',
      errorMessage: interrupted
          ? 'El diagnóstico fue interrumpido al abandonar la pantalla.'
          : 'El diagnóstico fue cancelado por el técnico.',
      progress: 1,
    );
    _emit();
    await _persist(diagnostic);
  }

  Future<void> _setStage(CellularDiagnosticStage stage, double progress) async {
    if ((!isRunning && !_finishing) || _disposed) return;
    diagnostic = diagnostic.copyWith(
      status: CellularDiagnosticStatus.analyzing,
      stage: stage,
      progress: progress,
    );
    _emit();
  }

  int _elapsedNow() => diagnostic.startedAt == null
      ? 0
      : DateTime.now()
            .toUtc()
            .difference(diagnostic.startedAt!)
            .inSeconds
            .clamp(0, 60);

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _cancelTimers() {
    _countdown?.cancel();
    _probe?.cancel();
    _countdown = null;
    _probe = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
