import 'dart:convert';
import 'dart:io';
import 'quran_repository.dart';

/// A reciter whose audio is served verse by verse.
/// id 'ev.<folder>'  -> everyayah.com/data/<folder>/SSSAAA.mp3
/// any other id      -> cdn.islamic.network/quran/audio/<bitrate>/<id>/<global verse>.mp3
class Reciter {
  final String id, name;
  const Reciter(this.id, this.name);

  bool get isEvery => id.startsWith('ev.');
  String get folder => id.substring(3);

  /// Candidate mp3 URLs for verse [g] (1..6236), best first.
  List<String> urls(int g, {int? preferBitrate}) {
    if (isEvery) {
      final (s, a) = QuranRepository.byGlobal(g);
      String p3(int n) => n.toString().padLeft(3, '0');
      return ['https://everyayah.com/data/$folder/${p3(s.n)}${p3(a.i)}.mp3'];
    }
    final rates = <int>[128, 64, 192, 48, 40, 32];
    if (preferBitrate != null) {
      rates.remove(preferBitrate);
      rates.insert(0, preferBitrate);
    }
    return [for (final b in rates) 'https://cdn.islamic.network/quran/audio/$b/$id/$g.mp3'];
  }
}

class Reciters {
  /// Only ar.alafasy and ar.husary were confirmed in the live edition list.
  /// The "ev." entries come from everyayah.com and are checked at selection time.
  static const builtin = [
    Reciter('ar.alafasy', 'مشاري راشد العفاسي'),
    Reciter('ar.husary', 'محمود خليل الحصري'),
    Reciter('ar.minshawi', 'محمد صديق المنشاوي'),
    Reciter('ev.Ghamadi_40kbps', 'سعد الغامدي'),
    Reciter('ev.Yasser_Ad-Dussary_128kbps', 'ياسر الدوسري'),
    Reciter('ev.Ali_Jaber_64kbps', 'علي جابر'),
  ];

  static List<Reciter> remote = [];
  static bool remoteLoaded = false;

  static List<Reciter> get all {
    final ids = builtin.map((e) => e.id).toSet();
    return [...builtin, ...remote.where((r) => !ids.contains(r.id))];
  }

  static Reciter byId(String id, [String? name]) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return Reciter(id, name ?? id);
  }

  /// Verse-by-verse Arabic reciters from the live islamic.network edition list.
  static Future<bool> fetchRemote() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await c.getUrl(Uri.parse('https://api.alquran.cloud/v1/edition/format/audio'));
      final res = await req.close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        return false;
      }
      final body = await res.transform(utf8.decoder).join();
      final data = (jsonDecode(body) as Map)['data'] as List;
      remote = [
        for (final e in data)
          if (e['type'] == 'versebyverse' && e['language'] == 'ar') Reciter('${e['identifier']}', '${e['name']}')
      ];
      remoteLoaded = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }
}
