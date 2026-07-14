import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/app_state.dart';

Future<AppState> bootstrap() async {
  await initializeDateFormatting('es');
  await Hive.initFlutter();
  final traceBox = await Hive.openBox<String>('trace_events');
  final syncBox = await Hive.openBox<String>('sync_queue');
  final preferences = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final state = AppState(
    preferences: preferences,
    traceBox: traceBox,
    syncBox: syncBox,
    packageInfo: packageInfo,
  );
  await state.initialize();
  return state;
}
