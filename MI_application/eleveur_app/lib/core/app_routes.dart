import 'package:flutter/material.dart';
import '../models/farm_task.dart';
import '../models/cow_profile.dart';
import '../screens/auth/biometric_authentication_screen.dart';
import '../screens/auth/eleveur_registration_screen.dart';
import '../screens/auth/name_entry_screen.dart';
import '../screens/auth/qr_scanner_screen.dart';
import '../screens/auth/startup_screen.dart';
import '../screens/auth/subscription_expired_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/cows/cow_detail_screen.dart';
import '../screens/cows/add_cow_screen.dart';
import '../screens/cows/edit_profile_screen.dart';
import '../screens/feeding/feeding_screen.dart';
import '../screens/home/eleveur_home_screen.dart';
import '../screens/scan/nfc_scan_screen.dart';
import '../services/nfc_service.dart';
import 'l10n.dart';
import 'theme.dart';

/// Central route names and builders for the application.
class AppRoutes {
  AppRoutes._();

  static bool _loggedIgnoredNativeRoute = false;

  static const welcome = '/';
  static const startup = '/startup';
  static const home = '/home';
  static const qrScanner = '/auth/qr';
  static const registration = '/auth/registration';
  static const nameEntry = '/auth/name';
  static const biometric = '/auth/biometric';
  static const subscriptionExpired = '/auth/subscription-expired';
  static const cowDetail = '/cows/detail';
  static const addCow = '/cows/add';
  static const editCowProfile = '/cows/edit';
  static const feeding = '/feeding';
  static const nfcScanner = '/scan/nfc';

  static final Map<String, WidgetBuilder> staticRoutes = {
    welcome: (_) => const WelcomeScreen(),
    startup: (_) => const StartupScreen(),
    home: (_) => const EleveurHomeScreen(),
    qrScanner: (_) => const QrScannerScreen(),
    biometric: (_) => const BiometricAuthenticationScreen(),
    subscriptionExpired: (_) => const SubscriptionExpiredScreen(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final normalizedName = settings.name?.toLowerCase();
    if (normalizedName?.startsWith('native://') == true ||
        normalizedName?.contains('notification') == true) {
      if (!_loggedIgnoredNativeRoute) {
        debugPrint('[MI_NOTIF] Ignored native route: ${settings.name}');
        _loggedIgnoredNativeRoute = true;
      }
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: startup),
        builder: staticRoutes[startup]!,
      );
    }

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
      case nameEntry:
        final arguments = settings.arguments;
        if (arguments == null) {
          builder = (_) => const NameEntryScreen();
        } else if (arguments is Map<String, String> &&
            arguments['token']?.isNotEmpty == true) {
          builder = (_) => NameEntryScreen(qrToken: arguments['token']);
        } else {
          builder = null;
        }
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
      case editCowProfile:
        final arguments = settings.arguments;
        builder = arguments is EditProfileRouteArguments
            ? (_) => EditProfileScreen(
                  profile: arguments.profile,
                  task: arguments.task,
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

    final routeBuilder =
        builder ?? (_) => _UnknownRouteScreen(routeName: settings.name ?? '');
    if (settings.name == editCowProfile) {
      return MaterialPageRoute<bool>(
        settings: settings,
        builder: routeBuilder,
      );
    }
    return MaterialPageRoute<void>(settings: settings, builder: routeBuilder);
  }
}

class EditProfileRouteArguments {
  const EditProfileRouteArguments({
    required this.profile,
    required this.task,
  });

  final CowProfile profile;
  final FarmTask task;
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
