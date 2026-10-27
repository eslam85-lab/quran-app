import 'package:flutter/material.dart';
import '../data/quran_repository.dart';
import '../main.dart';

class KhatmahScreen extends StatelessWidget {
  const KhatmahScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: appState,
        builder: (_, __) {
          final read = appState.readCount;
          final progress = read / QuranRepository.pageCount;
          final perDay = (QuranRepository.pageCount / appState.khatmahDays).ceil();
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Text('ختمة القرآن', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress, minHeight: 12, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 8),
            Text('${(progress * 100).toStringAsFixed(1)}% · ${arabicNum(read)} من ٦٠٤ صفحة'),
            const SizedBox(height: 24),
            Card(child: ListTile(leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                title: Text('${arabicNum(appState.streak)} يوم متتالي'), subtitle: const Text('سلسلة القراءة اليومية'))),
            Card(child: ListTile(leading: const Icon(Icons.today),
                title: Text('اليوم: ${arabicNum(appState.todayCount)} / ${arabicNum(perDay)} صفحة'),
                subtitle: Text('لختم القرآن خلال ${arabicNum(appState.khatmahDays)} يوماً'))),
            const SizedBox(height: 12),
            const Text('مدة الختمة'),
            Wrap(spacing: 8, children: [
              for (final d in [7, 15, 30, 60, 90])
                ChoiceChip(label: Text('${arabicNum(d)} يوم'), selected: appState.khatmahDays == d, onSelected: (_) => appState.setKhatmahDays(d)),
            ]),
            const SizedBox(height: 16),
            TextButton.icon(onPressed: appState.resetKhatmah, icon: const Icon(Icons.restart_alt), label: const Text('بدء ختمة جديدة')),
            const Text('تُحتسب الصفحة كمقروءة بعد البقاء عليها بضع ثوانٍ.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]);
        },
      );
}
