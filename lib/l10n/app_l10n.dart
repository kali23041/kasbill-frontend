import 'package:flutter/material.dart';

import 'strings_en.dart';
import 'strings_gu.dart';
import 'strings_hi.dart';
import 'strings_mr.dart';

/// Lightweight localization for Ratnex.
///
/// A hand-rolled map lookup rather than gen-l10n so new strings can be added
/// without a codegen step, and so a missing translation transparently falls
/// back to English instead of throwing.
class L10n {
  L10n(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('gu'),
  ];

  static const languageNames = <String, String>{
    'en': 'English',
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'gu': 'ગુજરાતી',
  };

  static const languageEnglishNames = <String, String>{
    'en': 'English',
    'hi': 'Hindi',
    'mr': 'Marathi',
    'gu': 'Gujarati',
  };

  static const _tables = <String, Map<String, String>>{
    'en': stringsEn,
    'hi': stringsHi,
    'mr': stringsMr,
    'gu': stringsGu,
  };

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ?? L10n(const Locale('en'));
  }

  /// Resolves [key], falling back to English and then to the key itself.
  String t(String key) {
    final table = _tables[locale.languageCode];
    return table?[key] ?? stringsEn[key] ?? key;
  }

  /// Resolves [key] and substitutes `{name}` placeholders.
  String f(String key, Map<String, Object?> args) {
    var out = t(key);
    args.forEach((k, v) {
      out = out.replaceAll('{$k}', '${v ?? ''}');
    });
    return out;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      L10n._tables.containsKey(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

/// `context.tr('bills')` reads better at call sites than `L10n.of(context).t`.
extension L10nX on BuildContext {
  String tr(String key) => L10n.of(this).t(key);

  String trf(String key, Map<String, Object?> args) => L10n.of(this).f(key, args);
}
