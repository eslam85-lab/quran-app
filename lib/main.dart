import 'package:flutter/material.dart';
import 'core/config.dart';
import 'data/app_state.dart';
import 'data/audio_store.dart';
import 'data/quran_repository.dart';
import 'screens/splash_screen.dart';

final appState = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  try {
    await AudioStore.I.init();
  } catch (_) {}
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (_, __) {
          ThemeData theme(Brightness b) => ThemeData(
                useMaterial3: true,
                fontFamily: 'Tajawal',
                fontFamilyFallback: const ['Amiri', 'AmiriQuran'],
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4F), brightness: b),
                scaffoldBackgroundColor:
                    b == Brightness.dark ? const Color(0xFF101412) : const Color(0xFFFAF7F0),
              );
          return MaterialApp(
            title: AppConfig.nameEn,
            debugShowCheckedModeBanner: false,
            theme: theme(Brightness.light),
            darkTheme: theme(Brightness.dark),
            themeMode: appState.dark ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      );
}

Future<void> bootstrap() => QuranRepository.load();
