import 'package:flutter/material.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import '../widgets/logo_mark.dart';
import 'bookmarks_screen.dart';
import 'khatmah_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

void openPage(BuildContext c, int page, {int? focusG}) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => ReaderScreen(page: page, focusG: focusG)));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const _SurahList(),
      const SearchScreen(),
      const BookmarksScreen(),
      const KhatmahScreen(),
      const SettingsScreen(),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: pages[tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'السور'),
            NavigationDestination(icon: Icon(Icons.search), label: 'البحث'),
            NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'المحفوظات'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'الختمة'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
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
        for (final j in juzs) ...[
          _juzHeader(j),
          for (final s in byJuz[j]!) _surahTile(context, s),
        ],
      ]),
    );
  }
}
