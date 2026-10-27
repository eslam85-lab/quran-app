import 'package:flutter/material.dart';
import '../data/arabic_search.dart';
import '../data/audio_store.dart';
import '../data/quran_repository.dart';
import '../data/reciters.dart';

/// Download full surahs for one reciter and play them offline.
class DownloadsScreen extends StatelessWidget {
  final Reciter reciter;
  const DownloadsScreen({super.key, required this.reciter});

  Future<void> _start(BuildContext context, Surah s) async {
    final fail = await AudioStore.I.download('s${s.n}|${reciter.id}', reciter, [for (final a in s.ayahs) a.g]);
    if (!context.mounted) return;
    final msg = fail < 0
        ? 'التخزين غير متاح على هذا الجهاز'
        : fail == 0
            ? 'تم تحميل ${s.name}'
            : 'تعذّر تحميل ${arabicNum(fail)} آية، تحقق من الاتصال أو من توفر هذا القارئ';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(BuildContext context, Surah s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف صوت ${s.name}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (yes == true) await AudioStore.I.delete(reciter.id, [for (final a in s.ayahs) a.g]);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text('التحميل الصوتي · ${reciter.name}', style: const TextStyle(fontSize: 16)), centerTitle: true),
          body: ListenableBuilder(
            listenable: AudioStore.I,
            builder: (ctx, _) => ListView.builder(
              itemCount: QuranRepository.surahs.length,
              itemBuilder: (_, i) {
                final s = QuranRepository.surahs[i];
                final key = 's${s.n}|${reciter.id}';
                final gs = [for (final a in s.ayahs) a.g];
                final have = AudioStore.I.countFor(reciter.id, gs);
                final p = AudioStore.I.progress[key];
                final Widget trailing;
                if (p != null) {
                  trailing = IconButton(
                    tooltip: 'إلغاء',
                    onPressed: () => AudioStore.I.cancel(key),
                    icon: Stack(alignment: Alignment.center, children: [
                      SizedBox(width: 28, height: 28, child: CircularProgressIndicator(value: p, strokeWidth: 3)),
                      const Icon(Icons.close, size: 14),
                    ]),
                  );
                } else if (have == gs.length) {
                  trailing = IconButton(
                    icon: const Icon(Icons.cloud_done, color: Color(0xFF43A047)),
                    tooltip: 'محمّلة، اضغط للحذف',
                    onPressed: () => _confirmDelete(ctx, s),
                  );
                } else {
                  trailing = IconButton(
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: 'تحميل',
                    onPressed: () => _start(ctx, s),
                  );
                }
                return ListTile(
                  leading: CircleAvatar(radius: 18, child: Text(arabicNum(s.n), style: const TextStyle(fontSize: 12))),
                  title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 20)),
                  subtitle: Text(p != null
                      ? '${toArabicDigits((p * 100).round().toString())}٪'
                      : '${arabicNum(have)} / ${arabicNum(gs.length)} آية'),
                  trailing: trailing,
                );
              },
            ),
          ),
        ),
      );
}
