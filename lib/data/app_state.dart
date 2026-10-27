import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tagColors = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFFB8C00), Color(0xFF8E24AA)];

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool dark = false, readVertical = false;
  String reciter = 'ar.alafasy';
  int lastPage = 0, streak = 0, khatmahDays = 30, todayCount = 0;
  String lastDay = '', readPages = '0' * 604;
  List<String> bookmarks = []; // "g|colorIndex|name"
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
    final rp = _p.getString('rp');
    if (rp != null && rp.length == 604) readPages = rp;
    if (lastDay == _today()) {
      _todaySet.addAll((_p.getStringList('tp') ?? []).map(int.parse));
    }
    todayCount = _todaySet.length;
  }

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

  int? bookmarkIndex(int g) {
    final i = bookmarks.indexWhere((b) => b.startsWith('$g|'));
    return i < 0 ? null : i;
  }

  void addBookmark(int g, int color, String name) {
    bookmarks.removeWhere((b) => b.startsWith('$g|'));
    bookmarks.add('$g|$color|${name.replaceAll('|', ' ')}');
    _p.setStringList('bm', bookmarks);
    notifyListeners();
  }

  void removeBookmark(int g) {
    bookmarks.removeWhere((b) => b.startsWith('$g|'));
    _p.setStringList('bm', bookmarks);
    notifyListeners();
  }
}
