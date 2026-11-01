import 'package:flutter/material.dart';
import '../data/khatma_state.dart';
import '../data/quran_repository.dart';
import '../data/reader_session.dart';
import '../widgets/logo_mark.dart' show kGold;
import 'reader_screen.dart';

/// Opens the Mushaf in KHATMA mode: a separate reader route on the root navigator with its own
/// session, so its position, read-pages and history never mix with the Surah tab.
void openKhatmaReader(BuildContext c, int page) => Navigator.of(c, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(page: page, session: const KhatmaSession())),
    );

class KhatmaTab extends StatelessWidget {
  const KhatmaTab({super.key});

  static String _date(DateTime d) => '${arabicNum(d.day)}/${arabicNum(d.month)}/${arabicNum(d.year)}';

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بدء ختمة جديدة؟'),
          content: const Text('سيُصفَّر تقدّم الختمة الحالية (الصفحات المقروءة). لا يتأثر موضع القراءة في تبويب السور ولا الفواصل.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ من جديد')),
          ],
        ),
      ),
    );
    if (yes == true) khatmaState.resetKhatma();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: khatmaState,
        builder: (ctx, _) {
          final k = khatmaState;
          final cs = Theme.of(ctx).colorScheme;
          final done = k.completed;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('الختمة والورد اليومي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),

            // ── overall progress ring ──
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withOpacity(.5),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 104,
                        height: 104,
                        child: CircularProgressIndicator(value: k.progress, strokeWidth: 9, color: kGold, backgroundColor: cs.outlineVariant.withOpacity(.4)),
                      ),
                      Text('${arabicNum((k.progress * 100).floor())}٪', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${arabicNum(k.readCount)} من ${arabicNum(QuranRepository.pageCount)} صفحة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(done ? 'أتممتَ الختمة، تقبّل الله منك' : 'باقٍ ${arabicNum(QuranRepository.pageCount - k.readCount)} صفحة'),
                      if (!done) ...[
                        const SizedBox(height: 4),
                        Text('الختم المتوقع: ${_date(k.expectedFinish)}', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(.65))),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── today's wird ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: kGold.withOpacity(.6))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.today, color: kGold),
                    const SizedBox(width: 8),
                    const Text('ورد اليوم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${arabicNum(k.wirdDone)} / ${arabicNum(k.wirdPages)} صفحة'),
                  ]),
                  const SizedBox(height: 6),
                  if (!done) Text('من صفحة ${arabicNum(k.wirdFrom)} إلى صفحة ${arabicNum(k.wirdTo)}', style: TextStyle(color: cs.onSurface.withOpacity(.7))),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: k.wirdPages == 0 ? 0 : k.wirdDone / k.wirdPages,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                    color: kGold,
                  ),
                  const SizedBox(height: 14),
                  if (done)
                    const Text('ما شاء الله، أتممتَ الختمة', textAlign: TextAlign.center)
                  else if (k.wirdComplete) ...[
                    const Text('أتممتَ ورد اليوم ✓', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => openKhatmaReader(ctx, k.firstUnread.clamp(1, 604)),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('متابعة القراءة زيادة'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: () => openKhatmaReader(ctx, k.wirdResumePage),
                      icon: const Icon(Icons.menu_book),
                      label: Text(k.wirdDone == 0 ? 'ابدأ الورد' : 'تابع الورد'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── stats ──
            Row(children: [
              Expanded(child: _Stat(icon: Icons.local_fire_department, color: Colors.orange, value: arabicNum(k.streak), label: 'يوم متتالي')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(icon: Icons.auto_stories, color: cs.primary, value: arabicNum(k.todayCount), label: 'صفحة اليوم')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(icon: Icons.speed, color: kGold, value: arabicNum(k.perDay), label: 'صفحة / يوم')),
            ]),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('متابعة الختمة'),
              subtitle: Text('صفحة ${arabicNum(k.resumePage)}'),
              onTap: () => openKhatmaReader(ctx, k.resumePage),
            ),

            // ── per-juz progress ──
            ExpansionTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('تقدّم الأجزاء'),
              children: [
                for (final (i, e) in k.juzProgress().indexed)
                  ListTile(
                    dense: true,
                    title: Row(children: [
                      SizedBox(width: 74, child: Text('الجزء ${arabicNum(i + 1)}')),
                      Expanded(child: LinearProgressIndicator(value: e.$1 / e.$2, minHeight: 6, borderRadius: BorderRadius.circular(6), color: kGold)),
                      const SizedBox(width: 10),
                      Text('${arabicNum(e.$1)}/${arabicNum(e.$2)}', style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
              ],
            ),

            const SizedBox(height: 8),
            const Text('مدة الختمة'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final d in [7, 15, 30, 60, 90])
                ChoiceChip(label: Text('${arabicNum(d)} يوم'), selected: k.days == d, onSelected: (_) => k.setDays(d)),
            ]),
            const SizedBox(height: 14),
            TextButton.icon(onPressed: () => _confirmReset(ctx), icon: const Icon(Icons.restart_alt), label: const Text('بدء ختمة جديدة')),
            Text(
              'تُحتسب الصفحة كمقروءة بعد البقاء عليها بضع ثوانٍ، وذلك فقط عند القراءة من هذا التبويب. التصفّح من تبويب السور لا يغيّر الختمة.',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(.6)),
            ),
          ]);
        },
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _Stat({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}
