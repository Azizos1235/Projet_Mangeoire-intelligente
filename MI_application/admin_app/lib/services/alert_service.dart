import '../models/alert.dart';
import 'api_client.dart';

class AlertService {
  AlertService._();

  static final AlertService instance = AlertService._();

  Future<List<Alert>> listAlerts({String? status, int limit = 50}) async {
    final queryParameters = <String, String>{'limit': '$limit'};
    if (status != null) queryParameters['status'] = status;
    final path = Uri(path: '/alerts', queryParameters: queryParameters);
    final response =
        await ApiClient.instance.get<List<dynamic>>(path.toString());
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid alert list response.');
      }
      return Alert.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<void> createAlert({
    required String message,
    required String severity,
    String? cowId,
    String? action,
  }) async {
    await ApiClient.instance.post<Object?>(
      '/alerts',
      body: {
        'message': message,
        'severity': severity,
        if (cowId != null) 'cow_id': cowId,
        if (action != null) 'action': action,
      },
    );
  }
}
