import 'package:flutter/material.dart';
import '../data/quran_repository.dart';

String _snippet(int g) {
  final (_, a) = QuranRepository.byGlobal(g);
  return a.text.split(' ').take(5).join(' ');
}

String _rubLabel(int r) {
  final hizb = (r - 1) ~/ 4 + 1;
  final q = (r - 1) % 4;
  const names = ['الحزب', 'ربع الحزب', 'نصف الحزب', 'ثلاثة أرباع الحزب'];
  return '${names[q]} ${arabicNum(hizb)}';
}

/// Bottom sheet with the Surah / Juz / Quarter index. [onJump] receives the target page.
void showIndexSheet(BuildContext context, void Function(int page) onJump) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      void go(int page) {
        Navigator.pop(sheetCtx);
        onJump(page);
      }

      return Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * .88,
          child: DefaultTabController(
            length: 3,
            child: Column(children: [
              const SizedBox(height: 8),
              const TabBar(tabs: [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'الأرباع')]),
              Expanded(child: TabBarView(children: [_surahs(go), _juz(go), _rubs(go)])),
            ]),
          ),
        ),
      );
    },
  );
}

Widget _surahs(void Function(int) go) => ListView(children: [
      for (final s in QuranRepository.surahs)
        ListTile(
          leading: CircleAvatar(radius: 18, child: Text(arabicNum(s.n), style: const TextStyle(fontSize: 12))),
          title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 20)),
          subtitle: Text('${s.type == 'Meccan' ? 'مكية' : 'مدنية'} · ${arabicNum(s.ayahs.length)} آية'),
          trailing: Text('ص ${arabicNum(QuranRepository.ayahPage[s.ayahs.first.g]!)}'),
          onTap: () => go(QuranRepository.ayahPage[s.ayahs.first.g]!),
        ),
    ]);

Widget _juz(void Function(int) go) {
  final first = <int, int>{};
  for (final p in QuranRepository.pages) {
    first.putIfAbsent(p.juz, () => p.p);
  }
  final js = first.keys.toList()..sort();
  return ListView(children: [
    for (final j in js)
      ListTile(
        leading: CircleAvatar(radius: 18, child: Text(arabicNum(j), style: const TextStyle(fontSize: 12))),
        title: Text('الجزء ${arabicNum(j)}'),
        subtitle: Text(_snippet(QuranRepository.pages[first[j]! - 1].firstG),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16)),
        trailing: Text('ص ${arabicNum(first[j]!)}'),
        onTap: () => go(first[j]!),
      ),
  ]);
}

Widget _rubs(void Function(int) go) {
  final rubs = QuranRepository.rubs;
  if (rubs.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('بيانات الأرباع غير متوفرة في هذه النسخة', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
  return ListView.builder(
    itemCount: rubs.length,
    itemBuilder: (_, i) {
      final r = rubs[i];
      return ListTile(
        leading: CircleAvatar(radius: 18, child: Text(arabicNum((r.n - 1) ~/ 8 + 1), style: const TextStyle(fontSize: 12))),
        title: Text(_rubLabel(r.n)),
        subtitle: Text(_snippet(r.g), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 16)),
        trailing: Text('ص ${arabicNum(r.page)}'),
        onTap: () => go(r.page),
      );
    },
  );
}
