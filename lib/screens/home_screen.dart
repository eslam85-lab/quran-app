import 'package:flutter/material.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import 'bookmarks_screen.dart';
import 'khatmah_screen.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

void openPage(BuildContext c, int page) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => ReaderScreen(page: page)));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const _SurahList(), const BookmarksScreen(), const KhatmahScreen(), const SettingsScreen()];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: pages[tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'القرآن'),
            NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'العلامات'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'الختمة'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList();
  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final dg = 1 + (day * 37) % QuranRepository.total;
    final (ds, da) = QuranRepository.byGlobal(dg);
    return ListenableBuilder(
      listenable: appState,
      builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openPage(context, QuranRepository.ayahPage[dg]!),
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
        const Divider(),
        for (final s in QuranRepository.surahs)
          ListTile(
            leading: CircleAvatar(radius: 18, child: Text(arabicNum(s.n), style: const TextStyle(fontSize: 12))),
            title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 22)),
            subtitle: Text('${s.type == 'Meccan' ? 'مكية' : 'مدنية'} · ${arabicNum(s.ayahs.length)} آية · صفحة ${arabicNum(QuranRepository.ayahPage[s.ayahs.first.g]!)}'),
            onTap: () => openPage(context, QuranRepository.ayahPage[s.ayahs.first.g]!),
          ),
      ]),
    );
  }
}
