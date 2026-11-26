import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
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
        title: Text(dialogContext.tr('notifications_permission_title')),
        content: Text(dialogContext.tr('notifications_permission_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('notifications_later')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('notifications_enable')),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final granted = await CanauxNatifs.demanderPermissionNotif();
    if (!granted && context.mounted) _showPermissionHint(context);
  } on PlatformException catch (error) {
    debugPrint('Unable to request notification permission: $error');
    if (context.mounted) _showPermissionHint(context);
  } on MissingPluginException catch (error) {
    debugPrint('Native notification channel is unavailable: $error');
    if (context.mounted) _showPermissionHint(context);
  }
}

void _showPermissionHint(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.tr('notifications_permission_hint')),
      action: SnackBarAction(
        label: context.tr('notifications_open_settings'),
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
          _error = context.tr('notifications_error');
          _loading = false;
        });
      }
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) {
        setState(() {
          _error = context.tr('notifications_error');
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
          _error = context.tr('notifications_error');
          _loading = false;
        });
      }
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) {
        setState(() {
          _error = context.tr('notifications_error');
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
      if (mounted) setState(() => _error = context.tr('notifications_error'));
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
      if (mounted) setState(() => _error = context.tr('notifications_error'));
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
        title: Text(dialogContext.tr('notifications_background_title')),
        content: Text(dialogContext.tr('notifications_background_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('notifications_background_open')),
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
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(context.tr('notifications_title')),
            subtitle: Text(context.tr('notifications_description')),
            value: _enabled,
            onChanged: _loading ? null : _setEnabled,
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              leading: const Icon(Icons.error_outline, color: AppTheme.error),
              title: Text(_error!),
            ),
          if (!_authorized)
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.error),
              title: Text(context.tr('notifications_permission_hint')),
              trailing: TextButton(
                onPressed: CanauxNatifs.ouvrirParametresNotifications,
                child: Text(context.tr('notifications_open_settings')),
              ),
            ),
          ListTile(
            leading: Icon(
              _serviceActive ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              color: _serviceActive ? AppTheme.primary : AppTheme.textGrey,
            ),
            title: Text(
              context.tr(
                _serviceActive
                    ? 'notifications_service_active'
                    : 'notifications_service_inactive',
              ),
            ),
            trailing: TextButton(
              onPressed: _loading ? null : _showBatteryGuidance,
              child: Text(context.tr('notifications_background_open')),
            ),
          ),
          if (_enabled)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _loading ? null : _checkNow,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.tr('notifications_check_now')),
              ),
            ),
        ],
      ),
    );
  }
}
