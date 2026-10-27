import 'quran_repository.dart';

/// Strips tashkeel / Quranic marks and unifies letter variants so that
/// "القرآن", "ٱلْقُرْءَانَ" and "القران" all compare equal.
String normalizeAr(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x640 || r == 0x670 || r == 0x200C || r == 0x200D) continue;
    if ((r >= 0x610 && r <= 0x61A) || (r >= 0x64B && r <= 0x65F)) continue;
    if ((r >= 0x6D6 && r <= 0x6ED) || (r >= 0x8D3 && r <= 0x8FF)) continue;
    switch (r) {
      case 0x621: // hamza on its own
        break;
      case 0x671: // alef wasla
      case 0x622: // alef madda
      case 0x623: // alef hamza above
      case 0x625: // alef hamza below
        b.writeCharCode(0x627);
        break;
      case 0x624: // waw hamza
        b.writeCharCode(0x648);
        break;
      case 0x626: // ya hamza
      case 0x649: // alef maqsura
      case 0x6CC: // farsi ya
        b.writeCharCode(0x64A);
        break;
      case 0x629: // ta marbuta
        b.writeCharCode(0x647);
        break;
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString().trim();
}

/// Western digits -> Arabic-Indic digits (leaves other characters untouched).
String toArabicDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final d = r >= 0x30 && r <= 0x39 ? r - 0x30 : -1;
    b.write(d >= 0 ? ar[d] : c);
  }
  return b.toString();
}

List<String> searchTokens(String q) =>
    normalizeAr(q).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

class QuranSearch {
  static List<String>? _idx; // normalized text of verse g at index g-1
  static List<String>? _names;

  static void _build() {
    _idx = [
      for (final s in QuranRepository.surahs)
        for (final a in s.ayahs) normalizeAr(a.text)
    ];
    _names = [for (final s in QuranRepository.surahs) normalizeAr(s.name)];
  }

  /// Verses (global numbers) containing ALL words of the query.
  static List<int> search(String q, {int limit = 200}) {
    final tokens = searchTokens(q);
    if (tokens.isEmpty) return [];
    if (_idx == null) _build();
    final out = <int>[];
    for (var i = 0; i < _idx!.length; i++) {
      final t = _idx![i];
      if (tokens.every((k) => t.contains(k))) {
        out.add(i + 1);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  static List<Surah> surahMatches(String q) {
    final nq = normalizeAr(q);
    if (nq.isEmpty) return [];
    if (_names == null) _build();
    return [
      for (var i = 0; i < _names!.length; i++)
        if (_names![i].contains(nq)) QuranRepository.surahs[i]
    ];
  }
}
