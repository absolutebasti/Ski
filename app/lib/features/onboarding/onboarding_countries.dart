import '../../app/l10n/app_locale.dart';

/// A country the user can ride for (docs/GAMIFICATION.md §5 "Team = country").
class TeamCountry {
  const TeamCountry(this.code, {required this.de, required this.en});

  /// ISO-3166 alpha-2, upper case.
  final String code;
  final String de;
  final String en;

  String name(AppLocale l) => l.pick(de: de, en: en);

  /// Regional-indicator pair, e.g. 'AT' → 🇦🇹.
  String get flag => flagEmoji(code);
}

/// Two regional-indicator symbols for an alpha-2 code.
String flagEmoji(String code) {
  final c = code.toUpperCase();
  if (c.length != 2) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + (u - 0x41)));
}

/// The five tiles on the Team page. 'Anderes' is the sixth tile and opens [kOtherCountries].
const kTeamCountries = [
  TeamCountry('AT', de: 'Österreich', en: 'Austria'),
  TeamCountry('CH', de: 'Schweiz', en: 'Switzerland'),
  TeamCountry('DE', de: 'Deutschland', en: 'Germany'),
  TeamCountry('IT', de: 'Italien', en: 'Italy'),
  TeamCountry('FR', de: 'Frankreich', en: 'France'),
];

/// Skiing countries behind 'Anderes'; the sheet sorts them by localised name.
const kOtherCountries = [
  TeamCountry('NO', de: 'Norwegen', en: 'Norway'),
  TeamCountry('SE', de: 'Schweden', en: 'Sweden'),
  TeamCountry('FI', de: 'Finnland', en: 'Finland'),
  TeamCountry('DK', de: 'Dänemark', en: 'Denmark'),
  TeamCountry('IS', de: 'Island', en: 'Iceland'),
  TeamCountry('GB', de: 'Großbritannien', en: 'United Kingdom'),
  TeamCountry('IE', de: 'Irland', en: 'Ireland'),
  TeamCountry('NL', de: 'Niederlande', en: 'Netherlands'),
  TeamCountry('BE', de: 'Belgien', en: 'Belgium'),
  TeamCountry('LU', de: 'Luxemburg', en: 'Luxembourg'),
  TeamCountry('LI', de: 'Liechtenstein', en: 'Liechtenstein'),
  TeamCountry('ES', de: 'Spanien', en: 'Spain'),
  TeamCountry('AD', de: 'Andorra', en: 'Andorra'),
  TeamCountry('PT', de: 'Portugal', en: 'Portugal'),
  TeamCountry('PL', de: 'Polen', en: 'Poland'),
  TeamCountry('CZ', de: 'Tschechien', en: 'Czechia'),
  TeamCountry('SK', de: 'Slowakei', en: 'Slovakia'),
  TeamCountry('SI', de: 'Slowenien', en: 'Slovenia'),
  TeamCountry('HR', de: 'Kroatien', en: 'Croatia'),
  TeamCountry('RO', de: 'Rumänien', en: 'Romania'),
  TeamCountry('BG', de: 'Bulgarien', en: 'Bulgaria'),
  TeamCountry('GR', de: 'Griechenland', en: 'Greece'),
  TeamCountry('TR', de: 'Türkei', en: 'Türkiye'),
  TeamCountry('GE', de: 'Georgien', en: 'Georgia'),
  TeamCountry('US', de: 'USA', en: 'United States'),
  TeamCountry('CA', de: 'Kanada', en: 'Canada'),
  TeamCountry('CL', de: 'Chile', en: 'Chile'),
  TeamCountry('AR', de: 'Argentinien', en: 'Argentina'),
  TeamCountry('JP', de: 'Japan', en: 'Japan'),
  TeamCountry('KR', de: 'Südkorea', en: 'South Korea'),
  TeamCountry('CN', de: 'China', en: 'China'),
  TeamCountry('IN', de: 'Indien', en: 'India'),
  TeamCountry('AU', de: 'Australien', en: 'Australia'),
  TeamCountry('NZ', de: 'Neuseeland', en: 'New Zealand'),
];

/// Any known country by code (grid first, then the sheet list); null if unknown.
TeamCountry? teamCountry(String? code) {
  if (code == null) return null;
  final c = code.toUpperCase();
  for (final k in kTeamCountries) {
    if (k.code == c) return k;
  }
  for (final k in kOtherCountries) {
    if (k.code == c) return k;
  }
  return null;
}

/// True when [code] is one of the five grid tiles.
bool isGridCountry(String? code) => code != null && kTeamCountries.any((k) => k.code == code.toUpperCase());
