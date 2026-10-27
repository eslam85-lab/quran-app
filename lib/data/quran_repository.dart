import 'dart:convert';
import 'package:flutter/services.dart';

class Ayah {
  final int g, i, page;
  final String text;
  Ayah(this.g, this.i, this.page, this.text);
}

class Surah {
  final int n;
  final String name, en, type;
  final List<Ayah> ayahs;
  Surah(this.n, this.name, this.en, this.type, this.ayahs);
}

class MWord {
  final String t;
  final int g;
  final bool end;
  const MWord(this.t, this.g, this.end);
}

/// kind: 0 = text line, 1 = surah header, 2 = basmala, 3 = blank line
class MRow {
  final int kind, surah;
  final List<MWord> words;
  const MRow(this.kind, this.words, this.surah);
}

class MPage {
  final int p, juz, surah;
  final List<MRow> rows;
  const MPage(this.p, this.juz, this.surah, this.rows);
  int get firstG => rows.firstWhere((r) => r.kind == 0).words.first.g;
}

class QuranRepository {
  static late List<Surah> surahs;
  static late List<String> tafsir;
  static late List<MPage> pages;
  static final Map<int, int> ayahPage = {};
  static const total = 6236;
  static const pageCount = 604;

  static Future<void> load() async {
    final q = jsonDecode(await rootBundle.loadString('assets/quran/quran.json'));
    surahs = [
      for (final s in q['surahs'])
        Surah(s['n'], s['name'], s['en'], s['type'], [
          for (final a in s['ayahs']) Ayah(a['g'], a['i'], a['p'], a['t'])
        ])
    ];
    tafsir = List<String>.from(jsonDecode(await rootBundle.loadString('assets/quran/tafsir.json')));
    final m = jsonDecode(await rootBundle.loadString('assets/quran/mushaf.json')) as List;
    pages = [
      for (final p in m)
        MPage(p['p'], p['j'], p['s'], [
          for (final r in p['l'] as List) _parseRow(r as List),
        ])
    ];
    ayahPage.clear();
    for (final p in pages) {
      for (final r in p.rows) {
        for (final w in r.words) { ayahPage.putIfAbsent(w.g, () => p.p); }
      }
    }
    // Runtime integrity guard: refuse to run with incomplete data
    final count = surahs.fold<int>(0, (s, e) => s + e.ayahs.length);
    if (surahs.length != 114 || count != total || tafsir.length != total ||
        pages.length != pageCount || ayahPage.length != total) {
      throw StateError('Quran data incomplete: ${surahs.length} surahs, $count verses, '
          '${pages.length} pages, ${ayahPage.length} verses in mushaf');
    }
  }

  static MRow _parseRow(List r) {
    final kind = r[0] as int;
    if (kind == 0) return MRow(0, [for (final w in r[1] as List) MWord(w[0] as String, w[1] as int, w[2] == 1)], 0);
    if (kind == 1) return MRow(1, const [], r[1] as int);
    return MRow(kind, const [], 0);
  }

  static (Surah, Ayah) byGlobal(int g) {
    for (final s in surahs) {
      if (g <= s.ayahs.last.g) return (s, s.ayahs[g - s.ayahs.first.g]);
    }
    throw RangeError('bad ayah $g');
  }
}

String arabicNum(int n) => n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
