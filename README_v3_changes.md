# v3 changes — copy `lib/` over your project's `lib/`

NEW files
  lib/data/audio_controller.dart   single audio engine (listen + memorization loop)
  lib/data/khatma_state.dart       independent khatma / wird state (own prefs keys)
  lib/data/reader_session.dart     SurahSession / KhatmaSession (where progress is saved)
  lib/widgets/memorize_sheet.dart  range + repetitions sheet and the control bar
  lib/screens/khatma_tab.dart      dedicated Khatma tab

REPLACED files
  lib/data/reciters.dart           catalog with editions (murattal / mujawwad / tarawih)
  lib/screens/reader_screen.dart   uses the controller + sessions + memorize bar (keeps wakelock)
  lib/screens/reciters_screen.dart grouped by sheikh, one row per edition
  lib/screens/home_screen.dart     one Navigator per tab, IndexedStack, root-navigator reader
  lib/main.dart                    adds `await khatmaState.init();`

CAN BE DELETED
  lib/screens/khatmah_screen.dart  (replaced by khatma_tab.dart)

NOT touched: lib/widgets/mushaf_page_view.dart (keep your v5/v6 file), pubspec.yaml (no new packages).
