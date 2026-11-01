import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/config.dart';
import '../data/app_state.dart';
import '../data/audio_controller.dart';
import '../data/audio_store.dart';
import '../data/khatma_state.dart';
import '../data/reader_session.dart';
import '../data/reciters.dart';
import '../widgets/index_sheet.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import '../widgets/memorize_sheet.dart';
import '../widgets/mushaf_page_view.dart';

class ReaderScreen extends StatefulWidget {
  final int page;
  final int? focusG; // verse to highlight when opened from search / bookmarks
  /// Where reading progress is stored: SurahSession (default) or KhatmaSession.
  final ReaderSession session;
  const ReaderScreen({super.key, required this.page, this.focusG, this.session = const SurahSession()});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pc = PageController(initialPage: widget.page - 1);
  late int _page = widget.page;
  int? playingG;
  final ac = AudioController.I;
  int? _lastG;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the screen on while reading
    widget.session.visit(_page);
    ac.addListener(_onAudio);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    ac.removeListener(_onAudio);
    ac.stop();
    _pc.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.session.exit());
    super.dispose();
  }

  /// Follows the audio engine: highlight the verse, turn the page, show errors once.
  void _onAudio() {
    if (!mounted) return;
    final g = ac.currentG;
    if (g != _lastG) {
      _lastG = g;
      if (g != null) {
        final pg = QuranRepository.ayahPage[g]!;
        if (pg != _page && _pc.hasClients) {
          _pc.animateToPage(pg - 1, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        }
      }
    }
    if (g != playingG) setState(() => playingG = g);
    final err = ac.error;
    if (err != null) {
      ac.error = null;
      _toast(err);
    }
  }

  /// Manual khatma control: a page counts as read ONLY when the user taps this button.
  Widget _markBar() => ListenableBuilder(
        listenable: Listenable.merge([khatmaState, ac]),
        builder: (ctx, _) {
          final cs = Theme.of(ctx).colorScheme;
          final read = widget.session.isRead(_page);
          return Material(
            color: cs.surface,
            elevation: 6,
            child: SafeArea(
              top: false,
              bottom: !ac.repeating, // the memorize bar below already covers the system inset
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: read
                    ? FilledButton.tonalIcon(
                        onPressed: () {
                          widget.session.unmarkRead(_page);
                          _toast('أُلغيت علامة القراءة لهذه الصفحة');
                        },
                        icon: const Icon(Icons.check_circle),
                        label: Text('تمت قراءة صفحة ${arabicNum(_page)} · اضغط للتراجع'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          widget.session.markRead(_page);
                          HapticFeedback.mediumImpact();
                          if (_pc.hasClients && _page < QuranRepository.pageCount) {
                            _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          }
                        },
                        icon: const Icon(Icons.done_all),
                        label: Text('تم القراءة · صفحة ${arabicNum(_page)}'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      ),
              ),
            ),
          );
        },
      );

  void _openIndex() => showIndexSheet(context, (page) => _pc.jumpToPage(page - 1));

  Future<void> _downloadPage() async {
    final r = Reciters.byId(appState.reciter, appState.reciterName);
    final page = _page;
    final gs = <int>{};
    for (final row in QuranRepository.pages[page - 1].rows) {
      for (final w in row.words) {
        gs.add(w.g);
      }
    }
    _toast('جارٍ تحميل صوت الصفحة…');
    final fail = await AudioStore.I.download('pg$page|${r.id}', r, gs.toList()..sort());
    if (fail < 0) {
      _toast('التخزين غير متاح على هذا الجهاز');
    } else {
      _toast(fail == 0 ? 'تم تحميل صوت الصفحة' : 'تعذّر تحميل ${arabicNum(fail)} آية، تحقق من الاتصال');
    }
  }

  void _openMemorize({int? surah, int? ayah}) {
    final pg = QuranRepository.pages[_page - 1];
    final first = QuranRepository.byGlobal(pg.firstG);
    showMemorizeSheet(context, surah: surah ?? first.$1.n, fromAyah: ayah ?? first.$2.i);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  static int? _parseNum(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final r in s.trim().runes) {
      final c = String.fromCharCode(r);
      final i = ar.indexOf(c);
      b.write(i >= 0 ? '$i' : c);
    }
    return int.tryParse(b.toString());
  }

  void _jumpDialog() {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('الانتقال إلى صفحة'),
          content: TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true,
              decoration: const InputDecoration(hintText: '١ - ٦٠٤')),
          actions: [
            FilledButton(onPressed: () {
              final n = _parseNum(ctl.text);
              if (n != null && n >= 1 && n <= 604) { _pc.jumpToPage(n - 1); Navigator.pop(ctx); }
            }, child: const Text('اذهب')),
          ],
        ),
      ),
    );
  }

  // ---------- verse action sheet ----------
  void _openAyah(int g) {
    final (s, a) = QuranRepository.byGlobal(g);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: .65, maxChildSize: .95,
          builder: (_, ctl) => ListenableBuilder(
            listenable: appState,
            builder: (_, __) {
              final marked = appState.isBookmarked(g);
              final starred = appState.isStarred(g);
              final note = appState.noteOf(g);
              return ListView(controller: ctl, padding: const EdgeInsets.all(20), children: [
                Text('${s.name} · آية ${arabicNum(a.i)}',
                    style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _Act(icon: Icons.play_arrow, label: 'تلاوة', onTap: () { Navigator.pop(sheetCtx); ac.playVerse(g); }),
                  _Act(icon: Icons.repeat, label: 'تكرار', onTap: () { Navigator.pop(sheetCtx); _openMemorize(surah: s.n, ayah: a.i); }),
                  _Act(icon: Icons.copy, label: 'نسخ', onTap: () {
                    Clipboard.setData(ClipboardData(text: '${a.text} ﴿${arabicNum(a.i)}﴾\n[${s.name}]'));
                    Navigator.pop(sheetCtx);
                    _toast('تم نسخ الآية');
                  }),
                  _Act(
                    icon: marked ? Icons.bookmark : Icons.bookmark_border,
                    color: appState.bookmarkColorOf(g),
                    label: 'فاصل',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      marked ? appState.removeBookmark(g) : _bookmarkDialog(s, a);
                    },
                  ),
                  _Act(
                    icon: starred ? Icons.star : Icons.star_border,
                    color: starred ? const Color(0xFFFFB300) : null,
                    label: 'نجمة',
                    onTap: () => appState.toggleStar(g),
                  ),
                  _Act(
                    icon: note == null ? Icons.edit_note : Icons.sticky_note_2,
                    label: 'ملاحظة',
                    onTap: () { Navigator.pop(sheetCtx); _noteDialog(g); },
                  ),
                ]),
                const SizedBox(height: 16),
                Text(a.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 26, height: 2)),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(note),
                  ),
                ],
                const Divider(height: 32),
                const Text('التفسير الميسر', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(QuranRepository.tafsir[g - 1], style: const TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.9)),
              ]);
            },
          ),
        ),
      ),
    );
  }

  void _bookmarkDialog(Surah s, Ayah a) {
    final name = TextEditingController(text: '${s.name} ${arabicNum(a.i)}');
    int color = 0;
    showDialog(context: context, builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: const Text('فاصل جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            for (var i = 0; i < tagColors.length; i++)
              GestureDetector(onTap: () => set(() => color = i),
                child: CircleAvatar(backgroundColor: tagColors[i], radius: 16,
                    child: color == i ? Icon(Icons.check, color: i == 1 ? Colors.black87 : Colors.white, size: 18) : null)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () { appState.addBookmark(a.g, color, name.text); Navigator.pop(ctx); }, child: const Text('حفظ')),
        ],
      )),
    ));
  }

  void _noteDialog(int g) {
    final ctl = TextEditingController(text: appState.noteOf(g) ?? '');
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('ملاحظة على الآية'),
        content: TextField(controller: ctl, autofocus: true, minLines: 3, maxLines: 8,
            decoration: const InputDecoration(hintText: 'اكتب تأملاتك هنا')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () { appState.setNote(g, ctl.text); Navigator.pop(ctx); }, child: const Text('حفظ')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${widget.session.titlePrefix}صفحة ${arabicNum(_page)}', style: const TextStyle(fontSize: 17)),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.menu), tooltip: 'الفهرس', onPressed: _openIndex),
              IconButton(icon: const Icon(Icons.pin_outlined), tooltip: 'انتقال', onPressed: _jumpDialog),
              IconButton(icon: const Icon(Icons.repeat_on), tooltip: 'تكرار للحفظ', onPressed: _openMemorize),
              ListenableBuilder(
                listenable: AudioStore.I,
                builder: (_, __) => AudioStore.I.isBusy('pg$_page|${appState.reciter}')
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: const Icon(Icons.cloud_download_outlined), tooltip: 'تحميل صوت الصفحة', onPressed: _downloadPage),
              ),
              IconButton(
                icon: Icon(playingG == null ? Icons.headphones : Icons.stop_circle_outlined),
                tooltip: 'استماع',
                onPressed: () => playingG == null ? ac.playVerse(QuranRepository.pages[_page - 1].firstG) : ac.stop(),
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              // while the memorize bar is visible it already sits above the system nav area,
              // so the page must not reserve that inset a second time
              child: ListenableBuilder(
                listenable: ac,
                builder: (ctx, child) {
                  final mq = MediaQuery.of(ctx);
                  if (!ac.repeating && !widget.session.supportsMarking) return child!;
                  return MediaQuery(
                    data: mq.copyWith(
                      padding: mq.padding.copyWith(bottom: 0),
                      viewPadding: mq.viewPadding.copyWith(bottom: 0),
                      systemGestureInsets: mq.systemGestureInsets.copyWith(bottom: 0),
                    ),
                    child: child!,
                  );
                },
                child: ListenableBuilder(
                  listenable: appState,
                  builder: (_, __) => PageView.builder(
                    controller: _pc,
                    scrollDirection: appState.readVertical ? Axis.vertical : Axis.horizontal,
                    itemCount: QuranRepository.pageCount,
                    onPageChanged: (i) {
                      setState(() => _page = i + 1);
                      widget.session.visit(_page);
                    },
                    itemBuilder: (_, i) => MushafPageView(
                      page: QuranRepository.pages[i],
                      playingG: playingG ?? widget.focusG,
                      onTapAyah: _openAyah,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.session.supportsMarking) _markBar(),
            const MemorizeBar(),
          ]),
        ),
      );
}

class _Act extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Act({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}
