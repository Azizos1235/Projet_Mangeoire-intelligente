import '../models/alert.dart';
import 'api_client.dart';

/// Loads and updates alerts through the backend alert endpoints.
class AlertService {
  AlertService._();

  static final AlertService instance = AlertService._();
  final ApiClient _api = ApiClient.instance;

  Future<List<Alert>> getAlerts() async {
    final response = await _api.getAlerts();
    final records = response is List
        ? response
        : response is Map<String, dynamic> && response['alerts'] is List
            ? response['alerts'] as List
            : null;
    if (records == null) {
      throw const FormatException('Invalid alerts response from API.');
    }
    return records.map((record) {
      if (record is! Map<String, dynamic>) {
        throw const FormatException('Invalid alert in API response.');
      }
      return Alert.fromJson(record);
    }).toList(growable: false);
  }

  Future<void> markRead(String alertId) async {
    await _api.markAlertRead(alertId);
  }
}
