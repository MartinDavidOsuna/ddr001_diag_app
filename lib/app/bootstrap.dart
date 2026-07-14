import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/app_state.dart';
import '../data/local/visual_inspection_repository.dart';
import '../data/local/functional_repositories.dart';

Future<AppState> bootstrap() async {
  await initializeDateFormatting('es');
  await Hive.initFlutter();
  final traceBox = await Hive.openBox<String>('trace_events');
  final syncBox = await Hive.openBox<String>('sync_queue');
  final mediaBox = await Hive.openBox<String>('media_sync_queue');
  final syncedTraceBox = await Hive.openBox<String>('synced_trace_ids');
  final inspectionBox = await Hive.openBox<String>('visual_inspections_v1');
  final inspectionIndexBox = await Hive.openBox<String>(
    'active_inspection_index_v1',
  );
  await Hive.openBox<String>('damage_records_v1');
  await Hive.openBox<String>('inspection_photos_v1');
  await Hive.openBox<String>('hydrant_configurations_v1');
  await Hive.openBox<String>('local_hydrants_v1');
  await Hive.openBox<String>('media_work_queue_v1');
  final functionalEligibilityBox = await Hive.openBox<String>(
    'functional_eligibility_v1',
  );
  final functionalInspectionBox = await Hive.openBox<String>(
    'functional_inspections_v1',
  );
  final functionalInspectionIndexBox = await Hive.openBox<String>(
    'active_functional_inspection_index_v1',
  );
  await Hive.openBox<String>('measurement_series_v1');
  await Hive.openBox<String>('instrument_records_v1');
  await Hive.openBox<String>('functional_valve_tests_v1');
  await Hive.openBox<String>('alarm_tests_v1');
  await Hive.openBox<String>('functional_results_v1');
  await Hive.openBox<String>('functional_test_records_v1');
  final preferences = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final state = AppState(
    preferences: preferences,
    traceBox: traceBox,
    syncBox: syncBox,
    mediaBox: mediaBox,
    syncedTraceBox: syncedTraceBox,
    packageInfo: packageInfo,
    visualInspectionRepository: VisualInspectionRepository(
      documents: inspectionBox,
      index: inspectionIndexBox,
    ),
    functionalEligibilityRepository: FunctionalEligibilityRepository(
      functionalEligibilityBox,
    ),
    functionalInspectionRepository: FunctionalInspectionRepository(
      documents: functionalInspectionBox,
      index: functionalInspectionIndexBox,
    ),
  );
  await state.initialize();
  return state;
}
