import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import '../widgets/logo_mark.dart';
import 'azkar_screen.dart';
import 'bookmarks_screen.dart';
import 'khatma_tab.dart';
import 'reader_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Opens the Mushaf in normal (Surah / Search / Bookmarks) mode on the ROOT navigator,
/// so the reader is a full-screen route independent of every tab's own history.
void openPage(BuildContext c, int page, {int? focusG}) => Navigator.of(c, rootNavigator: true)
    .push(MaterialPageRoute(builder: (_) => ReaderScreen(page: page, focusG: focusG)));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  // One Navigator per tab: each tab keeps its own back-stack and scroll position,
  // so nothing a tab does can leak into another one (Khatma <-> Surah in particular).
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  late final List<Widget> _tabs = [
    _tabNav(0, const _SurahList()),
    _tabNav(1, const SearchScreen()),
    _tabNav(2, const BookmarksScreen()),
    _tabNav(3, const KhatmaTab()),
    _tabNav(4, const SettingsScreen()),
  ];

  Widget _tabNav(int i, Widget root) => Navigator(
        key: _navKeys[i],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _navKeys[tab].currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          } else if (tab != 0) {
            setState(() => tab = 0);
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: SafeArea(child: IndexedStack(index: tab, children: _tabs)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) {
              if (i == tab) _navKeys[i].currentState?.popUntil((r) => r.isFirst);
              setState(() => tab = i);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'السور'),
              NavigationDestination(icon: Icon(Icons.search), label: 'البحث'),
              NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'المحفوظات'),
              NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'الختمة'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList();

  Widget _juzHeader(int j) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
        child: Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('الجزء ${arabicNum(j)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      );

  Widget _surahTile(BuildContext context, Surah s) {
    final page = QuranRepository.ayahPage[s.ayahs.first.g]!;
    return ListTile(
      leading: CircleAvatar(radius: 18, child: Text(arabicNum(s.n), style: const TextStyle(fontSize: 12))),
      title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 22)),
      subtitle: Text('${s.type == 'Meccan' ? 'مكية' : 'مدنية'} · ${arabicNum(s.ayahs.length)} آية · صفحة ${arabicNum(page)}'),
      onTap: () => openPage(context, page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final dg = 1 + (day * 37) % QuranRepository.total;
    final (ds, da) = QuranRepository.byGlobal(dg);

    // Group surahs by the juz in which they begin.
    final byJuz = <int, List<Surah>>{};
    for (final s in QuranRepository.surahs) {
      final page = QuranRepository.ayahPage[s.ayahs.first.g]!;
      byJuz.putIfAbsent(QuranRepository.pages[page - 1].juz, () => []).add(s);
    }
    final juzs = byJuz.keys.toList()..sort();

    return ListenableBuilder(
      listenable: appState,
      builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openPage(context, QuranRepository.ayahPage[dg]!, focusG: dg),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('آية اليوم · ${ds.name} ${arabicNum(da.i)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(da.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 26, height: 2)),
                const SizedBox(height: 8),
                Text(QuranRepository.tafsir[dg - 1], maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Amiri', fontSize: 15)),
              ]),
            ),
          ),
        ),
        if (appState.lastPage > 0)
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('تابع القراءة'),
            subtitle: Text('صفحة ${arabicNum(appState.lastPage)}'),
            onTap: () => openPage(context, appState.lastPage),
          ),
        ListTile(
          leading: const Icon(Icons.wb_twilight),
          title: const Text('الأذكار'),
          subtitle: const Text('الصباح · المساء · النوم · بعد الصلاة'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarScreen())),
        ),
        for (final j in juzs) ...[
          _juzHeader(j),
          for (final s in byJuz[j]!) _surahTile(context, s),
        ],
      ]),
    );
  }
}
