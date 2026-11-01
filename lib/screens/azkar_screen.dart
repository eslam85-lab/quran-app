import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/azkar_data.dart';
import '../data/quran_repository.dart' show arabicNum;
import '../widgets/logo_mark.dart' show kGold;

class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});
  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> {
  // remaining repetitions per category / zekr (kept while the screen is open)
  late final Map<AzkarCategory, List<int>> _left = {
    for (final c in AzkarCategory.values) c: [for (final z in azkarFor(c)) z.count],
  };

  // reading size, remembered between launches
  double _fs = 24;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble('az_fs');
      if (v != null && mounted) setState(() => _fs = v.clamp(18, 36));
    });
  }

  void _sizeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, set) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('حجم الخط', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', style: TextStyle(fontFamily: 'Amiri', fontSize: _fs, height: 1.9)),
              Slider(
                value: _fs,
                min: 18,
                max: 36,
                divisions: 9,
                onChanged: (v) {
                  set(() => _fs = v);
                  setState(() {});
                },
                onChangeEnd: (v) => SharedPreferences.getInstance().then((p) => p.setDouble('az_fs', v)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _tap(AzkarCategory c, int i) {
    if (_left[c]![i] <= 0) return;
    setState(() => _left[c]![i]--);
    _left[c]![i] == 0 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }

  void _reset(AzkarCategory c) =>
      setState(() => _left[c] = [for (final z in azkarFor(c)) z.count]);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: AzkarCategory.values.length,
        child: Builder(builder: (ctx) {
          final tc = DefaultTabController.of(ctx);
          return Scaffold(
            appBar: AppBar(
              title: const Text('الأذكار'),
              centerTitle: true,
              actions: [
                IconButton(icon: const Icon(Icons.text_fields), tooltip: 'حجم الخط', onPressed: _sizeSheet),
                AnimatedBuilder(
                  animation: tc,
                  builder: (_, __) => IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'إعادة العدّاد',
                    onPressed: () => _reset(AzkarCategory.values[tc.index]),
                  ),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final c in AzkarCategory.values) Tab(text: c.title)],
              ),
            ),
            body: TabBarView(
              children: [for (final c in AzkarCategory.values) _list(c)],
            ),
          );
        }),
      ),
    );
  }

  Widget _list(AzkarCategory c) {
    final items = azkarFor(c);
    final left = _left[c]!;
    final total = items.fold<int>(0, (s, z) => s + z.count);
    final done = total - left.fold<int>(0, (s, v) => s + v);
    final allDone = left.every((v) => v == 0);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 24 + MediaQuery.of(context).padding.bottom),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _progress(done / total, allDone);
        final idx = i - 1;
        return _card(c, idx, items[idx], left[idx]);
      },
    );
  }

  Widget _progress(double v, bool allDone) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: v, minHeight: 8, color: kGold),
          ),
          if (allDone)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('تقبّل الله منك', style: TextStyle(fontFamily: 'Amiri', fontSize: 20, fontWeight: FontWeight.w700)),
            ),
        ]),
      );

  Widget _card(AzkarCategory c, int i, Zekr z, int remaining) {
    final cs = Theme.of(context).colorScheme;
    final finished = remaining == 0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: finished ? .55 : 1,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: cs.surfaceContainerHighest.withOpacity(.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: finished ? kGold : cs.outlineVariant.withOpacity(.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _tap(c, i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                z.text,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling, // size is controlled by the in-app slider
                style: TextStyle(
                  fontFamily: 'Amiri', // classic Naskh: clear tashkeel, restful for long reading
                  fontWeight: FontWeight.w400,
                  fontSize: _fs,
                  height: 2.1, // room for the marks above/below the line
                  letterSpacing: 0,
                  color: cs.onSurface.withOpacity(.94),
                ),
              ),
              if (z.note != null) ...[
                const SizedBox(height: 8),
                Text(
                  z.note!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.6, color: cs.onSurface.withOpacity(.7)),
                ),
              ],
              const Divider(height: 24),
              Row(children: [
                Expanded(
                  child: Text(
                    z.source,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, height: 1.5, color: kGold, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                _counter(finished, remaining, z.count),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _counter(bool finished, int remaining, int total) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: finished ? kGold.withOpacity(.25) : cs.primaryContainer,
        border: Border.all(color: finished ? kGold : cs.primary, width: 1.6),
      ),
      child: finished
          ? Icon(Icons.check, color: cs.onSurface)
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Text(arabicNum(remaining), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.1)),
              if (total > 1) Text('من ${arabicNum(total)}', style: const TextStyle(fontSize: 9.5, height: 1.1)),
            ]),
    );
  }
}
