import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado completo que usa el admin (coordenadas + métricas)
class InegiRouteResult {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final double distanceKm;
  final double durationMin;
  final int tollsCount;

  InegiRouteResult({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.distanceKm,
    required this.durationMin,
    required this.tollsCount,
  });
}

class InegiRoutingService {
  // OJO: tu token de INEGI
  static const String _token = 'FTlDp1Hk-jXyh-GYzx-hHtO-iIYm8IQrL1mF';

  // Endpoints base (ajusta si tus URLs reales son distintas)
  static const String _geocodeBaseUrl =
      'https://www.inegi.org.mx/app/api/geocoding';
  static const String _routeBaseUrl = 'https://www.inegi.org.mx/app/api/ruteo';

  /// Geocodifica una dirección a (lat, lng)
  Future<(double, double)> _geocodeAddress(String address) async {
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse(
      '$_geocodeBaseUrl?type=geocoding&buscar=$encoded&_token=$_token',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Geocoding API: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final features = data['features'] as List?;
    if (features == null || features.isEmpty) {
      throw Exception('No se encontraron coordenadas para esa dirección');
    }

    final geometry = features[0]['geometry'];
    final coords = geometry['coordinates'] as List;

    final double lng = (coords[0] as num).toDouble();
    final double lat = (coords[1] as num).toDouble();

    return (lat, lng);
  }

  /// Consulta de ruteo INEGI, regresa (km, minutos, casetas)
  Future<(double, double, int)> _getRouteMetrics({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final url = Uri.parse(
      '$_routeBaseUrl?type=route'
      '&starty=$originLat&startx=$originLng'
      '&endy=$destLat&endx=$destLng'
      '&_token=$_token',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Routing API: ${response.body}');
    }

    final data = jsonDecode(response.body);

    // Ajusta esta ruta según el JSON real de INEGI
    final summary = data['features'][0]['properties']['summary'];

    final double distanceKm =
        ((summary['distance'] as num?) ?? 0).toDouble() / 1000.0;
    final double durationMin =
        ((summary['duration'] as num?) ?? 0).toDouble() / 60.0;
    final int tollsCount = (summary['tolls'] as num?)?.toInt() ?? 0;

    return (distanceKm, durationMin, tollsCount);
  }

  /// MÉTODO QUE ESTÁ ESPERANDO TU AdminHomePage
  /// Calcula ruta SOLO a partir de las direcciones.
  Future<InegiRouteResult> calculateRouteByAddresses({
    required String originAddress,
    required String destAddress,
  }) async {
    // 1) Geocodificar origen y destino
    final (originLat, originLng) = await _geocodeAddress(originAddress);
    final (destLat, destLng) = await _geocodeAddress(destAddress);

    // 2) Consultar ruteo
    final (distanceKm, durationMin, tollsCount) = await _getRouteMetrics(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    // 3) Empaquetar todo en un solo objeto
    return InegiRouteResult(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      distanceKm: distanceKm,
      durationMin: durationMin,
      tollsCount: tollsCount,
    );
  }
}
