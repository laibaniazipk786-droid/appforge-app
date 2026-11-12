import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/i18n.dart';

import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/config_provider.dart';
import 'providers/prefs_provider.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = ConfigProvider();
  final auth = AuthProvider();
  final cart = CartProvider();
  final prefs = PrefsProvider();
  await Future.wait([auth.init(), cart.init(), prefs.init()]);
  // Config loads from cache first, then refreshes from WordPress.
  config.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: config),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: cart),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: AppForgeApp(),
    ),
  );
}

class AppForgeApp extends StatelessWidget {
  const AppForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final prefs = context.watch<PrefsProvider>();
    final langs = config.config?.languages;
    final lang = prefs.language(langs);

    // Load the UI strings for the chosen language and send it to the API for content.
    I18n.load(lang.code, langs?.strings[lang.code] ?? const {}, lang.rtl);
    Api.instance.lang = lang.code;

    // Material widgets only ship some languages; others fall back to English widgets
    // while our own strings and text direction still follow the chosen language.
    final materialLocale = GlobalMaterialLocalizations.delegate.isSupported(Locale(lang.code)) ? Locale(lang.code) : Locale('en');

    return MaterialApp(
      key: ValueKey('app-${lang.code}'),
      title: config.settings.appName,
      debugShowCheckedModeBanner: false,
      theme: config.theme,
      darkTheme: config.darkTheme,
      themeMode: prefs.themeMode(config.settings),
      locale: materialLocale,
      supportedLocales: {Locale('en'), materialLocale}.toList(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: lang.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? SizedBox.shrink(),
      ),
      home: RootGate(),
    );
  }
}

/// Splash while the first config loads → onboarding (if enabled & not seen) → main app.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool? _showOnboarding;

  Future<void> _checkOnboarding(ConfigProvider config) async {
    final show = await OnboardingScreen.shouldShow(config.settings.onboarding);
    if (mounted) setState(() => _showOnboarding = show);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    if (config.config != null) {
      if (_showOnboarding == null) {
        _checkOnboarding(config);
        return _splash(config);
      }
      if (_showOnboarding!) {
        return OnboardingScreen(
          config: config.settings.onboarding,
          onDone: () => setState(() => _showOnboarding = false),
        );
      }
      return MainShell();
    }
    return _loadingOrError(context, config);
  }

  Widget _splash(ConfigProvider config) {
    final s = config.settings;
    return Scaffold(
      body: Center(
        child: s.logo.isNotEmpty
            ? NetImage(s.logo, height: 64, fit: BoxFit.contain)
            : Text(s.appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _loadingOrError(BuildContext context, ConfigProvider config) {
    if (config.config == null) {
      if (config.loading) {
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(tr('Could not connect to the store'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(config.error ?? '', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      config.loading = true;
                      config.refresh();
                    },
                    child: Text(tr('Try again')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return MainShell();
  }
}
