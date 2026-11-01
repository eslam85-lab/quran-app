import '../main.dart';
import 'khatma_state.dart';

/// Decides where the reader writes its reading progress. This is what keeps the
/// Surah tab and the Khatma tab fully independent of each other.
abstract class ReaderSession {
  const ReaderSession();
  String get titlePrefix; // shown in the app bar so the user always knows which mode is open
  void visit(int page); // user is looking at [page] (remember position)
  bool get supportsMarking => false; // true => the reader shows the manual "تم القراءة" button
  bool isRead(int page) => false;
  void markRead(int page) {} // ONLY called when the user taps "تم القراءة" (never automatic)
  void unmarkRead(int page) {}
  void exit(); // reader closed
}

/// Normal browsing from the Surah / Search / Bookmarks tabs.
class SurahSession extends ReaderSession {
  const SurahSession();
  @override
  String get titlePrefix => '';
  @override
  void visit(int page) => appState.setLastPage(page);
  @override
  void exit() => appState.refresh();
}

/// Opened from the Khatma tab: own position, own read-pages, own streak.
class KhatmaSession extends ReaderSession {
  const KhatmaSession();
  @override
  String get titlePrefix => 'الختمة · ';
  @override
  void visit(int page) => khatmaState.visit(page);
  @override
  bool get supportsMarking => true;
  @override
  bool isRead(int page) => khatmaState.isRead(page);
  @override
  void markRead(int page) => khatmaState.markPageRead(page);
  @override
  void unmarkRead(int page) => khatmaState.unmarkPage(page);
  @override
  void exit() => khatmaState.refresh();
}
