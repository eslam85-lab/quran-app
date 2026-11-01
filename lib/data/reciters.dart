import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_store.dart';
import 'quran_repository.dart';

/// Recitation edition of a reciter.
enum ReciterStyle { murattal, mujawwad, muallim, tarawih, other }

extension ReciterStyleX on ReciterStyle {
  String get label => switch (this) {
        ReciterStyle.murattal => 'مرتّل',
        ReciterStyle.mujawwad => 'مجوّد',
        ReciterStyle.muallim => 'معلّم (للتعليم والحفظ)',
        ReciterStyle.tarawih => 'تراويح الحرم',
        ReciterStyle.other => '',
      };
}

/// A reciter edition whose audio is served verse by verse.
///   id 'ev.<folder>'  -> everyayah.com/data/<folder>/SSSAAA.mp3
///   any other id      -> cdn.islamic.network/quran/audio/<bitrate>/<id>/<global verse>.mp3
///
/// [altFolders] are extra everyayah folders tried (in order) when the primary folder fails.
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
  bool get soon => id.startsWith('soon.'); // legacy placeholders: never listed any more
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
  // Adding a reciter = adding ONE line below (or one JSON object in the remote catalog).
  //   _ev('<everyayah folder>', 'اسم الشيخ', style: ..., alt: ['<fallback folder>'])
  // Every entry is checked by the app against the real server (see [verifyAll]); an edition
  // whose audio cannot be reached is hidden automatically, so the list never shows a dead row.

  static Reciter _ev(String folder, String sheikh, {ReciterStyle style = ReciterStyle.murattal, List<String> alt = const []}) =>
      Reciter('ev.$folder', sheikh, group: sheikh, style: style, altFolders: alt);

  static final List<Reciter> builtin = [
    // ── Egyptian school (old & new generation) ──
    _ev('Abdul_Basit_Murattal_192kbps', 'عبد الباسط عبد الصمد', alt: ['Abdul_Basit_Murattal_64kbps']),
    _ev('Abdul_Basit_Mujawwad_128kbps', 'عبد الباسط عبد الصمد', style: ReciterStyle.mujawwad),
    _ev('Husary_128kbps', 'محمود خليل الحصري', alt: ['Husary_64kbps']),
    _ev('Husary_128kbps_Mujawwad', 'محمود خليل الحصري', style: ReciterStyle.mujawwad),
    _ev('Husary_Muallim_128kbps', 'محمود خليل الحصري', style: ReciterStyle.muallim),
    _ev('Minshawy_Murattal_128kbps', 'محمد صديق المنشاوي', alt: ['Menshawi_32kbps']),
    _ev('Minshawy_Mujawwad_192kbps', 'محمد صديق المنشاوي', style: ReciterStyle.mujawwad),
    _ev('Minshawy_Teacher_128kbps', 'محمد صديق المنشاوي', style: ReciterStyle.muallim),
    _ev('Mustafa_Ismail_48kbps', 'مصطفى إسماعيل'),
    _ev('mahmoud_ali_albanna_32kbps', 'محمود علي البنا'),
    _ev('Mohammad_al_Tablaway_128kbps', 'محمد الطبلاوي', alt: ['Mohammad_al_Tablaway_64kbps']),
    _ev('Ahmed_Neana_128kbps', 'أحمد نعينع'),
    _ev('Muhammad_AbdulKareem_128kbps', 'محمد عبد الكريم'),
    _ev('Ali_Hajjaj_AlSuesy_128kbps', 'علي حجاج السويسي'),
    _ev('Hani_Rifai_192kbps', 'هاني الرفاعي', alt: ['Hani_Rifai_64kbps']),
    _ev('Sahl_Yassin_128kbps', 'سهل ياسين'),
    _ev('Muhammad_Ayyoub_128kbps', 'محمد أيوب', alt: ['Muhammad_Ayyoub_64kbps', 'Muhammad_Ayyoub_32kbps']),
    _ev('Muhammad_Jibreel_128kbps', 'محمد جبريل', alt: ['Muhammad_Jibreel_64kbps']),

    // ── Haramain & Gulf ──
    _ev('Abdurrahmaan_As-Sudais_192kbps', 'عبد الرحمن السديس', alt: ['Abdurrahmaan_As-Sudais_64kbps']),
    _ev('Saood_ash-Shuraym_128kbps', 'سعود الشريم', alt: ['Saood_ash-Shuraym_64kbps']),
    _ev('Maher_AlMuaiqly_64kbps', 'ماهر المعيقلي', alt: ['MaherAlMuaiqly128kbps']),
    _ev('Ghamadi_40kbps', 'سعد الغامدي'),
    _ev('Salah_Al_Budair_128kbps', 'صلاح البدير'),
    _ev('Hudhaify_128kbps', 'علي الحذيفي', alt: ['Hudhaify_64kbps', 'Hudhaify_32kbps']),
    _ev('Abu_Bakr_Ash-Shaatree_128kbps', 'أبو بكر الشاطري', alt: ['Abu_Bakr_Ash-Shaatree_64kbps']),
    _ev('Yasser_Ad-Dussary_128kbps', 'ياسر الدوسري'),
    _ev('Nasser_Alqatami_128kbps', 'ناصر القطامي'),
    _ev('Muhsin_Al_Qasim_192kbps', 'محسن القاسم'),
    _ev('Abdullah_Basfar_192kbps', 'عبد الله بصفر', alt: ['Abdullah_Basfar_64kbps', 'Abdullah_Basfar_32kbps']),
    _ev('Abdullah_Matroud_128kbps', 'عبد الله مطرود'),
    _ev('Abdullaah_3awwaad_Al-Juhaynee_128kbps', 'عبد الله عوّاد الجهني'),
    _ev('Salaah_AbdulRahman_Bukhatir_128kbps', 'صلاح بو خاطر'),
    _ev('Khaalid_Abdullaah_al-Qahtaanee_192kbps', 'خالد القحطاني'),
    _ev('Fares_Abbad_64kbps', 'فارس عباد'),
    _ev('Khalefa_Al_Tunaiji_64kbps', 'خليفة الطنيجي'),
    _ev('Ibrahim_Akhdar_32kbps', 'إبراهيم الأخضر'),
    _ev('Karim_Mansoori_40kbps', 'كريم منصوري'),
    _ev('Ayman_Sowaid_64kbps', 'أيمن سويد'),
    _ev('Yaser_Salamah_128kbps', 'ياسر سلامة'),
    _ev('Nabil_Rifa3i_48kbps', 'نبيل الرفاعي'),
    _ev('Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net', 'أحمد بن علي العجمي', alt: ['Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com']),
    _ev('Ali_Jaber_64kbps', 'علي جابر'),

    // ── islamic.network CDN (kept id, so saved selection keeps working) ──
    const Reciter('ar.alafasy', 'مشاري راشد العفاسي', group: 'مشاري العفاسي', style: ReciterStyle.murattal),

    // NOT included on purpose (no verse-by-verse source could be confirmed, and a dead row is worse
    // than no row): Mustafa Ismail mujawwad, Mohamed Rifat, Mahmoud Al-Banna mujawwad, Ali Jaber
    // Tarawih. When you find a working folder, add ONE line, e.g.
    //   _ev('<folder>', 'مصطفى إسماعيل', style: ReciterStyle.mujawwad),
  ];

  /// Old ids → current ids (saved selections keep working).
  static const _legacy = {
    'ar.husary': 'ev.Husary_128kbps',
    'ar.minshawi': 'ev.Minshawy_Murattal_128kbps',
  };

  /// Extra entries from the optional remote catalog (see [fetchCatalog]).
  static List<Reciter> extra = [];

  /// Verse-by-verse Arabic reciters from the live islamic.network edition list.
  /// Not shown by default any more (their names are English and they duplicate the catalog);
  /// kept for [byId] so old saved selections still resolve.
  static List<Reciter> remote = [];
  static bool remoteLoaded = false;

  /// Availability results: reciter id -> reachable? (null = not checked yet)
  static final Map<String, bool> checked = {};

  /// Catalog shown in the UI: builtin + remote catalog, no duplicates, dead editions removed.
  static List<Reciter> get all {
    final seen = <String>{};
    return [
      for (final r in [...builtin, ...extra])
        if (!r.soon && seen.add(r.id)) r,
    ];
  }

  static List<Reciter> get usable => [for (final r in all) if (checked[r.id] != false) r];

  static Reciter byId(String id, [String? name]) {
    id = _legacy[id] ?? id;
    for (final r in [...builtin, ...extra, ...remote]) {
      if (r.id == id) return r;
    }
    return Reciter(id, name ?? id);
  }

  // ───────────── availability verification ─────────────
  static bool verifying = false;
  static const _ttl = Duration(days: 3);

  /// Checks every edition against the real server (4 at a time) and remembers the result for
  /// 3 days. [onProgress] is called after each check so a screen can refresh.
  static Future<void> verifyAll({void Function(int done, int total)? onProgress, bool force = false}) async {
    if (verifying) return;
    verifying = true;
    try {
      final p = await SharedPreferences.getInstance();
      Map<String, dynamic> cache = {};
      try {
        cache = Map<String, dynamic>.from(jsonDecode(p.getString('rc_cache') ?? '{}') as Map);
      } catch (_) {}
      final now = DateTime.now().millisecondsSinceEpoch;
      final todo = <Reciter>[];
      for (final r in all) {
        final e = cache[r.id];
        if (!force && e is List && e.length == 2 && now - (e[1] as int) < _ttl.inMilliseconds) {
          checked[r.id] = e[0] == 1;
        } else {
          todo.add(r);
        }
      }
      var done = all.length - todo.length;
      onProgress?.call(done, all.length);
      var i = 0;
      Future<void> worker() async {
        while (i < todo.length) {
          final r = todo[i++];
          var ok = false;
          try {
            ok = await AudioStore.I.probe(r);
          } catch (_) {}
          checked[r.id] = ok;
          cache[r.id] = [ok ? 1 : 0, DateTime.now().millisecondsSinceEpoch];
          onProgress?.call(++done, all.length);
        }
      }

      await Future.wait([for (var w = 0; w < 4; w++) worker()]);
      await p.setString('rc_cache', jsonEncode(cache));
    } finally {
      verifying = false;
    }
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
