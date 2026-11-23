import 'package:appforge_app/core/api.dart';
import 'package:appforge_app/core/format.dart';
import 'package:appforge_app/models/models.dart';
import 'package:appforge_app/widgets/common.dart';
import 'package:appforge_app/widgets/startup_prompts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    Money.currency = const Currency(code: 'PKR', symbol: 'Rs', position: 'left_space', decimals: 0);
    Api.online.value = true;
  });

  testWidgets('Free shipping bar shows the amount left', (tester) async {
    await tester.pumpWidget(wrap(FreeShippingBar(info: FreeShippingInfo(min: 150000, remaining: 54600, qualified: false))));
    await tester.pumpAndSettle();
    expect(find.text('Add Rs 54,600 more for FREE shipping'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.636, 0.001));
  });

  testWidgets('Free shipping bar when qualified', (tester) async {
    await tester.pumpWidget(wrap(FreeShippingBar(info: FreeShippingInfo(min: 150000, remaining: 0, qualified: true))));
    await tester.pumpAndSettle();
    expect(find.text('You get FREE shipping!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('Offline error shows a friendly message + retry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(wrap(MessageView.error(ApiException('x', code: 'offline'), title: 'Could not load orders', onRetry: () => retried++)));
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('Server error shows title + message', (tester) async {
    await tester.pumpWidget(wrap(MessageView.error(ApiException('Order not found.', status: 404), title: 'Could not load orders')));
    expect(find.text('Could not load orders'), findsOneWidget);
    expect(find.text('Order not found.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Offline banner follows the connection state', (tester) async {
    await tester.pumpWidget(wrap(const Column(children: [OfflineBanner()])));
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    Api.online.value = false;
    await tester.pumpAndSettle();
    expect(find.text('You are offline — showing saved content'), findsOneWidget);
    Api.online.value = true;
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets('Popup dialog shows content and runs its action', (tester) async {
    var tapped = 0;
    final popup = PopupConfig({
      'enabled': true,
      'title': 'Eid Sale',
      'text': '10% off with WELCOME10',
      'button_label': 'Shop now',
      'action': {'type': 'route', 'value': 'products'},
    });
    await tester.pumpWidget(wrap(PopupDialog(popup: popup, onAction: () => tapped++)));
    expect(find.text('Eid Sale'), findsOneWidget);
    expect(find.text('10% off with WELCOME10'), findsOneWidget);
    await tester.tap(find.text('Shop now'));
    expect(tapped, 1);
  });

  testWidgets('Popup without an action has no button', (tester) async {
    final popup = PopupConfig({'enabled': true, 'title': 'Hello', 'button_label': 'Go', 'action': {'type': 'none', 'value': ''}});
    await tester.pumpWidget(wrap(PopupDialog(popup: popup, onAction: () {})));
    expect(find.text('Go'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('Price view: sale price + struck regular price', (tester) async {
    await tester.pumpWidget(wrap(const PriceView(price: 45000, regularPrice: 50000, onSale: true)));
    expect(find.text('Rs 45,000'), findsOneWidget);
    expect(find.text('Rs 50,000'), findsOneWidget);
  });
}
