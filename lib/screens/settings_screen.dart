import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../main.dart';
import '../data/reciters.dart';
import '../widgets/logo_mark.dart';
import 'downloads_screen.dart';
import 'reciters_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _open(BuildContext c, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('الإعدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          SwitchListTile(title: const Text('الوضع الداكن'), value: appState.dark, onChanged: appState.setDark),
          SwitchListTile(title: const Text('تمرير الصفحات عمودياً'), subtitle: const Text('بدلاً من التقليب الأفقي'),
              value: appState.readVertical, onChanged: appState.setVertical),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('القارئ'),
            subtitle: Text(appState.reciterName),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecitersScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: const Text('التحميل الصوتي'),
            subtitle: const Text('للاستماع دون إنترنت'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DownloadsScreen(reciter: Reciters.byId(appState.reciter, appState.reciterName)))),
          ),
          const Divider(height: 40),
          // ---------- About ----------
          const Center(child: LogoMark(size: 96)),
          const Center(child: Text(AppConfig.nameAr, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 40))),
          const Center(child: Text(AppConfig.nameEn, style: TextStyle(letterSpacing: 4, color: Colors.grey))),
          const SizedBox(height: 4),
          const Center(child: Text(AppConfig.sloganAr, style: TextStyle(fontFamily: 'Amiri', fontSize: 16))),
          const Center(child: Text(AppConfig.sloganEn, style: TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 24),
          const Center(child: Text('تصميم وتطوير', style: TextStyle(color: Colors.grey))),
          const Center(child: Text(AppConfig.developer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Instagram'),
              subtitle: const Text('@eslam._elsayed'), onTap: () => _open(context, AppConfig.instagram)),
          if (AppConfig.facebook.isNotEmpty)
            ListTile(leading: const Icon(Icons.facebook), title: const Text('Facebook'), onTap: () => _open(context, AppConfig.facebook)),
          if (AppConfig.linkedin.isNotEmpty)
            ListTile(leading: const Icon(Icons.work_outline), title: const Text('LinkedIn'), onTap: () => _open(context, AppConfig.linkedin)),
          const SizedBox(height: 16),
          const Center(child: Text('النص: المصحف العثماني برواية حفص عن عاصم · ٦٠٤ صفحة\nالتفسير: التفسير الميسر',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      );
}
