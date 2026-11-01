import 'dart:convert';
import 'dart:io';
import 'quran_repository.dart';

/// Recitation edition of a reciter.
enum ReciterStyle { murattal, mujawwad, tarawih, other }

extension ReciterStyleX on ReciterStyle {
  String get label => switch (this) {
        ReciterStyle.murattal => 'مرتّل',
        ReciterStyle.mujawwad => 'مجوّد',
        ReciterStyle.tarawih => 'تراويح الحرم',
        ReciterStyle.other => '',
      };
}

/// A reciter edition whose audio is served verse by verse.
///   id 'ev.<folder>'  -> everyayah.com/data/<folder>/SSSAAA.mp3
///   id 'soon.<x>'     -> placeholder: no verse-by-verse source known yet (shown disabled)
///   any other id      -> cdn.islamic.network/quran/audio/<bitrate>/<id>/<global verse>.mp3
///
/// [altFolders] are extra everyayah folders tried (in order) when the primary folder fails,
/// so a wrong guess for a folder name never breaks playback or downloads.
class Reciter {
  final String id, name;
  final String group; // sheikh name used to group his editions in the UI ('' = [name])
  final ReciterStyle style;
  final List<String> altFolders;
  const Reciter(
    this.id,
    this.name, {
    this.group = '',
    this.style = ReciterStyle.other,
    this.altFolders = const [],
  });

  bool get isEvery => id.startsWith('ev.');
  bool get soon => id.startsWith('soon.');
  String get folder => id.substring(3);
  String get groupName => group.isEmpty ? name : group;
  String get displayName => style == ReciterStyle.other ? name : '$groupName · ${style.label}';

  /// Candidate mp3 URLs for verse [g] (1..6236), best first.
  List<String> urls(int g, {int? preferBitrate}) {
    if (soon) return const [];
    if (isEvery) {
      final (s, a) = QuranRepository.byGlobal(g);
      String p3(int n) => n.toString().padLeft(3, '0');
      return [
        for (final f in [folder, ...altFolders]) 'https://everyayah.com/data/$f/${p3(s.n)}${p3(a.i)}.mp3',
      ];
    }
    final rates = <int>[128, 64, 192, 48, 40, 32];
    if (preferBitrate != null) {
      rates.remove(preferBitrate);
      rates.insert(0, preferBitrate);
    }
    return [for (final b in rates) 'https://cdn.islamic.network/quran/audio/$b/$id/$g.mp3'];
  }

  /// JSON shape used by the optional remote catalog (see [Reciters.fetchCatalog]).
  factory Reciter.fromJson(Map<String, dynamic> j) => Reciter(
        '${j['id']}',
        '${j['name']}',
        group: '${j['group'] ?? ''}',
        style: ReciterStyle.values.firstWhere((s) => s.name == j['style'], orElse: () => ReciterStyle.other),
        altFolders: [for (final f in (j['alt'] as List? ?? const [])) '$f'],
      );
}

class Reciters {
  // ───────────────────────────── CATALOG ─────────────────────────────
  // Adding a reciter = adding one line here (or one JSON object in the remote catalog).
  // Folder names marked [confirmed] were seen in public everyayah.com listings;
  // the others are best candidates and are checked by the app before use (see RecitersScreen).
  static const builtin = [
    // — existing entries (ids kept so saved selections keep working) —
    Reciter('ar.alafasy', 'مشاري راشد العفاسي', group: 'مشاري العفاسي', style: ReciterStyle.murattal),
    Reciter('ar.husary', 'محمود خليل الحصري', group: 'محمود خليل الحصري', style: ReciterStyle.murattal),
    Reciter('ar.minshawi', 'محمد صديق المنشاوي', group: 'محمد صديق المنشاوي', style: ReciterStyle.murattal),
    Reciter('ev.Ghamadi_40kbps', 'سعد الغامدي'),
    Reciter('ev.Yasser_Ad-Dussary_128kbps', 'ياسر الدوسري'),

    // — Ali Jaber —
    Reciter('ev.Ali_Jaber_64kbps', 'علي جابر', group: 'علي جابر', style: ReciterStyle.murattal), // [confirmed]
    Reciter('soon.ali_jaber_tarawih', 'علي جابر', group: 'علي جابر', style: ReciterStyle.tarawih),

    // — Mustafa Ismail —
    Reciter('ev.Mustafa_Ismail_48kbps', 'مصطفى إسماعيل', group: 'مصطفى إسماعيل', style: ReciterStyle.murattal),
    Reciter('soon.mustafa_ismail_mujawwad', 'مصطفى إسماعيل', group: 'مصطفى إسماعيل', style: ReciterStyle.mujawwad),

    // — Mohamed Rifat —
    Reciter('soon.mohamed_rifat', 'محمد رفعت', group: 'محمد رفعت', style: ReciterStyle.murattal),

    // — Mahmoud Khalil Al-Husary —
    Reciter('ev.Husary_128kbps', 'محمود خليل الحصري', group: 'محمود خليل الحصري',
        style: ReciterStyle.murattal, altFolders: ['Husary_64kbps']), // [confirmed: Husary_128kbps]
    Reciter('ev.Husary_128kbps_Mujawwad', 'محمود خليل الحصري', group: 'محمود خليل الحصري',
        style: ReciterStyle.mujawwad), // [confirmed]

    // — Mohamed Siddiq Al-Minshawi —
    Reciter('ev.Minshawy_Murattal_128kbps', 'محمد صديق المنشاوي', group: 'محمد صديق المنشاوي',
        style: ReciterStyle.murattal, altFolders: ['Menshawi_32kbps']), // Menshawi_32kbps [confirmed]
    Reciter('ev.Minshawy_Mujawwad_192kbps', 'محمد صديق المنشاوي', group: 'محمد صديق المنشاوي',
        style: ReciterStyle.mujawwad),

    // — Mahmoud Ali Al-Banna —
    Reciter('ev.mahmoud_ali_albanna_32kbps', 'محمود علي البنا', group: 'محمود علي البنا', style: ReciterStyle.murattal),
    Reciter('soon.mahmoud_ali_albanna_mujawwad', 'محمود علي البنا', group: 'محمود علي البنا', style: ReciterStyle.mujawwad),
  ];

  /// Extra entries from the optional remote catalog (see [fetchCatalog]).
  static List<Reciter> extra = [];

  /// Verse-by-verse Arabic reciters from the live islamic.network edition list.
  static List<Reciter> remote = [];
  static bool remoteLoaded = false;

  /// Results of availability checks done by the UI: reciter id -> reachable?
  static final Map<String, bool> checked = {};

  static List<Reciter> get all {
    final seen = <String>{};
    return [
      for (final r in [...builtin, ...extra, ...remote])
        if (seen.add(r.id)) r,
    ];
  }

  static Reciter byId(String id, [String? name]) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return Reciter(id, name ?? id);
  }

  /// Optional: load more reciters from your own JSON file, e.g. a raw GitHub URL:
  /// [{"id":"ev.Some_Folder_64kbps","name":"…","group":"…","style":"murattal","alt":["Other_Folder"]}]
  static Future<bool> fetchCatalog(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final res = await (await c.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        return false;
      }
      final list = jsonDecode(await res.transform(utf8.decoder).join()) as List;
      extra = [for (final e in list) Reciter.fromJson(Map<String, dynamic>.from(e as Map))];
      return true;
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }

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
