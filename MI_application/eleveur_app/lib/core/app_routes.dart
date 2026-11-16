import 'package:flutter/material.dart';
import '../models/cow_profile.dart';
import '../screens/auth/biometric_authentication_screen.dart';
import '../screens/auth/eleveur_registration_screen.dart';
import '../screens/auth/qr_scanner_screen.dart';
import '../screens/auth/startup_screen.dart';
import '../screens/auth/subscription_expired_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/cows/cow_detail_screen.dart';
import '../screens/cows/add_cow_screen.dart';
import '../screens/feeding/feeding_screen.dart';
import '../screens/home/eleveur_home_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/scan/nfc_scan_screen.dart';
import '../services/nfc_service.dart';
import 'l10n.dart';
import 'theme.dart';

/// Central route names and builders for the application.
class AppRoutes {
  AppRoutes._();

  static const welcome = '/';
  static const startup = '/startup';
  static const home = '/home';
  static const qrScanner = '/auth/qr';
  static const registration = '/auth/registration';
  static const biometric = '/auth/biometric';
  static const subscriptionExpired = '/auth/subscription-expired';
  static const cowDetail = '/cows/detail';
  static const addCow = '/cows/add';
  static const feeding = '/feeding';
  static const notifications = '/notifications';
  static const nfcScanner = '/scan/nfc';

  static final Map<String, WidgetBuilder> staticRoutes = {
    welcome: (_) => const WelcomeScreen(),
    startup: (_) => const StartupScreen(),
    home: (_) => const EleveurHomeScreen(),
    qrScanner: (_) => const QrScannerScreen(),
    biometric: (_) => const BiometricAuthenticationScreen(),
    subscriptionExpired: (_) => const SubscriptionExpiredScreen(),
    notifications: (_) => const NotificationsScreen(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == nfcScanner) {
      final mode = settings.arguments;
      return MaterialPageRoute<NfcScanResult?>(
        settings: settings,
        builder: (_) => NfcScanScreen(
          mode: mode is NfcScanMode ? mode : NfcScanMode.view,
        ),
      );
    }

    final WidgetBuilder? builder;
    switch (settings.name) {
      case registration:
        final arguments = settings.arguments;
        if (arguments is Map<String, String> &&
            arguments['code']?.isNotEmpty == true &&
            arguments['admin_name']?.isNotEmpty == true) {
          builder = (_) => EleveurRegistrationScreen(
                invitationCode: arguments['code']!,
                adminName: arguments['admin_name']!,
              );
        } else {
          builder = null;
        }
      case cowDetail:
        final cow = settings.arguments;
        builder = cow is CowReference
            ? (_) => CowDetailScreen(cow: cow)
            : cow is String && cow.isNotEmpty
                ? (_) => CowDetailScreen(
                      cow: CowReference(internalId: cow, cowId: ''),
                    )
                : null;
      case addCow:
        final nfcUid = settings.arguments;
        builder = nfcUid == null
            ? (_) => const AddCowScreen()
            : nfcUid is String && nfcUid.isNotEmpty
                ? (_) => AddCowScreen(
                      nfcUid: nfcUid,
                      tagAlreadyChecked: true,
                    )
                : null;
      case feeding:
        final cow = settings.arguments;
        builder = cow is CowReference
            ? (_) => FeedingScreen(cow: cow)
            : cow is String && cow.isNotEmpty
                ? (_) => FeedingScreen(
                      cow: CowReference(internalId: cow, cowId: ''),
                    )
                : null;
      default:
        builder = null;
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder:
          builder ?? (_) => _UnknownRouteScreen(routeName: settings.name ?? ''),
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  final String routeName;

  const _UnknownRouteScreen({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${context.tr('route_unavailable')}: $routeName',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey),
          ),
        ),
      ),
    );
  }
}
