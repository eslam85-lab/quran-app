import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bookmark ("فاصل") colours: red, yellow, green, blue.
const tagColors = [Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF1E88E5)];
const tagNames = ['أحمر', 'أصفر', 'أخضر', 'أزرق'];

class Bookmark {
  final int g, color;
  final String name, date; // date: yyyy-m-d
  const Bookmark(this.g, this.color, this.name, this.date);
}

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool dark = false, readVertical = false;
  String reciter = 'ar.alafasy';
  int lastPage = 0, streak = 0, khatmahDays = 30, todayCount = 0;
  String lastDay = '', readPages = '0' * 604;
  List<String> bookmarks = []; // "g|colorIndex|name|date"
  List<int> stars = []; // global verse numbers, oldest first
  Map<String, String> notes = {}; // "g" -> note text
  final Set<int> _todaySet = {};

  int get readCount => readPages.split('').where((c) => c == '1').length;

  String _today() { final n = DateTime.now(); return '${n.year}-${n.month}-${n.day}'; }

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    dark = _p.getBool('dark') ?? false;
    readVertical = _p.getBool('vertical') ?? false;
    reciter = _p.getString('reciter') ?? 'ar.alafasy';
    lastPage = _p.getInt('lastPage') ?? 0;
    streak = _p.getInt('streak') ?? 0;
    lastDay = _p.getString('lastDay') ?? '';
    khatmahDays = _p.getInt('kdays') ?? 30;
    bookmarks = _p.getStringList('bm') ?? [];
    stars = (_p.getStringList('stars') ?? []).map(int.tryParse).whereType<int>().toList();
    try {
      final raw = _p.getString('notes');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        notes = {for (final e in m.entries) e.key: '${e.value}'};
      }
    } catch (_) {
      notes = {};
    }
    final rp = _p.getString('rp');
    if (rp != null && rp.length == 604) readPages = rp;
    if (lastDay == _today()) {
      _todaySet.addAll((_p.getStringList('tp') ?? []).map(int.parse));
    }
    todayCount = _todaySet.length;
  }

  void refresh() => notifyListeners();
  void setDark(bool v) { dark = v; _p.setBool('dark', v); notifyListeners(); }
  void setVertical(bool v) { readVertical = v; _p.setBool('vertical', v); notifyListeners(); }
  void setReciter(String v) { reciter = v; _p.setString('reciter', v); notifyListeners(); }
  void setKhatmahDays(int v) { khatmahDays = v; _p.setInt('kdays', v); notifyListeners(); }
  void setLastPage(int p) { lastPage = p; _p.setInt('lastPage', p); }

  void resetKhatmah() {
    readPages = '0' * 604;
    _p.setString('rp', readPages);
    notifyListeners();
  }

  /// Called after the user stays on a page for a few seconds.
  void markPageRead(int page) {
    final i = page - 1;
    if (readPages[i] != '1') {
      readPages = readPages.substring(0, i) + '1' + readPages.substring(i + 1);
      _p.setString('rp', readPages);
    }
    final today = _today();
    if (today != lastDay) {
      final y = DateTime.now().subtract(const Duration(days: 1));
      streak = lastDay == '${y.year}-${y.month}-${y.day}' ? streak + 1 : 1;
      lastDay = today;
      _todaySet.clear();
      _p.setInt('streak', streak);
      _p.setString('lastDay', today);
    }
    _todaySet.add(page);
    todayCount = _todaySet.length;
    _p.setStringList('tp', _todaySet.map((e) => '$e').toList());
    notifyListeners();
  }

  // ---------- bookmarks ----------
  static Bookmark? _parse(String b) {
    final p = b.split('|');
    if (p.length < 3) return null;
    final g = int.tryParse(p[0]);
    final c = int.tryParse(p[1]);
    if (g == null || c == null) return null;
    final ci = c < 0 ? 0 : (c >= tagColors.length ? tagColors.length - 1 : c);
    return Bookmark(g, ci, p[2], p.length > 3 ? p[3] : '');
  }

  List<Bookmark> get bookmarkList {
    final out = <Bookmark>[];
    for (final b in bookmarks) {
      final x = _parse(b);
      if (x != null) out.add(x);
    }
    return out;
  }

  bool isBookmarked(int g) => bookmarks.any((b) => b.startsWith('$g|'));

  Color? bookmarkColorOf(int g) {
    for (final b in bookmarks) {
      if (b.startsWith('$g|')) {
        final x = _parse(b);
        if (x != null) return tagColors[x.color];
      }
    }
    return null;
  }

  void addBookmark(int g, int color, String name) {
    final n = DateTime.now();
    bookmarks.removeWhere((b) => b.startsWith('$g|'));
    bookmarks.add('$g|$color|${name.replaceAll('|', ' ')}|${n.year}-${n.month}-${n.day}');
    _p.setStringList('bm', bookmarks);
    notifyListeners();
  }

  void removeBookmark(int g) {
    bookmarks.removeWhere((b) => b.startsWith('$g|'));
    _p.setStringList('bm', bookmarks);
    notifyListeners();
  }

  // ---------- starred verses ----------
  bool isStarred(int g) => stars.contains(g);

  void toggleStar(int g) {
    if (!stars.remove(g)) stars.add(g);
    _p.setStringList('stars', stars.map((e) => '$e').toList());
    notifyListeners();
  }

  // ---------- notes ----------
  String? noteOf(int g) => notes['$g'];

  void setNote(int g, String text) {
    final t = text.trim();
    if (t.isEmpty) {
      notes.remove('$g');
    } else {
      notes['$g'] = t;
    }
    _p.setString('notes', jsonEncode(notes));
    notifyListeners();
  }
}
