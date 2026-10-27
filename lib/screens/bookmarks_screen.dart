import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/arabic_search.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import 'home_screen.dart';

/// "المحفوظات": الفواصل (coloured bookmarks), المميزة بنجمة, الملاحظات.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  static String _meta(int g) {
    final (s, a) = QuranRepository.byGlobal(g);
    return '${s.name} · آية ${arabicNum(a.i)} · صفحة ${arabicNum(QuranRepository.ayahPage[g]!)}';
  }

  static Widget _empty(String t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ),
      );

  static Widget _verse(int g, {int lines = 1}) {
    final (_, a) = QuranRepository.byGlobal(g);
    return Text(a.text,
        maxLines: lines, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 17));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'الفواصل'), Tab(text: 'المميزة'), Tab(text: 'الملاحظات')]),
          Expanded(
            child: ListenableBuilder(
              listenable: appState,
              builder: (ctx, _) => TabBarView(children: [_bookmarks(ctx), _stars(ctx), _notes(ctx)]),
            ),
          ),
        ]),
      );

  Widget _bookmarks(BuildContext ctx) {
    final list = appState.bookmarkList.reversed.toList();
    if (list.isEmpty) {
      return _empty('لا توجد فواصل بعد\nاضغط على أي آية ثم "فاصل" واختر اللون');
    }
    return ListView(children: [
      for (final b in list)
        ListTile(
          leading: Icon(Icons.bookmark, color: tagColors[b.color], size: 32),
          title: Text(b.name),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_meta(b.g)}${b.date.isEmpty ? '' : ' · ${toArabicDigits(b.date)}'}'),
            _verse(b.g),
          ]),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => appState.removeBookmark(b.g)),
          onTap: () => openPage(ctx, QuranRepository.ayahPage[b.g]!, focusG: b.g),
        ),
    ]);
  }

  Widget _stars(BuildContext ctx) {
    final list = appState.stars.reversed.toList();
    if (list.isEmpty) {
      return _empty('لا توجد آيات مميزة بعد\nاضغط على أي آية ثم "نجمة"');
    }
    return ListView(children: [
      for (final g in list)
        ListTile(
          leading: const Icon(Icons.star, color: Color(0xFFFFB300)),
          title: _verse(g, lines: 2),
          subtitle: Text(_meta(g)),
          trailing: IconButton(icon: const Icon(Icons.star_border), onPressed: () => appState.toggleStar(g)),
          onTap: () => openPage(ctx, QuranRepository.ayahPage[g]!, focusG: g),
        ),
    ]);
  }

  Widget _notes(BuildContext ctx) {
    final entries = appState.notes.entries.toList().reversed.toList();
    if (entries.isEmpty) {
      return _empty('لا توجد ملاحظات بعد\nاضغط على أي آية ثم "ملاحظة"');
    }
    return ListView(children: [
      for (final e in entries)
        Builder(builder: (_) {
          final g = int.parse(e.key);
          return ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_meta(g)), _verse(g)]),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => appState.setNote(g, '')),
            onTap: () => openPage(ctx, QuranRepository.ayahPage[g]!, focusG: g),
          );
        }),
    ]);
  }
}
