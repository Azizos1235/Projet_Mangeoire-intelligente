import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'canaux.dart';

Future<void> requestNotificationPermissionAfterLogin(
  BuildContext context,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    if (await CanauxNatifs.notificationsAutorisees()) return;
    final alreadyExplained = await CanauxNatifs.permissionDejaExpliquee();
    if (alreadyExplained || !context.mounted) return;

    await CanauxNatifs.marquerPermissionExpliquee();
    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.notificationsPermissionTitle),
        content: const Text(AppStrings.notificationsPermissionDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.notificationsLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.notificationsEnable),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final granted = await CanauxNatifs.demanderPermissionNotif();
    if (!granted && context.mounted) _showPermissionHint(context);
  } on PlatformException catch (error) {
    FlutterError.reportError(FlutterErrorDetails(exception: error));
    if (context.mounted) _showPermissionHint(context);
  } on MissingPluginException catch (error) {
    FlutterError.reportError(FlutterErrorDetails(exception: error));
    if (context.mounted) _showPermissionHint(context);
  }
}

void _showPermissionHint(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(AppStrings.notificationsPermissionHint),
      action: SnackBarAction(
        label: AppStrings.notificationsOpenSettings,
        onPressed: CanauxNatifs.ouvrirParametresNotifications,
      ),
    ),
  );
}

class NativeNotificationSettings extends StatefulWidget {
  const NativeNotificationSettings({super.key});

  @override
  State<NativeNotificationSettings> createState() =>
      _NativeNotificationSettingsState();
}

class _NativeNotificationSettingsState
    extends State<NativeNotificationSettings> {
  bool _enabled = true;
  bool _authorized = true;
  bool _serviceActive = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final values = await Future.wait([
        CanauxNatifs.notificationsActivees(),
        CanauxNatifs.notificationsAutorisees(),
        CanauxNatifs.serviceActif(),
      ]);
      if (!mounted) return;
      setState(() {
        _enabled = values[0];
        _authorized = values[1];
        _serviceActive = values[2];
        _loading = false;
      });
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to load notification settings: $error');
      if (mounted) {
        setState(() {
          _error = AppStrings.notificationsError;
          _loading = false;
        });
      }
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) {
        setState(() {
          _error = AppStrings.notificationsError;
          _loading = false;
        });
      }
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _loading = true);
    try {
      await CanauxNatifs.definirNotifications(enabled);
      var authorized = await CanauxNatifs.notificationsAutorisees();
      if (enabled && !authorized) {
        authorized = await CanauxNatifs.demanderPermissionNotif();
      }
      final serviceActive =
          enabled && authorized ? await CanauxNatifs.serviceActif() : false;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _authorized = authorized;
        _serviceActive = serviceActive;
        _error = null;
        _loading = false;
      });
      if (enabled && !authorized) _showPermissionHint(context);
      if (enabled && authorized) await _showBatteryGuidanceIfNeeded();
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to update notification settings: $error');
      if (mounted) {
        setState(() {
          _error = AppStrings.notificationsError;
          _loading = false;
        });
      }
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) {
        setState(() {
          _error = AppStrings.notificationsError;
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkNow() async {
    try {
      await CanauxNatifs.verifierMaintenant();
      if (mounted) setState(() => _error = null);
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to start notification check: $error');
      if (mounted) setState(() => _error = AppStrings.notificationsError);
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) setState(() => _error = AppStrings.notificationsError);
    }
  }

  Future<void> _showBatteryGuidanceIfNeeded() async {
    final ignored = await CanauxNatifs.ignoreOptimisationBatterie();
    if (ignored ||
        !await CanauxNatifs.guiderOptimisationBatterie() ||
        !mounted) {
      return;
    }
    await _showBatteryGuidance();
  }

  Future<void> _showBatteryGuidance() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.notificationsBackgroundTitle),
        content: const Text(AppStrings.notificationsBackgroundDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.notificationsLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.notificationsBackgroundOpen),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await CanauxNatifs.demanderIgnoreOptimisationBatterie();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return AppCard(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text(AppStrings.notificationsTitle),
            subtitle: const Text(AppStrings.notificationsDescription),
            value: _enabled,
            onChanged: _loading ? null : _setEnabled,
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline, color: AppTheme.warn),
              title: Text(_error!),
            ),
          if (!_authorized)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: AppTheme.warn),
              title: Text(AppStrings.notificationsPermissionHint),
              trailing: TextButton(
                onPressed: CanauxNatifs.ouvrirParametresNotifications,
                child: Text(AppStrings.notificationsOpenSettings),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _serviceActive ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              color: _serviceActive ? AppTheme.primary : AppTheme.textGrey,
            ),
            title: Text(
              _serviceActive
                  ? AppStrings.notificationsServiceActive
                  : AppStrings.notificationsServiceInactive,
            ),
            trailing: TextButton(
              onPressed: _loading ? null : _showBatteryGuidance,
              child: const Text(AppStrings.notificationsBackgroundOpen),
            ),
          ),
          if (_enabled)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _loading ? null : _checkNow,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(AppStrings.notificationsCheckNow),
              ),
            ),
        ],
      ),
    );
  }
}
