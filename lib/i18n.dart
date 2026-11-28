import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_catalog.dart';
import 'locale_url_stub.dart'
    if (dart.library.js_interop) 'locale_url_web.dart';

class PassyLocale {
  static const preferenceKey = 'passy.language';
  static final current = ValueNotifier<Locale>(const Locale('vi'));
  static const languages = {'vi': 'Tiếng Việt', 'en': 'English', 'ko': '한국어'};
  static Future<void> initialize() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(preferenceKey);
    } catch (_) {}
    final requested = Uri.base.queryParameters['lang'];
    final code = languages.containsKey(requested)
        ? requested
        : languages.containsKey(saved)
        ? saved
        : 'vi';
    current.value = Locale(code!);
    if (requested == code) await change(code);
  }

  static Future<void> change(String code) async {
    if (!languages.containsKey(code)) return;
    current.value = Locale(code);
    updateLocaleUrl(code);
    try {
      await (await SharedPreferences.getInstance()).setString(
        preferenceKey,
        code,
      );
    } catch (_) {}
  }
}

class _Phrase {
  final String key;
  final RegExp pattern;
  final List<int> indices;
  _Phrase(this.key, this.pattern, this.indices);
}

final _phrases =
    passyTranslations.keys.where((key) => key.contains(RegExp(r'\{\d+\}'))).map(
      (key) {
        final placeholders = RegExp(r'\{(\d+)\}').allMatches(key);
        final out = StringBuffer('^');
        final indices = <int>[];
        var last = 0;
        for (final match in placeholders) {
          out.write(RegExp.escape(key.substring(last, match.start)));
          out.write(r'([\s\S]*?)');
          indices.add(int.parse(match[1]!));
          last = match.end;
        }
        out.write(RegExp.escape(key.substring(last)));
        out.write(r'$');
        return _Phrase(key, RegExp(out.toString()), indices);
      },
    ).toList()..sort((a, b) => b.key.length.compareTo(a.key.length));

String tr(String text) {
  final code = PassyLocale.current.value.languageCode;
  if (code == 'vi') return text;
  final column = code == 'ko' ? 1 : 0, direct = passyTranslations[text];
  if (direct != null) return direct[column];
  for (final phrase in _phrases) {
    final match = phrase.pattern.firstMatch(text);
    if (match == null) continue;
    var value = passyTranslations[phrase.key]![column];
    final arguments = <int, String>{};
    for (var i = 0; i < phrase.indices.length; i++) {
      arguments[phrase.indices[i]] = match.group(i + 1)!;
    }
    value = value.replaceAllMapped(
      RegExp(r'\{(\d+)\}'),
      (m) => arguments[int.parse(m[1]!)] ?? m[0]!,
    );
    if (code == 'en') {
      value = value.replaceAllMapped(
        RegExp(r'\b1 (hours|minutes|days|items|reviews)\b'),
        (m) => '1 ${m[1]!.substring(0, m[1]!.length - 1)}',
      );
    }
    return value;
  }
  return text;
}

String localizedListingDescription(String text) {
  final match = RegExp(r'^Tình trạng: ([^\n]+)\n\n([\s\S]*)$').firstMatch(text);
  const standard = {
    'Mới',
    'Đã qua sử dụng - có khuyết điểm',
    'Đã qua sử dụng - như mới',
    'Đã qua sử dụng - tốt',
  };
  if (match == null || !standard.contains(match[1])) return text;
  return tr('Tình trạng: ${tr(match[1]!)}\n\n${match[2]}');
}

/// Translates application-owned labels. User-supplied titles, names and messages
/// remain ordinary Text widgets; catalog patterns preserve interpolated values.
class PassyText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  const PassyText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionColor,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: PassyLocale.current,
    builder: (context, activeLocale, _) => Text(
      tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale ?? activeLocale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    ),
  );
}

class LanguagePicker extends StatelessWidget {
  final VoidCallback? onChanged;
  const LanguagePicker({super.key, this.onChanged});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: PassyLocale.current,
    builder: (context, locale, _) => PopupMenuButton<String>(
      tooltip: locale.languageCode == 'ko'
          ? '언어'
          : locale.languageCode == 'en'
          ? 'Language'
          : 'Ngôn ngữ',
      initialValue: locale.languageCode,
      onSelected: (code) async {
        await PassyLocale.change(code);
        onChanged?.call();
      },
      itemBuilder: (_) => PassyLocale.languages.entries
          .map(
            (e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  if (e.key == locale.languageCode)
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  Text(e.value),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18),
            const SizedBox(width: 4),
            Text(
              locale.languageCode.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
