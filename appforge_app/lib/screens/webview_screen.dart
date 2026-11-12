import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/i18n.dart';

/// In-app browser for "Open URL" actions.
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isTab;

  const WebViewScreen({super.key, required this.url, this.title = '', this.isTab = false});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onProgress: (p) => setState(() => _progress = p)))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: () => _controller.reload())],
        bottom: _progress < 100
            ? PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(value: _progress / 100, minHeight: 2))
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// Opens the WooCommerce "order-pay" page so any website gateway (Stripe, PayPal, JazzCash, …)
/// works. Pops `true` when WooCommerce reaches the order-received (thank you) page.
class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  const PaymentWebViewScreen({super.key, required this.url});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

  bool _isSuccess(String url) => url.contains('/order-received/') || url.contains('order-received=');

  void _complete(bool success) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(success);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (_isSuccess(url)) _complete(true);
          setState(() => _loading = true);
        },
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          if (_isSuccess(req.url)) {
            _complete(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Cancel payment?')),
        content: Text(tr('Your order is saved. You can complete payment later from My orders.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Stay'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Leave'))),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) _complete(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Secure payment')),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () async {
              if (await _confirmLeave()) _complete(false);
            },
          ),
          bottom: _loading ? PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
