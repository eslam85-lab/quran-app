# إسلام · Islam — Quran App (Flutter)

Madani mushaf (604 pages, line by line), Tafsir al-Muyassar, verse-by-verse audio, tagged bookmarks,
daily ayah, khatmah tracker. Fonts (Amiri Quran, Amiri, Tajawal — all SIL OFL) are bundled in `assets/fonts/`.

## Build via GitHub
1. Push this folder to the `main` branch of a new repo.
2. Actions → "Build APK" (runs on push, or "Run workflow").
3. The workflow first runs `tools/generate_quran.py`, which FAILS the build unless there are exactly
   114 surahs, 6236 verses, 604 pages and every verse appears in the mushaf layout exactly once.
4. Download `quran-apk` from the run's Artifacts.

## Local
```
python tools/generate_quran.py
flutter create . --platforms=android
flutter pub get && flutter run
```
(`flutter create` is only needed once; the INTERNET permission and icons are added by the workflow — copy that step for local release builds.)

## Rebrand
Edit `lib/core/config.dart` (names, slogan, links). Add Facebook/LinkedIn URLs there; empty values are hidden.
