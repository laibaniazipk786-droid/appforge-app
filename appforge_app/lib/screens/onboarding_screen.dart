import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Welcome slides designed in WordPress → AppForge → Onboarding.
class OnboardingScreen extends StatefulWidget {
  static const prefsKey = 'appforge_onboarding_seen_version';

  final OnboardingConfig config;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.config, required this.onDone});

  /// True when onboarding is enabled and this version hasn't been seen yet.
  static Future<bool> shouldShow(OnboardingConfig c) async {
    if (!c.enabled || c.slides.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(prefsKey) ?? 0) < c.version;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(OnboardingScreen.prefsKey, widget.config.version);
    widget.onDone();
  }

  void _next(int count) {
    if (_index >= count - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final slides = c.slides;
    final theme = Theme.of(context);
    final bg = hexColor(c.bgColor, theme.scaffoldBackgroundColor);
    final full = c.fullscreen;
    final fg = full ? Colors.white : hexColor(c.textColor, theme.colorScheme.onSurface);
    final isLast = _index == slides.length - 1;

    final dots = Row(
      children: List.generate(
        slides.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: i == _index ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _index ? (full ? Colors.white : theme.colorScheme.primary) : fg.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final s = slides[i];
              if (full) {
                return Stack(fit: StackFit.expand, children: [
                  NetImage(s.image),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 130,
                    child: _texts(s, fg, TextAlign.left),
                  ),
                ]);
              }
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
                  child: Column(children: [
                    Expanded(
                      child: Center(
                        child: s.image.isEmpty ? const SizedBox.shrink() : NetImage(s.image, fit: BoxFit.contain, radius: BorderRadius.circular(28)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _texts(s, fg, TextAlign.center),
                  ]),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(c.skipLabel),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(children: [
                  Expanded(child: dots),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(120, 50), padding: const EdgeInsets.symmetric(horizontal: 26)),
                    onPressed: () => _next(slides.length),
                    child: Text(isLast ? c.doneLabel : c.nextLabel),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _texts(OnboardingSlide s, Color fg, TextAlign align) {
    return Column(
      crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.title, textAlign: align, style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 10),
        Text(s.text, textAlign: align, style: TextStyle(color: fg.withOpacity(0.8), fontSize: 15, height: 1.5)),
      ],
    );
  }
}
