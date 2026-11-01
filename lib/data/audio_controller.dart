import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import 'audio_store.dart';
import 'quran_repository.dart';
import 'reciters.dart';

/// A memorization loop: verses [from]..[to] (global numbers) played [times] times.
/// times == 0 means "repeat until stopped".
class RepeatPlan {
  final int surah, from, to, times;
  final int gapSeconds; // silent pause after every verse (time to repeat it aloud)
  const RepeatPlan({required this.surah, required this.from, required this.to, required this.times, this.gapSeconds = 0});
  int get count => to - from + 1;
}

/// The one and only audio engine of the app. The reader, the memorization bar and
/// (later) background-audio notifications all talk to this single object.
class AudioController extends ChangeNotifier {
  AudioController._() {
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _onCompleted();
    });
    player.playingStream.listen((_) => notifyListeners());
  }
  static final AudioController I = AudioController._();

  final AudioPlayer player = AudioPlayer();

  int? currentG; // verse being played / highlighted
  RepeatPlan? plan; // non-null while a memorization loop is active
  int loop = 1; // current repetition (1-based)
  bool _continuous = false; // plain "listen": carry on to the next verse
  String? error; // last error message (the UI shows it once, then clears it)

  int _session = 0; // bumped on every start/stop so stale callbacks are ignored
  int _handled = -1;

  bool get active => currentG != null;
  bool get repeating => plan != null;
  bool get isPlaying => player.playing;

  // ───────────── public API ─────────────
  /// Plain listening: play [g], then continue verse after verse.
  Future<void> playVerse(int g) async {
    plan = null;
    _continuous = true;
    loop = 1;
    currentG = g;
    await _playCurrent();
  }

  /// Memorization loop.
  Future<void> startRepeat(RepeatPlan p) async {
    plan = p;
    _continuous = false;
    loop = 1;
    currentG = p.from;
    await _playCurrent();
  }

  void pause() => player.pause();

  void resume() {
    if (currentG == null) return;
    if (player.processingState == ProcessingState.idle) {
      _playCurrent();
    } else {
      player.play();
    }
  }

  void togglePause() => isPlaying ? pause() : resume();

  /// Restart the memorization loop from repetition 1, first verse.
  void resetLoop() {
    final p = plan;
    if (p == null) return;
    loop = 1;
    currentG = p.from;
    _playCurrent();
  }

  Future<void> stop() async {
    _session++;
    plan = null;
    _continuous = false;
    currentG = null;
    loop = 1;
    await player.stop();
    notifyListeners();
  }

  // ───────────── internals ─────────────
  Future<void> _playCurrent() async {
    final g = currentG;
    if (g == null) return;
    final s = ++_session;
    error = null;
    notifyListeners();
    try {
      await _load(Reciters.byId(appState.reciter, appState.reciterName), g);
      if (s != _session) return;
      unawaited(player.play());
    } catch (_) {
      if (s != _session) return;
      _session++;
      plan = null;
      _continuous = false;
      currentG = null;
      error = 'تعذر تشغيل الصوت، تحقق من الاتصال أو من توفر هذا القارئ';
      notifyListeners();
    }
  }

  Future<void> _onCompleted() async {
    final g = currentG;
    if (g == null || _handled == _session) return; // ignore duplicate "completed" events
    _handled = _session;
    final s = _session;

    final p = plan;
    final gap = p?.gapSeconds ?? 0;
    if (gap > 0) {
      await Future<void>.delayed(Duration(seconds: gap));
      if (s != _session) return; // stopped / restarted during the pause
    }

    if (p != null) {
      if (g < p.to) {
        currentG = g + 1;
      } else if (p.times == 0 || loop < p.times) {
        loop++;
        currentG = p.from;
      } else {
        await stop();
        return;
      }
      await _playCurrent();
    } else if (_continuous && g < QuranRepository.total) {
      currentG = g + 1;
      await _playCurrent();
    } else {
      await stop();
    }
  }

  /// Plays the downloaded file when present, otherwise streams (trying every candidate URL).
  Future<void> _load(Reciter r, int g) async {
    final st = AudioStore.I;
    if (st.ready && st.has(r.id, g)) {
      final f = st.fileFor(r.id, g);
      if (await f.exists()) {
        await player.setFilePath(f.path);
        return;
      }
    }
    Object? last;
    for (final u in r.urls(g).take(3)) {
      try {
        await player.setUrl(u);
        return;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('no audio url');
  }
}
