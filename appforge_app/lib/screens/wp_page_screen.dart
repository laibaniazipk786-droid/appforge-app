import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../builder/actions.dart';
import '../core/i18n.dart';
import '../models/models.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

/// Shows a WordPress page (About, Privacy policy, Terms …) natively.
class WpPageScreen extends StatefulWidget {
  final int pageId;
  final String title;
  const WpPageScreen({super.key, required this.pageId, this.title = ''});

  @override
  State<WpPageScreen> createState() => _WpPageScreenState();
}

class _WpPageScreenState extends State<WpPageScreen> {
  late Future<WpPage> _future = Repo.page(widget.pageId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WpPage>(
      future: _future,
      builder: (context, snap) {
        final page = snap.data;
        return Scaffold(
          appBar: AppBar(title: Text(page?.title ?? widget.title)),
          body: page == null
              ? (snap.hasError
                  ? MessageView(
                      icon: Icons.error_outline,
                      title: tr('Could not load this page'),
                      subtitle: '${snap.error}',
                      actionLabel: tr('Retry'),
                      onAction: () => setState(() => _future = Repo.page(widget.pageId)),
                    )
                  : const LoadingView())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (page.image.isNotEmpty) ...[
                      NetImage(page.image, height: 200, width: double.infinity, radius: BorderRadius.circular(14)),
                      const SizedBox(height: 16),
                    ],
                    HtmlWidget(
                      page.content,
                      textStyle: const TextStyle(height: 1.6, fontSize: 15),
                      onTapUrl: (url) => AppActions.launchExternal('external', url),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
