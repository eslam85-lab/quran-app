import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  PauseMode pauseMode = PauseMode.none;
  int gap = 0; // seconds, used when pauseMode == fixed

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

  void _setFrom(int v) => setState(() {
        from = v.clamp(1, max);
        if (to < from) to = from;
      });

  void _setTo(int v) => setState(() => to = v.clamp(from, max));

  void _start() {
    FocusManager.instance.primaryFocus?.unfocus(); // commits any half-typed number first
    final plan = RepeatPlan(
      surah: surah,
      from: s.ayahs[from - 1].g,
      to: s.ayahs[to - 1].g,
      times: times,
      pauseMode: pauseMode,
      gapSeconds: pauseMode == PauseMode.fixed ? gap : 0,
    );
    AudioController.I.startRepeat(plan);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + mq.viewInsets.bottom + mq.padding.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('تكرار الآيات للحفظ', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: surah,
            decoration: const InputDecoration(labelText: 'السورة', border: OutlineInputBorder()),
            items: [
              for (final x in QuranRepository.surahs) DropdownMenuItem(value: x.n, child: Text('${arabicNum(x.n)}. ${x.name}')),
            ],
            onChanged: (v) => setState(() => _setSurah(v!)),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: NumberStepper(label: 'من الآية', value: from, min: 1, max: max, onChanged: _setFrom)),
            const SizedBox(width: 12),
            Expanded(child: NumberStepper(label: 'إلى الآية', value: to, min: from, max: max, onChanged: _setTo)),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text('اضغط على الرقم لتكتبه مباشرة (١ – ${arabicNum(max)})',
                style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(.6))),
          ),
          const SizedBox(height: 14),
          const Text('عدد مرات التكرار'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final n in [3, 5, 10, 20])
              ChoiceChip(label: Text(arabicNum(n)), selected: times == n, onSelected: (_) => setState(() => times = n)),
            ChoiceChip(label: const Text('∞ بلا حد'), selected: times == 0, onSelected: (_) => setState(() => times = 0)),
          ]),
          const SizedBox(height: 8),
          NumberStepper(
            label: 'أو حدّد العدد',
            value: times == 0 ? 1 : times,
            min: 1,
            max: 999,
            onChanged: (v) => setState(() => times = v),
          ),
          const SizedBox(height: 14),
          const Text('وقفات الترديد'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final g in [0, 1, 2, 3, 5])
              ChoiceChip(
                label: Text(g == 0 ? 'بلا وقفة' : '${arabicNum(g)} ث'),
                selected: g == 0 ? pauseMode == PauseMode.none : (pauseMode == PauseMode.fixed && gap == g),
                onSelected: (_) => setState(() {
                  gap = g;
                  pauseMode = g == 0 ? PauseMode.none : PauseMode.fixed;
                }),
              ),
          ]),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: pauseMode == PauseMode.reciterDuration,
            onChanged: (v) => setState(() => pauseMode = v ? PauseMode.reciterDuration : PauseMode.none),
            title: const Text('وقفة بحسب مدة قراءة الشيخ للآية تماماً', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('بعد كل آية يصمت التطبيق بقدر مدتها نفسها، لتردّدها أنت بنفس الإيقاع'),
          ),
          if (pauseMode == PauseMode.none)
            Text('بلا وقفة: تنتقل الآيات والتكرارات متصلة بلا انقطاع ولا تأخير.',
                style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(.6))),
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

/// Parses Western or Arabic-Indic digits ("١٠٠" or "100").
int? parseDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final r in s.trim().runes) {
    final c = String.fromCharCode(r);
    final i = ar.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return int.tryParse(b.toString());
}

/// Number box the user can tap and type into, with +/- buttons as quick adjusters.
///  * valid numbers (min..max) are applied live while typing (typing "100" works digit by digit)
///  * an out-of-range number is shown in red and is clamped when the field loses focus / on "done"
class NumberStepper extends StatefulWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const NumberStepper({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _c = TextEditingController(text: arabicNum(widget.value));
  late final FocusNode _f = FocusNode()..addListener(_onFocus);
  bool _invalid = false;

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    // external change (+/- buttons, clamping by the other field): reflect it unless it is what we just typed
    if (old.value != widget.value && parseDigits(_c.text) != widget.value) {
      _setText(widget.value);
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _f.removeListener(_onFocus);
    _f.dispose();
    _c.dispose();
    super.dispose();
  }

  void _setText(int v) {
    final t = arabicNum(v);
    _c.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  void _onFocus() {
    if (_f.hasFocus) {
      _c.selection = TextSelection(baseOffset: 0, extentOffset: _c.text.length); // type over the old number
    } else {
      _commit();
    }
  }

  void _commit() {
    final n = parseDigits(_c.text);
    final v = (n ?? widget.value).clamp(widget.min, widget.max);
    setState(() => _invalid = false);
    _setText(v);
    if (v != widget.value) widget.onChanged(v);
  }

  void _typed(String text) {
    final n = parseDigits(text);
    final ok = n != null && n >= widget.min && n <= widget.max;
    setState(() => _invalid = text.isNotEmpty && !ok);
    if (ok && n != widget.value) widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    final err = Theme.of(context).colorScheme.error;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        enabledBorder: _invalid ? OutlineInputBorder(borderSide: BorderSide(color: err, width: 1.6)) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: widget.value > widget.min ? () => widget.onChanged(widget.value - 1) : null,
        ),
        Expanded(
          child: TextField(
            controller: _c,
            focusNode: _f,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')), LengthLimitingTextInputFormatter(4)],
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _invalid ? err : null),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
            onChanged: _typed,
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _f.unfocus(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: widget.value < widget.max ? () => widget.onChanged(widget.value + 1) : null,
        ),
      ]),
    );
  }
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
        final status = ac.inGap ? ' · وقفة، رددها الآن' : '';
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
                    Text('الآية ${arabicNum(a.i)} · التكرار $rep$status',
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
