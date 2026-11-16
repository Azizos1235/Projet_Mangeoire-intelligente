import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/nfc_service.dart';
import '../../services/session.dart';
import '../../core/theme.dart';
import '../cows/cows_screen.dart';
import 'home_tab.dart';
import '../notifications/notifications_screen.dart';

/// Main application shell with dashboard, livestock, and alerts tabs.
class EleveurHomeScreen extends StatefulWidget {
  const EleveurHomeScreen({super.key});

  @override
  State<EleveurHomeScreen> createState() => _EleveurHomeScreenState();
}

class _EleveurHomeScreenState extends State<EleveurHomeScreen> {
  int _tab = 0;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _userName = _currentUserName();
    Session.instance.currentUser.addListener(_onCurrentUserChanged);
    if (_userName == null) unawaited(_loadCurrentUser());
  }

  String? _currentUserName() {
    final name = Session.instance.currentUser.value?.displayName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  void _onCurrentUserChanged() {
    final name = _currentUserName();
    if (!mounted || name == _userName) return;
    setState(() => _userName = name);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.instance.me();
      if (!mounted || !identical(Session.instance.currentUser.value, user)) {
        return;
      }
      final name = user.displayName?.trim();
      if (name != _userName) setState(() => _userName = name);
    } catch (error) {
      if (kDebugMode) debugPrint('[DBG] home user name unavailable: $error');
    }
  }

  @override
  void dispose() {
    Session.instance.currentUser.removeListener(_onCurrentUserChanged);
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == 3) {
      _scanCow();
      return;
    }
    setState(() => _tab = index);
  }

  Future<void> _scanCow() async {
    final scan = await Navigator.pushNamed<NfcScanResult?>(
      context,
      AppRoutes.nfcScanner,
      arguments: NfcScanMode.view,
    );
    if (!mounted || scan == null) return;

    try {
      final result = await NfcService.instance.lookupTag(
        scan.uid,
        mode: scan.mode,
      );
      if (!mounted) return;
      switch (result.status) {
        case NfcLookupStatus.found:
          await Navigator.pushNamed<void>(
            context,
            AppRoutes.cowDetail,
            arguments: result.cow!,
          );
        case NfcLookupStatus.notFound:
          await _offerAddForUnknownTag(result.uid);
        case NfcLookupStatus.registeredElsewhere:
          await _showNoCowFound();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error.messageKey))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('api_error_generic'))),
      );
    }
  }

  Future<void> _offerAddForUnknownTag(String uid) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_not_found')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('add_cow')),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      await Navigator.pushNamed<void>(
        context,
        AppRoutes.addCow,
        arguments: uid,
      );
    }
  }

  Future<void> _showNoCowFound() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_not_found')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('got_it')),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('logout')),
        content: Text(dialogContext.tr('logout_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('logout')),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(
            onGoTab: _selectTab,
            onAddCow: () =>
                Navigator.pushNamed<void>(context, AppRoutes.addCow),
            onLogout: _logout,
            name: _userName,
          ),
          CowsTab(onScanCow: _scanCow),
          NotificationsScreen(isActive: _tab == 2),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primarySoft,
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon:
                const Icon(Icons.home_rounded, color: AppTheme.primary),
            label: context.tr('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon:
                const Icon(Icons.list_alt_rounded, color: AppTheme.primary),
            label: context.tr('nav_cows'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_none_rounded),
            selectedIcon: const Icon(Icons.notifications_rounded,
                color: AppTheme.primary),
            label: context.tr('nav_alerts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.nfc_rounded),
            selectedIcon:
                const Icon(Icons.nfc_rounded, color: AppTheme.primary),
            label: context.tr('nav_nfc'),
          ),
        ],
      ),
    );
  }
}
