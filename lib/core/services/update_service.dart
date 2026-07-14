import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../domain/enums/app_enums.dart';
import '../../domain/models/app_models.dart';

class UpdateService {
  Future<UpdateInfo> check(String installedVersion) async {
    try {
      final source = await rootBundle.loadString(
        'assets/config/update_manifest.json',
      );
      final json = jsonDecode(source) as Map<String, dynamic>;
      final current = Version.parse(installedVersion);
      final latest = Version.parse(json['latestVersion'] as String);
      final minimum = Version.parse(json['minimumSupportedVersion'] as String);
      final status = current < minimum
          ? UpdateStatus.required
          : current < latest
          ? UpdateStatus.optional
          : UpdateStatus.current;
      return UpdateInfo(
        latestVersion: '$latest',
        minimumSupportedVersion: '$minimum',
        buildNumber: json['buildNumber'] as int,
        title: json['title'] as String,
        message: json['message'] as String,
        status: status,
      );
    } catch (_) {
      return const UpdateInfo(
        latestVersion: '',
        minimumSupportedVersion: '',
        buildNumber: 0,
        title: 'Comprobación no disponible',
        message: 'Puedes continuar usando los datos locales.',
        status: UpdateStatus.unavailable,
      );
    }
  }
}
