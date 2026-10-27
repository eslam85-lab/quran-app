import 'package:flutter/material.dart';
import '../core/config.dart';
import '../main.dart';
import '../widgets/logo_mark.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  String? error;

  @override
  void initState() {
    super.initState();
    Future.wait([bootstrap(), Future.delayed(const Duration(milliseconds: 1800))]).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    }).catchError((e) { if (mounted) setState(() => error = '$e'); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kGreen,
        body: Center(
          child: error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: Colors.white)))
              : FadeTransition(
                  opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                  child: ScaleTransition(
                    scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const LogoMark(size: 150),
                      const SizedBox(height: 12),
                      const Text(AppConfig.nameAr,
                          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 64, color: Colors.white, height: 1.3)),
                      const Text('ISLAM', style: TextStyle(fontSize: 16, letterSpacing: 8, color: kGold, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 18),
                      const Text(AppConfig.sloganAr, style: TextStyle(fontFamily: 'Amiri', fontSize: 17, color: Colors.white70)),
                    ]),
                  ),
                ),
        ),
      );
}
