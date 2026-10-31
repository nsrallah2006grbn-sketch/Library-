class Country {
  final String code, name;
  final List<String> dials;
  const Country(this.code, this.name, this.dials);
  String get dial => dials.first;
  String get flag => String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

const countries = [
  Country('SA', 'السعودية', ['+966']), Country('AE', 'الإمارات', ['+971']),
  Country('KW', 'الكويت', ['+965']), Country('QA', 'قطر', ['+974']),
  Country('BH', 'البحرين', ['+973']), Country('OM', 'عُمان', ['+968']),
  Country('YE', 'اليمن', ['+967']), Country('JO', 'الأردن', ['+962']),
  Country('LB', 'لبنان', ['+961']), Country('SY', 'سوريا', ['+963']),
  Country('IQ', 'العراق', ['+964']), Country('PS', 'فلسطين', ['+970', '+972']),
  Country('EG', 'مصر', ['+20']), Country('LY', 'ليبيا', ['+218']),
  Country('TN', 'تونس', ['+216']), Country('DZ', 'الجزائر', ['+213']),
  Country('MA', 'المغرب', ['+212']), Country('MR', 'موريتانيا', ['+222']),
  Country('SD', 'السودان', ['+249']), Country('SO', 'الصومال', ['+252']),
  Country('DJ', 'جيبوتي', ['+253']), Country('KM', 'جزر القمر', ['+269']),
];

Country? countryByCode(String code) {
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}

const grades = [
  'الأول الابتدائي', 'الثاني الابتدائي', 'الثالث الابتدائي',
  'الرابع الابتدائي', 'الخامس الابتدائي', 'السادس الابتدائي',
  'الأول المتوسط', 'الثاني المتوسط', 'الثالث المتوسط',
  'الأول الثانوي', 'الثاني الثانوي', 'الثالث الثانوي',
];
