import 'package:flutter/material.dart';
import '../data/arabic_search.dart';
import '../data/audio_store.dart';
import '../data/reciters.dart';
import '../main.dart';
import 'downloads_screen.dart';

/// Reciters grouped by sheikh, one row per edition (مرتّل / مجوّد / معلّم / تراويح).
/// Editions whose audio server cannot be reached are hidden automatically.
class RecitersScreen extends StatefulWidget {
  const RecitersScreen({super.key});
  @override
  State<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends State<RecitersScreen> {
  String _q = '';
  int _done = 0, _total = 0;
  bool _checking = false;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify({bool force = false}) async {
    setState(() {
      _checking = true;
      _total = Reciters.all.length;
      _done = Reciters.checked.length;
    });
    await Reciters.verifyAll(
      force: force,
      onProgress: (d, t) {
        if (mounted) setState(() { _done = d; _total = t; });
      },
    );
    if (mounted) setState(() => _checking = false);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  Future<void> _pick(Reciter r) async {
    setState(() => _busy = r.id);
    final ok = Reciters.checked[r.id] == true || await AudioStore.I.probe(r);
    Reciters.checked[r.id] = ok;
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok) {
      appState.setReciter(r.id, r.displayName);
      _toast('تم اختيار ${r.displayName}');
    } else {
      _toast('هذه النسخة غير متاحة حالياً أو لا يوجد اتصال');
    }
  }

  String _source(Reciter r) {
    if (AudioStore.I.anyFor(r.id)) return 'يوجد صوت محمّل';
    if (Reciters.checked[r.id] == null) return 'جارٍ التحقق…';
    return 'متاح · بثّ وتحميل';
  }

  @override
  Widget build(BuildContext context) {
    final nq = normalizeAr(_q);
    final groups = <String, List<Reciter>>{};
    for (final r in Reciters.usable) {
      if (nq.isNotEmpty && !normalizeAr('${r.groupName} ${r.name}').contains(nq)) continue;
      groups.putIfAbsent(r.groupName, () => []).add(r);
    }
    final hidden = Reciters.all.length - Reciters.usable.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القرّاء'),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'إعادة التحقق من المصادر', onPressed: _checking ? null : () => _verify(force: true)),
          ],
        ),
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
          if (_checking) ...[
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('جارٍ التحقق من مصادر الصوت… $_done / $_total', style: const TextStyle(fontSize: 12)),
            ),
          ] else if (hidden > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('أُخفيت $hidden نسخة لأن مصدر صوتها غير متاح الآن', style: const TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: appState,
              builder: (ctx, __) => ListView(children: [
                for (final e in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                    child: Text(e.key, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(ctx).colorScheme.primary)),
                  ),
                  for (final r in e.value) _tile(ctx, r),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext ctx, Reciter r) {
    final sel = Reciters.byId(appState.reciter).id == r.id;
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: sel ? cs.primary : null),
      title: Text(r.style == ReciterStyle.other ? r.name : r.style.label),
      subtitle: Text(_source(r)),
      trailing: _busy == r.id
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              tooltip: 'التحميل الصوتي',
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => DownloadsScreen(reciter: r))),
            ),
      onTap: () => _pick(r),
    );
  }
}
