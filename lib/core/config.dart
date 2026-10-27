// Edit these to rebrand the app.
class AppConfig {
  static const nameAr = 'إسلام';
  static const nameEn = 'Islam';
  static const sloganAr = 'التطبيق الأمثل لقراءة القرآن الكريم';
  static const sloganEn = 'The Premier Quran Reading App';
  static const developer = 'Eslam Elsayed';
  static const instagram =
      'https://www.instagram.com/eslam._elsayed?utm_source=qr&xtok=YTlyNW16NzVzZzJl';
  static const facebook = ''; // add link
  static const linkedin = ''; // add link
  static const reciters = {
    'ar.alafasy': 'مشاري العفاسي',
    'ar.husary': 'محمود خليل الحصري',
    'ar.minshawi': 'محمد صديق المنشاوي',
  };
  static String audioUrl(String reciter, int g) =>
      'https://cdn.islamic.network/quran/audio/128/$reciter/$g.mp3';
}
