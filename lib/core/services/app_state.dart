import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/mock/demo_data.dart';
import '../../domain/models/app_models.dart';
import 'update_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.preferences,
    required this.traceBox,
    required this.syncBox,
    required this.packageInfo,
  });
  final SharedPreferences preferences;
  final Box<String> traceBox, syncBox;
  final PackageInfo packageInfo;
  final updateService = UpdateService();
  final user = demoUser;
  final hydrants = demoHydrants;
  bool initialized = false, online = true, syncing = false;
  double syncProgress = 0;
  UpdateInfo? updateInfo;
  bool get authenticated => preferences.getBool('demo_session') ?? false;
  String get versionLabel =>
      '${packageInfo.version}+${packageInfo.buildNumber}';
  int get pendingCount => syncBox.length;

  Future<void> initialize() async {
    if (syncBox.isEmpty) {
      await syncBox.put('DDR001-HID-0002', 'Guardado localmente');
      await syncBox.put('DDR001-HID-0491', 'Guardado localmente');
    }
    updateInfo = await updateService.check(packageInfo.version);
    initialized = true;
    notifyListeners();
  }

  Future<bool> login(
    String email,
    String password, {
    required bool remember,
  }) async {
    final valid =
        email.trim().toLowerCase() == 'inspector.demo@ddr001.mx' &&
        password == 'demo123';
    if (!valid) return false;
    await preferences.setBool('demo_session', true);
    await preferences.setBool('remember_session', remember);
    await trace('login', 'Inicio de sesión demo');
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await trace('logout', 'Cierre de sesión');
    await preferences.setBool('demo_session', false);
    notifyListeners();
  }

  void toggleConnection() {
    online = !online;
    notifyListeners();
  }

  Future<void> trace(
    String action,
    String description, {
    String? hydrantId,
  }) async {
    final event = TraceEvent(
      id: const Uuid().v4(),
      action: action,
      description: description,
      createdAt: DateTime.now(),
      userId: user.id,
      brigadeName: user.brigadeName,
      deviceId: user.deviceId,
      hydrantId: hydrantId,
    );
    await traceBox.put(event.id, jsonEncode(event.toJson()));
  }

  Future<void> synchronize() async {
    if (!online || syncing || syncBox.isEmpty) return;
    syncing = true;
    syncProgress = 0;
    notifyListeners();
    await trace('sync_execute', 'Ejecución de sincronización simulada');
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 130));
      syncProgress = i / 10;
      notifyListeners();
    }
    await syncBox.clear();
    syncing = false;
    notifyListeners();
  }

  Hydrant hydrant(String id) => hydrants.firstWhere((item) => item.id == id);
}
