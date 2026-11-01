import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import 'audio_store.dart';
import 'quran_repository.dart';
import 'reciters.dart';

/// What happens between two verses while memorizing.
enum PauseMode {
  /// No pause: verses (and repetitions) are chained gaplessly.
  none,

  /// A fixed silent pause of [RepeatPlan.gapSeconds] after every verse.
  fixed,

  /// The pause lasts exactly as long as the reciter took to read that verse,
  /// so the user can repeat it aloud with the same rhythm.
  reciterDuration,
}

/// A memorization loop: verses [from]..[to] (global numbers) played [times] times.
/// times == 0 means "repeat until stopped".
class RepeatPlan {
  final int surah, from, to, times;
  final PauseMode pauseMode;
  final int gapSeconds; // used when pauseMode == fixed
  const RepeatPlan({
    required this.surah,
    required this.from,
    required this.to,
    required this.times,
    this.pauseMode = PauseMode.none,
    this.gapSeconds = 0,
  });

  int get count => to - from + 1;

  /// True when a silent pause is needed between verses (=> step-by-step playback).
  bool get hasPause => pauseMode == PauseMode.reciterDuration || (pauseMode == PauseMode.fixed && gapSeconds > 0);
}

/// The one and only audio engine of the app.
///
/// Two playback strategies, both preloading the next verse so nothing is cut or delayed:
///  * QUEUE mode (listening, and repetition without pauses): one gapless
///    [ConcatenatingAudioSource]. The native player prepares verse N+1 while verse N plays,
///    so the transition is sample-accurate. Repetitions are simply the range appended
///    again and again (extended in chunks while playing).
///  * STEP mode (repetition with a pause): verse by verse. During the pause the next verse is
///    already loaded (preloaded, paused), so `play()` at the end of the pause starts instantly.
class AudioController extends ChangeNotifier {
  AudioController._() {
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _onCompleted();
    });
    player.playingStream.listen((_) => notifyListeners());
    player.currentIndexStream.listen(_onIndex);
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) => _fail(_run));
  }
  static final AudioController I = AudioController._();

  final AudioPlayer player = AudioPlayer();

  int? currentG; // verse being played / highlighted
  RepeatPlan? plan; // non-null while a memorization loop is active
  int loop = 1; // current repetition (1-based)
  bool inGap = false; // true during a memorization pause
  Duration? gapLength; // length of the current pause (for the UI)
  String? error; // last error message (the UI shows it once, then clears it)

  int _run = 0; // bumped on every start/stop: stale async work is ignored
  int _step = 0; // bumped for every loaded item in STEP mode
  int _handledStep = -1;
  bool _userPaused = false;

  // QUEUE mode bookkeeping
  ConcatenatingAudioSource? _queue;
  int _built = 0; // listen: verses appended so far; repeat: rounds appended so far
  int _listenFrom = 0;
  int _k = 0; // index of the URL candidate that worked

  bool get active => currentG != null;
  bool get repeating => plan != null;
  bool get isPlaying => inGap ? !_userPaused : player.playing;
  bool get _stepMode => plan?.hasPause ?? false;

  // ───────────── public API ─────────────
  /// Plain listening: play [g], then continue verse after verse (gapless).
  Future<void> playVerse(int g) async {
    final run = _begin();
    plan = null;
    currentG = g;
    notifyListeners();
    await _startQueue(run, listenFrom: g);
  }

  /// Memorization loop.
  Future<void> startRepeat(RepeatPlan p) async {
    final run = _begin();
    plan = p;
    currentG = p.from;
    notifyListeners();
    if (p.hasPause) {
      await _startStep(run, p.from);
    } else {
      await _startQueue(run, listenFrom: p.from);
    }
  }

  void pause() {
    _userPaused = true;
    player.pause();
    notifyListeners();
  }

  void resume() {
    if (currentG == null) return;
    _userPaused = false;
    if (player.processingState == ProcessingState.idle) {
      final p = plan;
      final run = _run;
      if (p != null && p.hasPause) {
        _startStep(run, currentG!);
      } else {
        _startQueue(run, listenFrom: p == null ? currentG! : p.from);
      }
    } else if (!inGap) {
      player.play();
    }
    notifyListeners();
  }

  void togglePause() => isPlaying ? pause() : resume();

  /// Restart the memorization loop from repetition 1, first verse.
  void resetLoop() {
    final p = plan;
    if (p == null) return;
    startRepeat(p);
  }

  Future<void> stop() async {
    _run++;
    _step++;
    plan = null;
    currentG = null;
    loop = 1;
    inGap = false;
    gapLength = null;
    _userPaused = false;
    _queue = null;
    await player.stop();
    notifyListeners();
  }

  // ───────────── internals ─────────────
  int _begin() {
    final run = ++_run;
    _step++;
    error = null;
    loop = 1;
    inGap = false;
    gapLength = null;
    _userPaused = false;
    _queue = null;
    return run;
  }

  Reciter get _reciter => Reciters.byId(appState.reciter, appState.reciterName);

  AudioSource _source(Reciter r, int g, int k) {
    final st = AudioStore.I;
    if (st.ready && st.has(r.id, g)) {
      final f = st.fileFor(r.id, g);
      if (f.existsSync()) return AudioSource.file(f.path);
    }
    final urls = r.urls(g);
    if (urls.isEmpty) throw StateError('no audio url');
    return AudioSource.uri(Uri.parse(urls[math.min(k, urls.length - 1)]));
  }

  int _candidates(Reciter r, int g) => math.max(1, math.min(3, r.urls(g).length));

  void _fail(int run) {
    if (run != _run || currentG == null) return;
    _run++;
    _step++;
    plan = null;
    currentG = null;
    inGap = false;
    _queue = null;
    error = 'تعذر تشغيل الصوت، تحقق من الاتصال أو من توفر هذا القارئ';
    player.stop();
    notifyListeners();
  }

  // ───────────── QUEUE mode (gapless) ─────────────
  Future<void> _startQueue(int run, {required int listenFrom}) async {
    final r = _reciter;
    final p = plan;
    _listenFrom = listenFrom;
    Object? last = StateError('no audio url');
    for (var k = 0; k < _candidates(r, listenFrom); k++) {
      try {
        final q = ConcatenatingAudioSource(useLazyPreparation: true, children: _initialChildren(r, k, p));
        await player.setAudioSource(q, initialIndex: 0, initialPosition: Duration.zero);
        if (run != _run) return;
        _queue = q;
        _k = k;
        last = null;
        break;
      } catch (e) {
        last = e;
        if (run != _run) return;
      }
    }
    if (last != null) return _fail(run);
    await player.setLoopMode(LoopMode.off);
    if (run != _run) return;
    unawaited(player.play());
  }

  List<AudioSource> _initialChildren(Reciter r, int k, RepeatPlan? p) {
    if (p != null) {
      final rounds = p.times == 0 ? 10 : math.min(p.times, 10);
      _built = rounds;
      return [
        for (var i = 0; i < rounds; i++)
          for (var g = p.from; g <= p.to; g++) _source(r, g, k),
      ];
    }
    final end = math.min(_listenFrom + 39, QuranRepository.total);
    _built = end - _listenFrom + 1;
    return [for (var g = _listenFrom; g <= end; g++) _source(r, g, k)];
  }

  /// Keeps the queue ahead of the playhead (appending is gapless).
  void _extendQueue(int i) {
    final q = _queue;
    if (q == null) return;
    final r = _reciter;
    final p = plan;
    try {
      if (p != null) {
        final total = p.times == 0 ? 1 << 30 : p.times;
        if (_built < total && i >= (_built - 1) * p.count) {
          final add = math.min(10, total - _built);
          unawaited(q.addAll([
            for (var n = 0; n < add; n++)
              for (var g = p.from; g <= p.to; g++) _source(r, g, _k),
          ]));
          _built += add;
        }
      } else if (_listenFrom + _built <= QuranRepository.total && i >= _built - 6) {
        final start = _listenFrom + _built;
        final end = math.min(start + 39, QuranRepository.total);
        unawaited(q.addAll([for (var g = start; g <= end; g++) _source(r, g, _k)]));
        _built += end - start + 1;
      }
    } catch (_) {}
  }

  void _onIndex(int? i) {
    if (i == null || _queue == null || currentG == null || _stepMode) return;
    final p = plan;
    if (p != null) {
      loop = i ~/ p.count + 1;
      currentG = p.from + i % p.count;
    } else {
      currentG = _listenFrom + i;
    }
    _extendQueue(i);
    notifyListeners();
  }

  // ───────────── STEP mode (repetition with pauses) ─────────────
  /// Loads [g] (paused, fully prepared). Returns false if every URL candidate failed.
  Future<bool> _loadStep(int run, int g) async {
    final r = _reciter;
    for (var k = 0; k < _candidates(r, g); k++) {
      try {
        await player.setAudioSource(_source(r, g, k), preload: true);
        return run == _run;
      } catch (_) {
        if (run != _run) return false;
      }
    }
    return false;
  }

  Future<void> _startStep(int run, int g) async {
    _step++;
    _handledStep = _step; // ignore stray events while loading
    currentG = g;
    notifyListeners();
    await player.pause();
    if (!await _loadStep(run, g)) {
      if (run == _run) _fail(run);
      return;
    }
    _handledStep = -1;
    if (!_userPaused) unawaited(player.play());
  }

  Future<void> _onCompleted() async {
    if (_handledStep == _step) return; // ignore duplicate "completed" events
    _handledStep = _step;
    final run = _run;
    final g = currentG;
    final p = plan;
    if (g == null) return;

    if (p == null || !p.hasPause) {
      // QUEUE mode reached the very end of the queue.
      await stop();
      return;
    }

    // Which verse comes next?
    int next;
    var nextLoop = loop;
    if (g < p.to) {
      next = g + 1;
    } else if (p.times == 0 || loop < p.times) {
      next = p.from;
      nextLoop = loop + 1;
    } else {
      await stop();
      return;
    }

    // How long to stay silent: the verse's own duration, or a fixed number of seconds.
    final spoken = player.duration ?? const Duration(seconds: 2);
    final pause = p.pauseMode == PauseMode.reciterDuration ? spoken : Duration(seconds: p.gapSeconds);

    _step++; // new item: its own "completed" event must be handled separately
    _handledStep = _step; // ...but ignore stray events until it is loaded
    inGap = true;
    gapLength = pause;
    notifyListeners();
    await player.pause(); // "playing" stays true after completion; stop it from auto-starting the next load

    // Preload the next verse WHILE the pause runs, so it starts with zero delay afterwards.
    final loaded = _loadStep(run, next);
    final waited = Future<void>.delayed(pause);
    final ok = await loaded;
    await waited;
    if (run != _run) return;
    if (!ok) return _fail(run);

    inGap = false;
    gapLength = null;
    loop = nextLoop;
    currentG = next;
    _handledStep = -1; // armed: the next "completed" is the end of this verse
    notifyListeners();
    if (!_userPaused) unawaited(player.play());
  }
}
