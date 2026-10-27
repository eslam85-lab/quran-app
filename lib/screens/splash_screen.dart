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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  String? error;

  @override
  void initState() {
    super.initState();
    Future.wait([bootstrap(), Future.delayed(const Duration(milliseconds: 3000))]).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    }).catchError((e) { if (mounted) setState(() => error = '$e'); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Animation<double> _in(double a, double b) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOut));

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: kGreen,
          body: Center(
            child: error != null
                ? Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: Colors.white)))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    FadeTransition(
                      opacity: _in(0, .4),
                      child: ScaleTransition(
                        scale: Tween(begin: .9, end: 1.0).animate(_in(0, .5)),
                        child: const LogoMark(size: 150),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _in(.2, .55),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(AppConfig.nameAr,
                            style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 64, color: Colors.white, height: 1.3)),
                        Text('ISLAM', style: TextStyle(fontSize: 16, letterSpacing: 8, color: kGold, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _in(.5, 1),
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(_in(.5, 1)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28),
                          child: Text(AppConfig.welcomeAr,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 28, color: kGold, height: 1.9)),
                        ),
                      ),
                    ),
                  ]),
          ),
        ),
      );
}
