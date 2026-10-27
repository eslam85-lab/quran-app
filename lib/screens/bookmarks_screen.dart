import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import 'home_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (_, __) {
          if (appState.bookmarks.isEmpty) {
            return const Center(child: Text('لا توجد علامات بعد\nاضغط على أي آية ثم أيقونة العلامة', textAlign: TextAlign.center));
          }
          return ListView(children: [
            for (final b in appState.bookmarks.reversed)
              Builder(builder: (_) {
                final p = b.split('|');
                final g = int.parse(p[0]);
                final (_, a) = QuranRepository.byGlobal(g);
                return ListTile(
                  leading: Icon(Icons.bookmark, color: tagColors[int.parse(p[1])]),
                  title: Text(p[2]),
                  subtitle: Text(a.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'AmiriQuran')),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => appState.removeBookmark(g)),
                  onTap: () => openPage(context, QuranRepository.ayahPage[g]!),
                );
              }),
          ]);
        },
      );
}
