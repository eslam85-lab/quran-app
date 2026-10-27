import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'reciters.dart';

/// Offline audio: downloads verse mp3 files to app storage and tracks what exists.
class AudioStore extends ChangeNotifier {
  AudioStore._();
  static final AudioStore I = AudioStore._();

  Directory? _root;
  final Map<String, Set<int>> _have = {}; // reciter id -> downloaded verses
  final Map<String, int> _bitrate = {}; // reciter id -> bitrate that worked
  final Map<String, double> progress = {}; // task key -> 0..1
  final Set<String> _cancel = {};

  bool get ready => _root != null;

  Future<void> init() async {
    final d = await getApplicationDocumentsDirectory();
    final root = Directory('${d.path}/audio');
    await root.create(recursive: true);
    for (final e in root.listSync()) {
      if (e is! Directory) continue;
      final id = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final set = <int>{};
      for (final f in e.listSync()) {
        if (f is! File) continue;
        final n = f.uri.pathSegments.last;
        if (!n.endsWith('.mp3')) continue;
        final g = int.tryParse(n.substring(0, n.length - 4));
        if (g != null) set.add(g);
      }
      _have[id] = set;
    }
    _root = root;
  }

  File fileFor(String rid, int g) => File('${_root!.path}/$rid/$g.mp3');
  bool has(String rid, int g) => _have[rid]?.contains(g) ?? false;
  bool anyFor(String rid) => _have[rid]?.isNotEmpty ?? false;
  bool isBusy(String key) => progress.containsKey(key);
  void cancel(String key) => _cancel.add(key);

  int countFor(String rid, Iterable<int> gs) {
    final s = _have[rid];
    if (s == null) return 0;
    var n = 0;
    for (final g in gs) {
      if (s.contains(g)) n++;
    }
    return n;
  }

  Future<bool> _fetch(String url, File dest) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final res = await (await c.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        return false;
      }
      await dest.parent.create(recursive: true);
      final tmp = File('${dest.path}.part');
      final sink = tmp.openWrite();
      await res.pipe(sink);
      if (await tmp.length() < 1024) {
        await tmp.delete();
        return false;
      }
      await tmp.rename(dest.path);
      return true;
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }

  Future<bool> _get(Reciter r, int g) async {
    for (final u in r.urls(g, preferBitrate: _bitrate[r.id]).take(3)) {
      if (await _fetch(u, fileFor(r.id, g))) {
        (_have[r.id] ??= <int>{}).add(g);
        final m = RegExp(r'/audio/(\d+)/').firstMatch(u);
        if (m != null) _bitrate[r.id] = int.parse(m.group(1)!);
        return true;
      }
    }
    return false;
  }

  /// True if the reciter's first verse can be fetched (or files already exist offline).
  Future<bool> probe(Reciter r) async {
    if (anyFor(r.id)) return true;
    for (final u in r.urls(1).take(3)) {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final res = await (await c.getUrl(Uri.parse(u))).close();
        final ok = res.statusCode == 200;
        if (ok) return true;
      } catch (_) {
        // try next candidate
      } finally {
        c.close(force: true);
      }
    }
    return false;
  }

  /// Downloads verses [gs] for [r]. Returns the number of failures, or -1 if storage is unavailable.
  Future<int> download(String key, Reciter r, List<int> gs) async {
    if (!ready) return -1;
    if (progress.containsKey(key)) return 0;
    _cancel.remove(key);
    progress[key] = 0;
    notifyListeners();
    var next = 0, done = 0, fail = 0;
    Future<void> worker() async {
      while (!_cancel.contains(key)) {
        final i = next++;
        if (i >= gs.length) return;
        final g = gs[i];
        if (!has(r.id, g) && !await _get(r, g)) fail++;
        done++;
        progress[key] = done / gs.length;
        notifyListeners();
      }
    }

    await Future.wait([worker(), worker(), worker()]);
    progress.remove(key);
    _cancel.remove(key);
    notifyListeners();
    return fail;
  }

  Future<void> delete(String rid, Iterable<int> gs) async {
    final s = _have[rid];
    for (final g in gs) {
      s?.remove(g);
      try {
        final f = fileFor(rid, g);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    notifyListeners();
  }
}
