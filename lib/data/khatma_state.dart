import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_repository.dart';

/// Everything about the daily Khatma / Wird lives here, completely separate from [AppState]
/// (reading position of the Surah tab, bookmarks, ...). Own keys, own listeners.
final khatmaState = KhatmaState();

class KhatmaState extends ChangeNotifier {
  late SharedPreferences _p;

  int days = 30; // target: finish the Quran in this many days
  int streak = 0;
  int lastPage = 0; // last page opened FROM THE KHATMA (not from the Surah tab)
  int todayCount = 0;
  String lastDay = '';
  String readPages = '0' * 604;
  int dayStart = 1; // first unread page when today began = start of today's wird
  String dayStartDate = '';
  final Set<int> _todaySet = {};

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    if (!_p.containsKey('kh_init')) {
      // one-time migration of the progress the old combined screen had stored
      final rp = _p.getString('rp');
      if (rp != null && rp.length == 604) _p.setString('kh_rp', rp);
      _p.setInt('kh_days', _p.getInt('kdays') ?? 30);
      _p.setInt('kh_streak', _p.getInt('streak') ?? 0);
      _p.setString('kh_lastDay', _p.getString('lastDay') ?? '');
      final tp = _p.getStringList('tp');
      if (tp != null) _p.setStringList('kh_tp', tp);
      _p.setBool('kh_init', true);
    }
    days = _p.getInt('kh_days') ?? 30;
    streak = _p.getInt('kh_streak') ?? 0;
    lastPage = _p.getInt('kh_lastPage') ?? 0;
    lastDay = _p.getString('kh_lastDay') ?? '';
    final rp = _p.getString('kh_rp');
    if (rp != null && rp.length == 604) readPages = rp;
    dayStart = _p.getInt('kh_dayStart') ?? 1;
    dayStartDate = _p.getString('kh_dayStartDate') ?? '';
    if (lastDay == _today()) {
      _todaySet.addAll((_p.getStringList('kh_tp') ?? []).map(int.tryParse).whereType<int>());
    }
    todayCount = _todaySet.length;
    _rollDay();
  }

  // ───────────── derived values ─────────────
  int get readCount => readPages.split('').where((c) => c == '1').length;
  double get progress => readCount / QuranRepository.pageCount;
  bool get completed => readCount >= QuranRepository.pageCount;
  int get perDay => (QuranRepository.pageCount / days).ceil();
  bool isRead(int page) => readPages[page - 1] == '1';

  int get firstUnread {
    final i = readPages.indexOf('0');
    return i < 0 ? QuranRepository.pageCount + 1 : i + 1;
  }

  /// Today's wird: pages [wirdFrom]..[wirdTo].
  int get wirdFrom => dayStart.clamp(1, QuranRepository.pageCount);
  int get wirdTo => (wirdFrom + perDay - 1).clamp(1, QuranRepository.pageCount);
  int get wirdPages => wirdTo - wirdFrom + 1;
  int get wirdDone {
    var n = 0;
    for (var p = wirdFrom; p <= wirdTo; p++) {
      if (isRead(p)) n++;
    }
    return n;
  }

  bool get wirdComplete => wirdDone >= wirdPages;

  /// Where "start / continue the wird" should open.
  int get wirdResumePage {
    for (var p = wirdFrom; p <= wirdTo; p++) {
      if (!isRead(p)) return p;
    }
    return wirdFrom;
  }

  /// Page that "continue the khatma" opens: last page opened from the khatma, else first unread.
  int get resumePage => lastPage > 0 ? lastPage : firstUnread.clamp(1, QuranRepository.pageCount);

  DateTime get expectedFinish {
    final remaining = QuranRepository.pageCount - readCount;
    final daysLeft = (remaining / perDay).ceil();
    return DateTime.now().add(Duration(days: daysLeft));
  }

  /// Pages read / total pages for each of the 30 juz.
  List<(int read, int total)> juzProgress() {
    final read = List<int>.filled(30, 0), total = List<int>.filled(30, 0);
    for (final pg in QuranRepository.pages) {
      final j = (pg.juz - 1).clamp(0, 29);
      total[j]++;
      if (isRead(pg.p)) read[j]++;
    }
    return [for (var i = 0; i < 30; i++) (read[i], total[i])];
  }

  // ───────────── actions ─────────────
  void refresh() => notifyListeners();

  void _rollDay() {
    final t = _today();
    if (dayStartDate != t) {
      dayStart = firstUnread.clamp(1, QuranRepository.pageCount);
      dayStartDate = t;
      _p.setInt('kh_dayStart', dayStart);
      _p.setString('kh_dayStartDate', t);
    }
  }

  void setDays(int v) {
    days = v;
    _p.setInt('kh_days', v);
    notifyListeners();
  }

  void visit(int page) {
    lastPage = page;
    _p.setInt('kh_lastPage', page);
  }

  void markPageRead(int page) {
    _rollDay();
    final i = page - 1;
    if (readPages[i] != '1') {
      readPages = readPages.substring(0, i) + '1' + readPages.substring(i + 1);
      _p.setString('kh_rp', readPages);
    }
    final today = _today();
    if (today != lastDay) {
      final y = DateTime.now().subtract(const Duration(days: 1));
      streak = lastDay == '${y.year}-${y.month}-${y.day}' ? streak + 1 : 1;
      lastDay = today;
      _todaySet.clear();
      _p.setInt('kh_streak', streak);
      _p.setString('kh_lastDay', today);
    }
    _todaySet.add(page);
    todayCount = _todaySet.length;
    _p.setStringList('kh_tp', _todaySet.map((e) => '$e').toList());
    notifyListeners();
  }

  /// Undo a "mark as read" (the user tapped it by mistake).
  void unmarkPage(int page) {
    final i = page - 1;
    if (readPages[i] != '0') {
      readPages = readPages.substring(0, i) + '0' + readPages.substring(i + 1);
      _p.setString('kh_rp', readPages);
    }
    if (_todaySet.remove(page)) {
      todayCount = _todaySet.length;
      _p.setStringList('kh_tp', _todaySet.map((e) => '$e').toList());
    }
    notifyListeners();
  }

  void resetKhatma() {
    readPages = '0' * 604;
    lastPage = 0;
    dayStart = 1;
    dayStartDate = _today();
    _todaySet.clear();
    todayCount = 0;
    _p.setString('kh_rp', readPages);
    _p.setInt('kh_lastPage', 0);
    _p.setInt('kh_dayStart', 1);
    _p.setString('kh_dayStartDate', dayStartDate);
    _p.setStringList('kh_tp', []);
    notifyListeners();
  }
}
