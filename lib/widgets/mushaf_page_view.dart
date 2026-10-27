import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import 'logo_mark.dart';

const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

class _Fit {
  final double fs;
  final List<double> natural100; // natural width of each row at font size 100
  _Fit(this.fs, this.natural100);
}

/// One printed Madani mushaf page: header (surah / juz), up to 15 lines, footer (page number).
class MushafPageView extends StatelessWidget {
  final MPage page;
  final int? playingG;
  final void Function(int g) onTapAyah;
  const MushafPageView({super.key, required this.page, required this.playingG, required this.onTapAyah});

  static final Map<String, _Fit> _cache = {};

  _Fit _fit(double w, double lineH) {
    final key = '${page.p}_${w.round()}_${lineH.round()}';
    return _cache.putIfAbsent(key, () {
      final nat = <double>[];
      var maxNat = 1.0;
      for (final r in page.rows) {
        if (r.kind != 0) { nat.add(0); continue; }
        final tp = TextPainter(
          text: TextSpan(text: r.words.map((e) => e.t).join(' '), style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 100)),
          textDirection: TextDirection.rtl,
        )..layout();
        nat.add(tp.width);
        maxNat = math.max(maxNat, tp.width);
      }
      final fs = math.min(math.min(100 * w / maxNat, lineH * .55), 42.0);
      return _Fit(fs, nat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surah = QuranRepository.surahs[page.surah - 1];
    final meta = TextStyle(fontFamily: 'Amiri', fontSize: 15, color: cs.onSurface.withOpacity(.6));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(children: [
        Row(children: [
          Text('${arabicNum(surah.n)}  ${surah.name}', style: meta),
          const Spacer(),
          Text('الجزء ${arabicNum(page.juz)}', style: meta),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            final lineH = c.maxHeight / 15;
            final fit = _fit(c.maxWidth, lineH);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < page.rows.length; i++)
                  SizedBox(height: lineH, width: c.maxWidth, child: _row(ctx, page.rows[i], fit, i, c.maxWidth, lineH)),
              ],
            );
          }),
        ),
        Text(arabicNum(page.p), style: meta.copyWith(fontSize: 16)),
      ]),
    );
  }

  Widget _row(BuildContext ctx, MRow r, _Fit fit, int idx, double w, double lineH) {
    final cs = Theme.of(ctx).colorScheme;
    final fs = fit.fs;
    switch (r.kind) {
      case 1:
        return Container(
          margin: EdgeInsets.symmetric(vertical: lineH * .08),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kGold.withOpacity(.12),
            border: Border.all(color: kGold, width: 1.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(QuranRepository.surahs[r.surah - 1].name,
              style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: math.min(fs * 1.05, lineH * .40), height: 1.3, color: cs.onSurface)),
        );
      case 2:
        return Center(child: Text(_basmala, style: TextStyle(fontFamily: 'AmiriQuran', fontSize: fs, height: 1.6, color: cs.onSurface)));
      case 3:
        return const SizedBox.shrink();
    }
    final centered = fit.natural100[idx] * fs / 100 < w * .78;
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: [
        for (final wd in r.words)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => onTapAyah(wd.g),
            child: Container(
              padding: centered ? EdgeInsets.symmetric(horizontal: fs * .14) : null,
              color: wd.g == playingG ? cs.primary.withOpacity(.2) : null,
              child: Text(wd.t,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: wd.end ? fs * .9 : fs,
                    height: 1.6,
                    color: wd.end ? _endColor(cs, wd.g) : cs.onSurface,
                  )),
            ),
          ),
      ],
    );
  }

  Color _endColor(ColorScheme cs, int g) {
    return appState.bookmarkColorOf(g) ?? kGold;
  }
}
