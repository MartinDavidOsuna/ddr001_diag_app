import 'package:geolocator/geolocator.dart';

class LocationCaptureException implements Exception {
  const LocationCaptureException(
    this.message, {
    this.permanentlyDenied = false,
  });
  final String message;
  final bool permanentlyDenied;
  @override
  String toString() => message;
}

class LocationService {
  Future<Position> capture() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationCaptureException('Activa el servicio de ubicación.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationCaptureException(
        'El permiso de ubicación está denegado permanentemente.',
        permanentlyDenied: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationCaptureException('Permiso de ubicación denegado.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
}
