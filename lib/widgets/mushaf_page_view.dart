import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import 'logo_mark.dart'; // defines kGold

const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

// ───────────────────────── Mushaf typography ─────────────────────────
// Amiri-Bold is a *real* bold master (declared as weight 700 in pubspec.yaml) and
// covers every Quranic mark, so diacritics stay crisp. Faux-bolding AmiriQuran
// would smear the tashkeel.
const String kMushafFont = 'Amiri';
const FontWeight kMushafWeight = FontWeight.w700;

/// Line box = fontSize * this. Amiri's own ascent+descent is ~1.76em, which is what made
/// the 15 lines overflow; we fix the box and centre the glyphs inside it instead.
const double _kLineBox = 1.3;

/// Largest glyph size allowed inside one line slot (fraction of the slot height).
const double _kMaxFsOfLine = .66;
const double _kMaxFs = 48.0;

/// Printed Madani mushaf = 15 lines. Pages with a surah header / basmala may have more rows.
const int _kBaseLines = 15;

TextStyle _quranStyle(double fs, Color color) => TextStyle(
      fontFamily: kMushafFont,
      fontWeight: kMushafWeight,
      fontSize: fs,
      height: _kLineBox,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
    );

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
    final key = '${page.p}_${w.round()}_${lineH.round()}_${kMushafWeight.value}';
    return _cache.putIfAbsent(key, () {
      final nat = <double>[];
      var maxNat = 1.0;
      for (final r in page.rows) {
        if (r.kind != 0) { nat.add(0); continue; }
        final tp = TextPainter(
          text: TextSpan(
            text: r.words.map((e) => e.t).join(' '),
            style: const TextStyle(fontFamily: kMushafFont, fontWeight: kMushafWeight, fontSize: 100),
          ),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
        )..layout();
        nat.add(tp.width);
        maxNat = math.max(maxNat, tp.width);
      }
      // 0.985 keeps a hair of slack so the longest line never wraps or clips on the edge.
      final byWidth = 100 * (w * .985) / maxNat;
      final byHeight = lineH * _kMaxFsOfLine;
      return _Fit(math.min(math.min(byWidth, byHeight), _kMaxFs), nat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surah = QuranRepository.surahs[page.surah - 1];
    final meta = TextStyle(fontFamily: 'Amiri', fontSize: 15, color: cs.onSurface.withOpacity(.6));
    final mq = MediaQuery.of(context);

    // The mushaf is a fixed layout: the system "font size" setting must not change it.
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      // SafeArea keeps the last line + page number clear of the gesture / navigation bar.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(children: [
            SizedBox(
              height: 26,
              child: Row(children: [
                Text('${arabicNum(surah.n)}  ${surah.name}', style: meta),
                const Spacer(),
                Text('الجزء ${arabicNum(page.juz)}', style: meta),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (ctx, c) {
                // Every row (text, header, basmala, blank) gets one equal slot.
                // Using rows.length (not a hard-coded 15) is what stops the bottom line being cut off.
                final slots = math.max(_kBaseLines, page.rows.length);
                final lineH = c.maxHeight / slots;
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
            SizedBox(height: 24, child: Center(child: Text(arabicNum(page.p), style: meta.copyWith(fontSize: 16)))),
          ]),
        ),
      ),
    );
  }

  Widget _row(BuildContext ctx, MRow r, _Fit fit, int idx, double w, double lineH) {
    final cs = Theme.of(ctx).colorScheme;
    final fs = fit.fs;
    switch (r.kind) {
      case 1: // surah header
        return Container(
          margin: EdgeInsets.symmetric(vertical: lineH * .06),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kGold.withOpacity(.12),
            border: Border.all(color: kGold, width: 1.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(QuranRepository.surahs[r.surah - 1].name,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w700,
                fontSize: math.min(fs * 1.05, lineH * .42),
                height: 1.2,
                color: cs.onSurface,
              )),
        );
      case 2: // basmala
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_basmala, style: _quranStyle(fs, cs.onSurface)),
          ),
        );
      case 3: // blank line
        return const SizedBox.shrink();
    }
    final centered = fit.natural100[idx] * fs / 100 < w * .78;
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: [
        for (final wd in r.words)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => onTapAyah(wd.g),
            child: Container(
              alignment: Alignment.center,
              height: lineH,
              padding: centered ? EdgeInsets.symmetric(horizontal: fs * .14) : null,
              color: wd.g == playingG ? cs.primary.withOpacity(.2) : null,
              child: Text(
                wd.t,
                softWrap: false,
                style: _quranStyle(wd.end ? fs * .9 : fs, wd.end ? _endColor(cs, wd.g) : cs.onSurface),
              ),
            ),
          ),
      ],
    );
  }

  Color _endColor(ColorScheme cs, int g) {
    return appState.bookmarkColorOf(g) ?? kGold;
  }
}
