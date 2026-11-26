import '../models/alert.dart';
import 'api_client.dart';

class AlertService {
  AlertService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  static final AlertService instance = AlertService();
  final ApiClient _apiClient;

  Future<List<Alert>> listAlerts({String? status, int limit = 50}) async {
    final queryParameters = <String, String>{'limit': '$limit'};
    if (status != null) queryParameters['status'] = status;
    final path = Uri(path: '/alerts', queryParameters: queryParameters);
    final response = await _apiClient.get<List<dynamic>>(path.toString());
    return response
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid alert list response.');
          }
          return Alert.fromJson(Map<String, dynamic>.from(item));
        })
        .where((alert) => alert.source == 'system')
        .toList(growable: false);
  }

  Future<void> markRead(String alertId) async {
    await _apiClient.markAlertRead(alertId);
  }

  Future<void> deleteAlert(String alertId) async {
    await _apiClient.delete(
      '/alerts/${Uri.encodeComponent(alertId)}',
    );
  }
}
