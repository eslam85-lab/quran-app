# v4 changes — copy `lib/` over your project's `lib/` (+ optional `tool/`)

Changed files
  lib/data/audio_controller.dart    gapless queue engine + step engine with preloading + PauseMode
  lib/widgets/memorize_sheet.dart   typed ayah numbers (NumberStepper), "pause = reciter's duration" switch
  lib/data/reciters.dart            ~45 sheikhs, murattal/mujawwad/muallim editions, auto-verification
  lib/screens/reciters_screen.dart  hides unreachable editions, progress while verifying
  lib/data/khatma_state.dart        + unmarkPage()
  lib/data/reader_session.dart      read() removed; supportsMarking / isRead / markRead / unmarkRead
  lib/screens/reader_screen.dart    dwell timer removed; manual "تم القراءة" bar (Khatma mode only)
  lib/data/azkar_data.dart          + wake-up, in-prayer categories; extra morning/evening/after-prayer items
  lib/screens/azkar_screen.dart     font-size slider (saved), Amiri regular, scrollable tabs
New: tool/verify_reciters.dart      offline check of every everyayah folder

No new packages. Old downloads of ar.husary / ar.minshawi (islamic.network) are not reused:
those ids now map to the everyayah editions, so re-download if needed.

Not included (unchanged by me — keep your v4 versions): main.dart, home_screen.dart, khatma_tab.dart.
One optional text edit in khatma_tab.dart: replace the footnote with
  'لا تُحتسب الصفحة كمقروءة إلا إذا ضغطتَ «تم القراءة» أثناء القراءة من هذا التبويب. ...'
Because the zip is based on your v3_lib, diff reader_screen.dart / reciters_screen.dart against
your v4 copies if you edited them since.
