import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../builder/actions.dart';
import '../config/app_config.dart';
import '../core/i18n.dart';
import '../models/models.dart';
import '../providers/config_provider.dart';
import 'common.dart';

/// Things shown once when the app opens: the "update available" message and
/// the popup announcement from WordPress → AppForge → Marketing.
class StartupPrompts {
  StartupPrompts._();

  static const _popupIdKey = 'appforge_popup_id';
  static const _popupTimeKey = 'appforge_popup_time';
  static bool _ran = false;

  static Future<void> run(BuildContext context) async {
    if (_ran) return;
    _ran = true;
    final settings = context.read<ConfigProvider>().settings;
    final update = settings.appUpdate;
    final status = update.status(AppConfig.version);
    if (status != 'none') {
      await _showUpdate(context, update, force: status == 'required');
      if (status == 'required') return;
    }
    if (!context.mounted) return;
    await _maybePopup(context, settings.popup);
  }

  static Future<void> _showUpdate(BuildContext context, AppUpdateConfig u, {required bool force}) {
    final url = u.storeUrl.isNotEmpty ? u.storeUrl : AppConfig.playStoreUrl;
    return showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          icon: const Icon(Icons.system_update, size: 40),
          title: Text(force ? tr('Update required') : tr('Update available')),
          content: Text(u.message.isNotEmpty ? u.message : tr('A new version of the app is available.')),
          actions: [
            if (!force) TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Later'))),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              child: Text(tr('Update now')),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _maybePopup(BuildContext context, PopupConfig popup) async {
    if (!popup.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final show = popup.shouldShow(
      lastId: prefs.getString(_popupIdKey) ?? '',
      lastShownMs: prefs.getInt(_popupTimeKey) ?? 0,
      nowMs: now,
    );
    if (!show) return;
    await Future.delayed(Duration(seconds: popup.delay));
    if (!context.mounted) return;
    await prefs.setString(_popupIdKey, popup.id);
    await prefs.setInt(_popupTimeKey, now);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => PopupDialog(
        popup: popup,
        onAction: () {
          Navigator.pop(ctx);
          AppActions.open(context, popup.action);
        },
      ),
    );
  }
}

class PopupDialog extends StatelessWidget {
  final PopupConfig popup;
  final VoidCallback onAction;

  const PopupDialog({super.key, required this.popup, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAction = popup.buttonLabel.isNotEmpty && popup.action.type != 'none';
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (popup.image.isNotEmpty)
                  GestureDetector(
                    onTap: hasAction ? onAction : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: NetImage(popup.image, fit: BoxFit.cover),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (popup.title.isNotEmpty)
                        Text(popup.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      if (popup.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(popup.text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                      ],
                      if (hasAction) ...[
                        const SizedBox(height: 18),
                        ElevatedButton(onPressed: onAction, child: Text(popup.buttonLabel)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, color: Colors.white, size: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
