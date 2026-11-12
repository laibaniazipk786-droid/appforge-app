/// App UI translations. Keys are the English text; translations come from
/// WordPress → AppForge → Languages (sent inside /config).
class I18n {
  I18n._();

  static Map<String, String> _strings = const {};
  static String code = 'en';
  static bool rtl = false;

  static void load(String langCode, Map<String, String> strings, bool isRtl) {
    code = langCode;
    _strings = strings;
    rtl = isRtl;
  }

  static String lookup(String key) {
    final s = _strings[key];
    return (s == null || s.isEmpty) ? key : s;
  }
}

/// Translate [key]. Placeholders like {n} are replaced from [args].
String tr(String key, [Map<String, Object?>? args]) {
  var s = I18n.lookup(key);
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  }
  return s;
}
