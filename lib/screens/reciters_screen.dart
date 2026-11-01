import 'package:flutter/material.dart';
import '../data/arabic_search.dart';
import '../data/audio_store.dart';
import '../data/reciters.dart';
import '../main.dart';
import 'downloads_screen.dart';

/// Reciters grouped by sheikh, one row per edition (مرتّل / مجوّد / تراويح).
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

  /// Checks that the edition really has audio before selecting it (so a wrong folder never sticks).
  Future<void> _pick(Reciter r) async {
    if (r.soon) {
      _toast('المصدر الصوتي لهذه النسخة غير متوفر بعد');
      return;
    }
    setState(() => _busy = r.id);
    final ok = await AudioStore.I.probe(r);
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
    if (r.soon) return 'قريباً · لا يوجد مصدر صوتي آية بآية';
    if (AudioStore.I.anyFor(r.id)) return 'يوجد صوت محمّل';
    if (Reciters.checked[r.id] == false) return 'غير متاح حالياً';
    return r.isEvery ? 'everyayah.com' : 'islamic.network';
  }

  @override
  Widget build(BuildContext context) {
    final nq = normalizeAr(_q);
    final groups = <String, List<Reciter>>{};
    for (final r in Reciters.all) {
      if (nq.isNotEmpty && !normalizeAr('${r.groupName} ${r.name}').contains(nq)) continue;
      groups.putIfAbsent(r.groupName, () => []).add(r);
    }
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
    final sel = r.id == appState.reciter;
    final cs = Theme.of(ctx).colorScheme;
    return ListTile(
      enabled: !r.soon,
      leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: sel ? cs.primary : null),
      title: Text(r.style == ReciterStyle.other ? r.name : r.style.label),
      subtitle: Text(_source(r)),
      trailing: _busy == r.id
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : r.soon
              ? null
              : IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  tooltip: 'التحميل الصوتي',
                  onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => DownloadsScreen(reciter: r))),
                ),
      onTap: () => _pick(r),
    );
  }
}
