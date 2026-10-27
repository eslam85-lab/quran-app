import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../core/config.dart';
import '../data/app_state.dart';
import '../data/quran_repository.dart';
import '../main.dart';
import '../widgets/mushaf_page_view.dart';

final _player = AudioPlayer();

class ReaderScreen extends StatefulWidget {
  final int page;
  const ReaderScreen({super.key, required this.page});
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
    _dwell?.cancel();
    _sub?.cancel();
    _player.stop();
    _pc.dispose();
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
      await _player.setUrl(AppConfig.audioUrl(appState.reciter, g));
      unawaited(_player.play());
    } catch (_) {
      if (mounted) {
        setState(() => playingG = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تشغيل الصوت، تحقق من الاتصال')));
      }
    }
  }

  void _stop() { _player.stop(); setState(() => playingG = null); }

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
              final n = int.tryParse(ctl.text);
              if (n != null && n >= 1 && n <= 604) { _pc.jumpToPage(n - 1); Navigator.pop(ctx); }
            }, child: const Text('اذهب')),
          ],
        ),
      ),
    );
  }

  void _openAyah(int g) {
    final (s, a) = QuranRepository.byGlobal(g);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: .6, maxChildSize: .95,
          builder: (_, ctl) => ListView(controller: ctl, padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Text('${s.name} · آية ${arabicNum(a.i)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.play_arrow), onPressed: () { Navigator.pop(context); _play(g); }),
              ListenableBuilder(listenable: appState, builder: (_, __) {
                final marked = appState.bookmarkIndex(g) != null;
                return IconButton(
                  icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () { Navigator.pop(context); marked ? appState.removeBookmark(g) : _bookmarkDialog(s, a); });
              }),
            ]),
            const SizedBox(height: 12),
            Text(a.text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 26, height: 2)),
            const Divider(height: 32),
            const Text('التفسير الميسر', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(QuranRepository.tafsir[g - 1], style: const TextStyle(fontFamily: 'Amiri', fontSize: 19, height: 1.9)),
          ]),
        ),
      ),
    );
  }

  void _bookmarkDialog(Surah s, Ayah a) {
    final name = TextEditingController(text: '${s.name} ${a.i}');
    int color = 0;
    showDialog(context: context, builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: const Text('علامة جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            for (var i = 0; i < tagColors.length; i++)
              GestureDetector(onTap: () => set(() => color = i),
                child: CircleAvatar(backgroundColor: tagColors[i], radius: 16,
                    child: color == i ? const Icon(Icons.check, color: Colors.white, size: 18) : null)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () { appState.addBookmark(a.g, color, name.text); Navigator.pop(ctx); }, child: const Text('حفظ')),
        ],
      )),
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
              IconButton(icon: const Icon(Icons.pin_outlined), tooltip: 'انتقال', onPressed: _jumpDialog),
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
                playingG: playingG,
                onTapAyah: _openAyah,
              ),
            ),
          ),
        ),
      );
}
