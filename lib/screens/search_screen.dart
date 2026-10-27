import 'package:flutter/material.dart';
import '../data/arabic_search.dart';
import '../data/quran_repository.dart';
import 'home_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  List<int> _res = [];
  List<Surah> _sur = [];
  List<String> _tokens = [];

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _run(String q) {
    setState(() {
      _tokens = searchTokens(q);
      _res = QuranSearch.search(q);
      _sur = QuranSearch.surahMatches(q);
    });
  }

  List<TextSpan> _highlight(String text, Color bg) {
    final words = text.split(' ');
    final spans = <TextSpan>[];
    for (var i = 0; i < words.length; i++) {
      final n = normalizeAr(words[i]);
      final hit = _tokens.any((t) => n.contains(t));
      spans.add(TextSpan(
        text: i < words.length - 1 ? '${words[i]} ' : words[i],
        style: hit ? TextStyle(backgroundColor: bg, fontWeight: FontWeight.bold) : null,
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = _tokens.isEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _ctl,
          onChanged: _run,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث في القرآن: كلمة، عبارة، أو اسم سورة',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ctl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctl.clear();
                      _run('');
                    }),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      Expanded(
        child: empty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('اكتب كلمة أو أكثر للبحث في القرآن الكريم\nيعمل البحث دون اعتبار للتشكيل',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ),
              )
            : (_res.isEmpty && _sur.isEmpty)
                ? const Center(child: Text('لا توجد نتائج'))
                : ListView.builder(
                    itemCount: 1 + _sur.length + _res.length,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        final more = _res.length >= 200 ? '+' : '';
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text('${arabicNum(_res.length)}$more آية',
                              style: const TextStyle(color: Colors.grey)),
                        );
                      }
                      if (i <= _sur.length) {
                        final s = _sur[i - 1];
                        return ListTile(
                          leading: CircleAvatar(radius: 18, child: Text(arabicNum(s.n), style: const TextStyle(fontSize: 12))),
                          title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 22)),
                          subtitle: Text('${arabicNum(s.ayahs.length)} آية'),
                          onTap: () => openPage(ctx, QuranRepository.ayahPage[s.ayahs.first.g]!),
                        );
                      }
                      final g = _res[i - 1 - _sur.length];
                      final (s, a) = QuranRepository.byGlobal(g);
                      final page = QuranRepository.ayahPage[g]!;
                      return ListTile(
                        title: RichText(
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 21, height: 2, color: cs.onSurface),
                            children: _highlight(a.text, cs.primary.withOpacity(.25)),
                          ),
                        ),
                        subtitle: Text('${s.name} · آية ${arabicNum(a.i)} · صفحة ${arabicNum(page)}'),
                        onTap: () => openPage(ctx, page, focusG: g),
                      );
                    },
                  ),
      ),
    ]);
  }
}
