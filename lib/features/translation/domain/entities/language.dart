import 'package:equatable/equatable.dart';

class Language extends Equatable {
  final String code;
  final String name;
  final String native;
  final String flag;
  const Language({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  @override
  List<Object> get props => [code, name, native, flag];
}

const List<Language> languages = [
  Language(code: 'en', name: 'English', native: 'English', flag: '🇺🇸'),
  Language(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸'),
  Language(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷'),
  Language(code: 'de', name: 'German', native: 'Deutsch', flag: '🇩🇪'),
  Language(code: 'it', name: 'Italian', native: 'Italiano', flag: '🇮🇹'),
  Language(code: 'pt', name: 'Portuguese', native: 'Português', flag: '🇧🇷'),
  Language(code: 'ru', name: 'Russian', native: 'Русский', flag: '🇷🇺'),
  Language(code: 'zh-cn', name: 'Chinese', native: '简体中文', flag: '🇨🇳'),
  Language(code: 'ja', name: 'Japanese', native: '日本語', flag: '🇯🇵'),
  Language(code: 'ko', name: 'Korean', native: '한국어', flag: '🇰🇷'),
  Language(code: 'ar', name: 'Arabic', native: 'العربية', flag: '🇸🇦'),
  Language(code: 'hi', name: 'Hindi', native: 'हिन्दी', flag: '🇮🇳'),
  Language(code: 'bn', name: 'Bengali', native: 'বাংলা', flag: '🇧🇩'),
  Language(code: 'tr', name: 'Turkish', native: 'Türkçe', flag: '🇹🇷'),
  Language(code: 'nl', name: 'Dutch', native: 'Nederlands', flag: '🇳🇱'),
  Language(code: 'pl', name: 'Polish', native: 'Polski', flag: '🇵🇱'),
  Language(code: 'uk', name: 'Ukrainian', native: 'Українська', flag: '🇺🇦'),
  Language(code: 'sv', name: 'Swedish', native: 'Svenska', flag: '🇸🇪'),
  Language(code: 'th', name: 'Thai', native: 'ไทย', flag: '🇹🇭'),
  Language(code: 'vi', name: 'Vietnamese', native: 'Tiếng Việt', flag: '🇻🇳'),
  Language(
    code: 'id',
    name: 'Indonesian',
    native: 'Bahasa Indonesia',
    flag: '🇮🇩',
  ),
  Language(code: 'he', name: 'Hebrew', native: 'עברית', flag: '🇮🇱'),
  Language(code: 'fa', name: 'Persian', native: 'فارسی', flag: '🇮🇷'),
  Language(code: 'ta', name: 'Tamil', native: 'தமிழ்', flag: '🇮🇳'),
  Language(code: 'sw', name: 'Swahili', native: 'Kiswahili', flag: '🇹🇿'),
  // + 87 more languages in production
];

Language languageByCode(String code) {
  final normalizedCode = code.toLowerCase();
  return languages.firstWhere(
    (lang) => lang.code == normalizedCode,
    orElse: () {
      final prefix = normalizedCode.split('-').first;
      return languages.firstWhere(
        (lang) => lang.code == prefix,
        orElse: () => languages.first,
      );
    },
  );
}
