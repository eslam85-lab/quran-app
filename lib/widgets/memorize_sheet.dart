import 'package:flutter/material.dart';
import '../data/audio_controller.dart';
import '../data/quran_repository.dart';

/// Bottom sheet where the user picks surah, ayah range and number of repetitions.
Future<void> showMemorizeSheet(BuildContext context, {int? surah, int? fromAyah}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _MemorizeSheet(surah: surah ?? 1, fromAyah: fromAyah ?? 1),
    ),
  );
}

class _MemorizeSheet extends StatefulWidget {
  final int surah, fromAyah;
  const _MemorizeSheet({required this.surah, required this.fromAyah});
  @override
  State<_MemorizeSheet> createState() => _MemorizeSheetState();
}

class _MemorizeSheetState extends State<_MemorizeSheet> {
  late int surah = widget.surah;
  late int from = widget.fromAyah;
  late int to = widget.fromAyah;
  int times = 5; // 0 = endless
  int gap = 0;

  Surah get s => QuranRepository.surahs[surah - 1];
  int get max => s.ayahs.length;

  void _setSurah(int n) {
    surah = n;
    from = from.clamp(1, max);
    to = to.clamp(from, max);
  }

  @override
  void initState() {
    super.initState();
    _setSurah(widget.surah);
    from = widget.fromAyah.clamp(1, max);
    to = from;
  }

  void _start() {
    final plan = RepeatPlan(
      surah: surah,
      from: s.ayahs[from - 1].g,
      to: s.ayahs[to - 1].g,
      times: times,
      gapSeconds: gap,
    );
    AudioController.I.startRepeat(plan);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('تكرار الآيات للحفظ', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: surah,
            decoration: const InputDecoration(labelText: 'السورة', border: OutlineInputBorder()),
            items: [
              for (final x in QuranRepository.surahs)
                DropdownMenuItem(value: x.n, child: Text('${arabicNum(x.n)}. ${x.name}')),
            ],
            onChanged: (v) => setState(() => _setSurah(v!)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Stepper(label: 'من الآية', value: from, min: 1, max: max, onChanged: (v) => setState(() {
              from = v;
              if (to < from) to = from;
            }))),
            const SizedBox(width: 12),
            Expanded(child: _Stepper(label: 'إلى الآية', value: to, min: from, max: max, onChanged: (v) => setState(() => to = v))),
          ]),
          const SizedBox(height: 14),
          const Text('عدد مرات التكرار'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final n in [3, 5, 10, 20])
              ChoiceChip(label: Text(arabicNum(n)), selected: times == n, onSelected: (_) => setState(() => times = n)),
            ChoiceChip(label: const Text('∞ بلا حد'), selected: times == 0, onSelected: (_) => setState(() => times = 0)),
          ]),
          const SizedBox(height: 8),
          _Stepper(
            label: 'أو حدّد العدد',
            value: times == 0 ? 1 : times,
            min: 1,
            max: 999,
            onChanged: (v) => setState(() => times = v),
          ),
          const SizedBox(height: 14),
          const Text('وقفة بعد كل آية (لتردّدها بنفسك)'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final g in [0, 1, 2, 3, 5])
              ChoiceChip(label: Text(g == 0 ? 'بلا وقفة' : '${arabicNum(g)} ث'), selected: gap == g, onSelected: (_) => setState(() => gap = g)),
          ]),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: Text(times == 0
                ? 'ابدأ (${arabicNum(from)}–${arabicNum(to)} بلا حد)'
                : 'ابدأ (${arabicNum(from)}–${arabicNum(to)} × ${arabicNum(times)})'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: cs.primary),
          ),
        ]),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0)),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: value > min ? () => onChanged(value - 1) : null),
          Expanded(child: Text(arabicNum(value), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: value < max ? () => onChanged(value + 1) : null),
        ]),
      );
}

/// Compact control strip shown at the bottom of the reader while a memorization loop is active.
class MemorizeBar extends StatelessWidget {
  const MemorizeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AudioController.I;
    return ListenableBuilder(
      listenable: ac,
      builder: (ctx, _) {
        final p = ac.plan;
        final g = ac.currentG;
        if (p == null || g == null) return const SizedBox.shrink();
        final cs = Theme.of(ctx).colorScheme;
        final (s, a) = QuranRepository.byGlobal(g);
        final first = QuranRepository.byGlobal(p.from).$2.i;
        final last = QuranRepository.byGlobal(p.to).$2.i;
        final rep = p.times == 0 ? '${arabicNum(ac.loop)} · ∞' : '${arabicNum(ac.loop)} من ${arabicNum(p.times)}';
        return Material(
          color: cs.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('حفظ · ${s.name} ${arabicNum(first)}–${arabicNum(last)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSecondaryContainer)),
                    Text('الآية ${arabicNum(a.i)} · التكرار $rep',
                        style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer.withOpacity(.8))),
                  ]),
                ),
                IconButton(
                  tooltip: ac.isPlaying ? 'إيقاف مؤقت' : 'متابعة',
                  icon: Icon(ac.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 34),
                  onPressed: ac.togglePause,
                ),
                IconButton(tooltip: 'إعادة من البداية', icon: const Icon(Icons.restart_alt), onPressed: ac.resetLoop),
                IconButton(tooltip: 'إنهاء', icon: const Icon(Icons.stop_circle_outlined), onPressed: ac.stop),
              ]),
            ),
          ),
        );
      },
    );
  }
}
