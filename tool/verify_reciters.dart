// Run from the project root, on a machine with internet:   dart run tool/verify_reciters.dart
// Reads every _ev('<folder>', ...) line (and its alt: [...] folders) from lib/data/reciters.dart and checks
// the first verse (001001) and the last verse (114006) on everyayah.com. Prints OK / MISSING per folder.
import 'dart:io';

Future<bool> exists(HttpClient c, String url) async {
  try {
    final r = await (await c.openUrl('HEAD', Uri.parse(url))).close();
    await r.drain<void>();
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final src = File('lib/data/reciters.dart').readAsStringSync();
  final line = RegExp(r"_ev\('([^']+)'[^\n]*?(?:alt: \[([^\]]*)\])?\)[,)]");
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  var bad = 0;
  for (final m in line.allMatches(src)) {
    final folders = [m.group(1)!, ...RegExp(r"'([^']+)'").allMatches(m.group(2) ?? '').map((e) => e.group(1)!)];
    var any = false;
    for (final f in folders) {
      final a = await exists(c, 'https://everyayah.com/data/$f/001001.mp3');
      final b = await exists(c, 'https://everyayah.com/data/$f/114006.mp3');
      stdout.writeln('${a && b ? "OK     " : "MISSING"}  $f');
      any = any || (a && b);
    }
    if (!any) bad++;
  }
  stdout.writeln('\nEditions with NO working folder: $bad');
  c.close(force: true);
}
