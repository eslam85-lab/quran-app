import 'package:flutter/material.dart';
import '../data/arabic_search.dart';
import '../data/audio_store.dart';
import '../data/reciters.dart';
import '../main.dart';
import 'downloads_screen.dart';

class RecitersScreen extends StatefulWidget {
  const RecitersScreen({super.key});
  @override
  State<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends State<RecitersScreen> {
  String _q = '';
  bool _loading = false, _failed = false;
  String? _busy;

  @override
  void initState() {
    super.initState();
    if (!Reciters.remoteLoaded) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    final ok = await Reciters.fetchRemote();
    if (!mounted) return;
    setState(() { _loading = false; _failed = !ok; });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  Future<void> _pick(Reciter r) async {
    setState(() => _busy = r.id);
    final ok = await AudioStore.I.probe(r);
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok) {
      appState.setReciter(r.id, r.name);
      _toast('تم اختيار ${r.name}');
    } else {
      _toast('هذا القارئ غير متاح حالياً أو لا يوجد اتصال');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nq = normalizeAr(_q);
    final list = Reciters.all.where((r) => nq.isEmpty || normalizeAr(r.name).contains(nq)).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('القرّاء'), centerTitle: true),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن قارئ',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            ListTile(
              dense: true,
              leading: const Icon(Icons.wifi_off),
              title: const Text('تعذّر جلب قائمة القرّاء الإضافية'),
              trailing: TextButton(onPressed: _load, child: const Text('إعادة')),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: appState,
              builder: (_, __) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  final sel = r.id == appState.reciter;
                  return ListTile(
                    leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: sel ? Theme.of(ctx).colorScheme.primary : null),
                    title: Text(r.name),
                    subtitle: Text(AudioStore.I.anyFor(r.id) ? 'يوجد صوت محمّل' : (r.isEvery ? 'everyayah.com' : 'islamic.network')),
                    trailing: _busy == r.id
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.cloud_download_outlined),
                            tooltip: 'التحميل الصوتي',
                            onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => DownloadsScreen(reciter: r))),
                          ),
                    onTap: () => _pick(r),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
