import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config.dart';
import '../data/app_state.dart';
import '../data/audio_store.dart';
import '../data/reciters.dart';
import '../widgets/index_sheet.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import '../widgets/mushaf_page_view.dart';

final _player = AudioPlayer();

class ReaderScreen extends StatefulWidget {
  final int page;
  final int? focusG; // verse to highlight when opened from search / bookmarks
  const ReaderScreen({super.key, required this.page, this.focusG});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pc = PageController(initialPage: widget.page - 1);
  late int _page = widget.page;
  int? playingG;
  Timer? _dwell;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // keep the screen on while reading
    appState.setLastPage(_page);
    _startDwell();
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted && playingG != null) {
        final next = playingG! + 1;
        next <= QuranRepository.total ? _play(next) : setState(() => playingG = null);
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // let the screen sleep normally again
    _dwell?.cancel();
    _sub?.cancel();
    _player.stop();
    _pc.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => appState.refresh());
    super.dispose();
  }

  void _startDwell() {
    _dwell?.cancel();
    final p = _page;
    _dwell = Timer(const Duration(seconds: 4), () => appState.markPageRead(p));
  }

  Future<void> _play(int g) async {
    setState(() => playingG = g);
    final pg = QuranRepository.ayahPage[g]!;
    if (pg != _page && _pc.hasClients) {
      _pc.animateToPage(pg - 1, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
    try {
      await _load(Reciters.byId(appState.reciter, appState.reciterName), g);
      unawaited(_player.play());
    } catch (_) {
      if (mounted) {
        setState(() => playingG = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تشغيل الصوت، تحقق من الاتصال')));
      }
    }
  }

  /// Plays the downloaded file when present, otherwise streams (trying fallback bitrates).
  Future<void> _load(Reciter r, int g) async {
    final st = AudioStore.I;
    if (st.ready && st.has(r.id, g)) {
      final f = st.fileFor(r.id, g);
      if (await f.exists()) {
        await _player.setFilePath(f.path);
        return;
      }
    }
    Object? last;
    for (final u in r.urls(g).take(3)) {
      try {
        await _player.setUrl(u);
        return;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('no audio url');
  }

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

  void _stop() { _player.stop(); setState(() => playingG = null); }

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
                  _Act(icon: Icons.play_arrow, label: 'تلاوة', onTap: () { Navigator.pop(sheetCtx); _play(g); }),
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
            title: Text('صفحة ${arabicNum(_page)}', style: const TextStyle(fontSize: 17)),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.menu), tooltip: 'الفهرس', onPressed: _openIndex),
              IconButton(icon: const Icon(Icons.pin_outlined), tooltip: 'انتقال', onPressed: _jumpDialog),
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
                onPressed: () => playingG == null ? _play(QuranRepository.pages[_page - 1].firstG) : _stop(),
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: appState,
            builder: (_, __) => PageView.builder(
              controller: _pc,
              scrollDirection: appState.readVertical ? Axis.vertical : Axis.horizontal,
              itemCount: QuranRepository.pageCount,
              onPageChanged: (i) {
                setState(() => _page = i + 1);
                appState.setLastPage(_page);
                _startDwell();
              },
              itemBuilder: (_, i) => MushafPageView(
                page: QuranRepository.pages[i],
                playingG: playingG ?? widget.focusG,
                onTapAyah: _openAyah,
              ),
            ),
          ),
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
