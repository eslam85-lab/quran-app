// Edit these to rebrand the app.
class AppConfig {
  static const nameAr = 'إسلام';
  static const nameEn = 'Islam';
  static const sloganAr = 'التطبيق الأمثل لقراءة القرآن الكريم';
  static const sloganEn = 'The Premier Quran Reading App';
  // Welcome line shown on the splash screen (with full tashkeel).
  static const welcomeAr = 'إِسْلَامٌ رَفِيقُكَ فِي تَدَبُّرِ كِتَابِ ٱللَّهِ';
  static const developer = 'Eslam Elsayed';
  static const instagram =
      'https://www.instagram.com/eslam._elsayed?utm_source=qr&xtok=YTlyNW16NzVzZzJl';
  static const facebook =
      'https://www.facebook.com/eslam.elsayed.570?mibextid=rS40aB7S9Ucbxw6v';
  static const linkedin =
      'https://www.linkedin.com/in/eslam-elsayed-249b7935b?utm_source=share_via&utm_content=profile&utm_medium=member_android';
  static const reciters = {
    'ar.alafasy': 'مشاري العفاسي',
    'ar.husary': 'محمود خليل الحصري',
    'ar.minshawi': 'محمد صديق المنشاوي',
  };
  static String audioUrl(String reciter, int g) =>
      'https://cdn.islamic.network/quran/audio/128/$reciter/$g.mp3';
}
