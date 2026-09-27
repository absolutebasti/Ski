/// Medal and level catalogue (docs/GAMIFICATION.md §2 and §4).
///
/// Thresholds are stored in SI units: metres for vertical and distance,
/// m/s for speeds, plain counts otherwise. Ids are `<metric>-<tier>` and
/// stable (`AchievementMetric.name` + `-` + `MedalTier.name`, e.g. `topSpeed-gold`);
/// they are persisted and used by tests.
library;

import 'achievement_models.dart';

/// One row of the level table: the band starts at [minM] metres of lifetime
/// ski distance.
class LevelDef {
  const LevelDef({required this.index, required this.minM, required this.titleDe, required this.titleEn});
  final int index;
  final double minM;
  final String titleDe;
  final String titleEn;
}

/// Level table by lifetime ski distance, ascending (§2).
const List<LevelDef> levelTable = [
  LevelDef(index: 1, minM: 0, titleDe: 'Rookie', titleEn: 'Rookie'),
  LevelDef(index: 2, minM: 25000, titleDe: 'Einsteiger', titleEn: 'Starter'),
  LevelDef(index: 3, minM: 50000, titleDe: 'Pistenfahrer', titleEn: 'Piste rider'),
  LevelDef(index: 4, minM: 100000, titleDe: 'Carver', titleEn: 'Carver'),
  LevelDef(index: 5, minM: 200000, titleDe: 'Vielfahrer', titleEn: 'Regular'),
  LevelDef(index: 6, minM: 350000, titleDe: 'Allrounder', titleEn: 'All-rounder'),
  LevelDef(index: 7, minM: 500000, titleDe: 'Ausdauerfahrer', titleEn: 'Endurance'),
  LevelDef(index: 8, minM: 750000, titleDe: 'Höhenjäger', titleEn: 'Vert hunter'),
  LevelDef(index: 9, minM: 1000000, titleDe: 'Tausender', titleEn: 'Thousand'),
  LevelDef(index: 10, minM: 1500000, titleDe: 'Veteran', titleEn: 'Veteran'),
  LevelDef(index: 11, minM: 2000000, titleDe: 'Elite', titleEn: 'Elite'),
  LevelDef(index: 12, minM: 3000000, titleDe: 'Pro', titleEn: 'Pro'),
  LevelDef(index: 13, minM: 5000000, titleDe: 'Legende', titleEn: 'Legend'),
  LevelDef(index: 14, minM: 10000000, titleDe: 'Black', titleEn: 'Black'),
];

/// Metrics in catalogue order (the order the Medaillen sheet shows).
const List<AchievementMetric> medalMetricOrder = [
  AchievementMetric.days,
  AchievementMetric.streak,
  AchievementMetric.vertical,
  AchievementMetric.distance,
  AchievementMetric.topSpeed,
  AchievementMetric.avgSpeed,
  AchievementMetric.runs,
  AchievementMetric.dayVertical,
  AchievementMetric.dayRuns,
  AchievementMetric.countries,
  AchievementMetric.resorts,
  AchievementMetric.points,
];

const double _kmh = 1 / 3.6;

/// All 48 medals, 12 metrics × 4 tiers, in [medalMetricOrder] and tier order.
const List<MedalDef> medalCatalog = [
  // days (lifetime)
  MedalDef(id: 'days-bronze', metric: AchievementMetric.days, tier: MedalTier.bronze, threshold: 1,
      titleDe: 'Erster Tag', titleEn: 'First day', hintDe: 'Ein Skitag aufgezeichnet', hintEn: 'One ski day recorded'),
  MedalDef(id: 'days-silver', metric: AchievementMetric.days, tier: MedalTier.silver, threshold: 10,
      titleDe: 'Zehn Tage', titleEn: 'Ten days', hintDe: '10 Skitage', hintEn: '10 ski days'),
  MedalDef(id: 'days-gold', metric: AchievementMetric.days, tier: MedalTier.gold, threshold: 25,
      titleDe: 'Fünfundzwanzig Tage', titleEn: 'Twenty-five days', hintDe: '25 Skitage', hintEn: '25 ski days'),
  MedalDef(id: 'days-black', metric: AchievementMetric.days, tier: MedalTier.black, threshold: 100,
      titleDe: 'Hundert Tage', titleEn: 'Hundred days', hintDe: '100 Skitage', hintEn: '100 ski days'),

  // streak (consecutive calendar days)
  MedalDef(id: 'streak-bronze', metric: AchievementMetric.streak, tier: MedalTier.bronze, threshold: 3,
      titleDe: 'Drei am Stück', titleEn: 'Three straight', hintDe: '3 Skitage in Folge', hintEn: '3 ski days in a row'),
  MedalDef(id: 'streak-silver', metric: AchievementMetric.streak, tier: MedalTier.silver, threshold: 5,
      titleDe: 'Fünf am Stück', titleEn: 'Five straight', hintDe: '5 Skitage in Folge', hintEn: '5 ski days in a row'),
  MedalDef(id: 'streak-gold', metric: AchievementMetric.streak, tier: MedalTier.gold, threshold: 7,
      titleDe: 'Sieben am Stück', titleEn: 'Seven straight', hintDe: '7 Skitage in Folge', hintEn: '7 ski days in a row'),
  MedalDef(id: 'streak-black', metric: AchievementMetric.streak, tier: MedalTier.black, threshold: 14,
      titleDe: 'Zwei Wochen', titleEn: 'Two weeks', hintDe: '14 Skitage in Folge', hintEn: '14 ski days in a row'),

  // vertical (lifetime metres of drop; the rulebook's 'hm' = Höhenmeter)
  MedalDef(id: 'vertical-bronze', metric: AchievementMetric.vertical, tier: MedalTier.bronze, threshold: 10000,
      titleDe: 'Zehntausend', titleEn: 'Ten thousand', hintDe: '10.000 Höhenmeter', hintEn: '10,000 m of vertical'),
  MedalDef(id: 'vertical-silver', metric: AchievementMetric.vertical, tier: MedalTier.silver, threshold: 50000,
      titleDe: 'Fünfzigtausend', titleEn: 'Fifty thousand', hintDe: '50.000 Höhenmeter', hintEn: '50,000 m of vertical'),
  MedalDef(id: 'vertical-gold', metric: AchievementMetric.vertical, tier: MedalTier.gold, threshold: 100000,
      titleDe: 'Hunderttausend', titleEn: 'Hundred thousand', hintDe: '100.000 Höhenmeter', hintEn: '100,000 m of vertical'),
  MedalDef(id: 'vertical-black', metric: AchievementMetric.vertical, tier: MedalTier.black, threshold: 500000,
      titleDe: 'Halbe Million', titleEn: 'Half a million', hintDe: '500.000 Höhenmeter', hintEn: '500,000 m of vertical'),

  // distance (lifetime metres)
  MedalDef(id: 'distance-bronze', metric: AchievementMetric.distance, tier: MedalTier.bronze, threshold: 100000,
      titleDe: 'Hundert Kilometer', titleEn: 'Hundred kilometres', hintDe: '100 km auf Ski', hintEn: '100 km on skis'),
  MedalDef(id: 'distance-silver', metric: AchievementMetric.distance, tier: MedalTier.silver, threshold: 500000,
      titleDe: 'Fünfhundert Kilometer', titleEn: 'Five hundred kilometres', hintDe: '500 km auf Ski', hintEn: '500 km on skis'),
  MedalDef(id: 'distance-gold', metric: AchievementMetric.distance, tier: MedalTier.gold, threshold: 1000000,
      titleDe: 'Tausend Kilometer', titleEn: 'Thousand kilometres', hintDe: '1.000 km auf Ski', hintEn: '1,000 km on skis'),
  MedalDef(id: 'distance-black', metric: AchievementMetric.distance, tier: MedalTier.black, threshold: 5000000,
      titleDe: 'Fünftausend Kilometer', titleEn: 'Five thousand kilometres', hintDe: '5.000 km auf Ski', hintEn: '5,000 km on skis'),

  // top speed (single non-suspicious day, m/s)
  MedalDef(id: 'topSpeed-bronze', metric: AchievementMetric.topSpeed, tier: MedalTier.bronze, threshold: 60 * _kmh,
      titleDe: 'Sechzig', titleEn: 'Sixty', hintDe: '60 km/h an einem Tag', hintEn: '60 km/h in a single day'),
  MedalDef(id: 'topSpeed-silver', metric: AchievementMetric.topSpeed, tier: MedalTier.silver, threshold: 80 * _kmh,
      titleDe: 'Achtzig', titleEn: 'Eighty', hintDe: '80 km/h an einem Tag', hintEn: '80 km/h in a single day'),
  MedalDef(id: 'topSpeed-gold', metric: AchievementMetric.topSpeed, tier: MedalTier.gold, threshold: 100 * _kmh,
      titleDe: 'Hundert', titleEn: 'Hundred', hintDe: '100 km/h an einem Tag', hintEn: '100 km/h in a single day'),
  MedalDef(id: 'topSpeed-black', metric: AchievementMetric.topSpeed, tier: MedalTier.black, threshold: 120 * _kmh,
      titleDe: 'Hundertzwanzig', titleEn: 'One-twenty', hintDe: '120 km/h an einem Tag', hintEn: '120 km/h in a single day'),

  // average ski speed (lifetime, m/s)
  MedalDef(id: 'avgSpeed-bronze', metric: AchievementMetric.avgSpeed, tier: MedalTier.bronze, threshold: 25 * _kmh,
      titleDe: 'Gleichmäßig', titleEn: 'Steady', hintDe: 'Ø 25 km/h auf der Piste', hintEn: '25 km/h average on skis'),
  MedalDef(id: 'avgSpeed-silver', metric: AchievementMetric.avgSpeed, tier: MedalTier.silver, threshold: 35 * _kmh,
      titleDe: 'Zügig', titleEn: 'Brisk', hintDe: 'Ø 35 km/h auf der Piste', hintEn: '35 km/h average on skis'),
  MedalDef(id: 'avgSpeed-gold', metric: AchievementMetric.avgSpeed, tier: MedalTier.gold, threshold: 45 * _kmh,
      titleDe: 'Schnell', titleEn: 'Fast', hintDe: 'Ø 45 km/h auf der Piste', hintEn: '45 km/h average on skis'),
  MedalDef(id: 'avgSpeed-black', metric: AchievementMetric.avgSpeed, tier: MedalTier.black, threshold: 55 * _kmh,
      titleDe: 'Rennlinie', titleEn: 'Race line', hintDe: 'Ø 55 km/h auf der Piste', hintEn: '55 km/h average on skis'),

  // runs (lifetime)
  MedalDef(id: 'runs-bronze', metric: AchievementMetric.runs, tier: MedalTier.bronze, threshold: 50,
      titleDe: 'Fünfzig Abfahrten', titleEn: 'Fifty runs', hintDe: '50 Abfahrten insgesamt', hintEn: '50 runs in total'),
  MedalDef(id: 'runs-silver', metric: AchievementMetric.runs, tier: MedalTier.silver, threshold: 250,
      titleDe: 'Zweihundertfünfzig', titleEn: 'Two-fifty', hintDe: '250 Abfahrten insgesamt', hintEn: '250 runs in total'),
  MedalDef(id: 'runs-gold', metric: AchievementMetric.runs, tier: MedalTier.gold, threshold: 1000,
      titleDe: 'Tausend Abfahrten', titleEn: 'Thousand runs', hintDe: '1.000 Abfahrten insgesamt', hintEn: '1,000 runs in total'),
  MedalDef(id: 'runs-black', metric: AchievementMetric.runs, tier: MedalTier.black, threshold: 5000,
      titleDe: 'Fünftausend Abfahrten', titleEn: 'Five thousand runs', hintDe: '5.000 Abfahrten insgesamt', hintEn: '5,000 runs in total'),

  // day vertical (single non-suspicious day, metres)
  MedalDef(id: 'dayVertical-bronze', metric: AchievementMetric.dayVertical, tier: MedalTier.bronze, threshold: 2000,
      titleDe: 'Zweitausender', titleEn: 'Two-thousand day', hintDe: '2.000 hm an einem Tag', hintEn: '2,000 m of vertical in one day'),
  MedalDef(id: 'dayVertical-silver', metric: AchievementMetric.dayVertical, tier: MedalTier.silver, threshold: 3000,
      titleDe: 'Dreitausender', titleEn: 'Three-thousand day', hintDe: '3.000 hm an einem Tag', hintEn: '3,000 m of vertical in one day'),
  MedalDef(id: 'dayVertical-gold', metric: AchievementMetric.dayVertical, tier: MedalTier.gold, threshold: 4000,
      titleDe: 'Viertausender', titleEn: 'Four-thousand day', hintDe: '4.000 hm an einem Tag', hintEn: '4,000 m of vertical in one day'),
  MedalDef(id: 'dayVertical-black', metric: AchievementMetric.dayVertical, tier: MedalTier.black, threshold: 6000,
      titleDe: 'Sechstausender', titleEn: 'Six-thousand day', hintDe: '6.000 hm an einem Tag', hintEn: '6,000 m of vertical in one day'),

  // day runs (single non-suspicious day)
  MedalDef(id: 'dayRuns-bronze', metric: AchievementMetric.dayRuns, tier: MedalTier.bronze, threshold: 10,
      titleDe: 'Zehn Abfahrten', titleEn: 'Ten runs', hintDe: '10 Abfahrten an einem Tag', hintEn: '10 runs in one day'),
  MedalDef(id: 'dayRuns-silver', metric: AchievementMetric.dayRuns, tier: MedalTier.silver, threshold: 20,
      titleDe: 'Zwanzig Abfahrten', titleEn: 'Twenty runs', hintDe: '20 Abfahrten an einem Tag', hintEn: '20 runs in one day'),
  MedalDef(id: 'dayRuns-gold', metric: AchievementMetric.dayRuns, tier: MedalTier.gold, threshold: 30,
      titleDe: 'Dreißig Abfahrten', titleEn: 'Thirty runs', hintDe: '30 Abfahrten an einem Tag', hintEn: '30 runs in one day'),
  MedalDef(id: 'dayRuns-black', metric: AchievementMetric.dayRuns, tier: MedalTier.black, threshold: 40,
      titleDe: 'Vierzig Abfahrten', titleEn: 'Forty runs', hintDe: '40 Abfahrten an einem Tag', hintEn: '40 runs in one day'),

  // countries (distinct)
  MedalDef(id: 'countries-bronze', metric: AchievementMetric.countries, tier: MedalTier.bronze, threshold: 2,
      titleDe: 'Grenzgänger', titleEn: 'Border crosser', hintDe: 'Ski in 2 Ländern', hintEn: 'Skied in 2 countries'),
  MedalDef(id: 'countries-silver', metric: AchievementMetric.countries, tier: MedalTier.silver, threshold: 3,
      titleDe: 'Drei Länder', titleEn: 'Three countries', hintDe: 'Ski in 3 Ländern', hintEn: 'Skied in 3 countries'),
  MedalDef(id: 'countries-gold', metric: AchievementMetric.countries, tier: MedalTier.gold, threshold: 4,
      titleDe: 'Vier Länder', titleEn: 'Four countries', hintDe: 'Ski in 4 Ländern', hintEn: 'Skied in 4 countries'),
  MedalDef(id: 'countries-black', metric: AchievementMetric.countries, tier: MedalTier.black, threshold: 5,
      titleDe: 'Fünf Länder', titleEn: 'Five countries', hintDe: 'Ski in 5 Ländern', hintEn: 'Skied in 5 countries'),

  // resorts (distinct)
  MedalDef(id: 'resorts-bronze', metric: AchievementMetric.resorts, tier: MedalTier.bronze, threshold: 3,
      titleDe: 'Drei Gebiete', titleEn: 'Three resorts', hintDe: 'Ski in 3 Skigebieten', hintEn: 'Skied in 3 resorts'),
  MedalDef(id: 'resorts-silver', metric: AchievementMetric.resorts, tier: MedalTier.silver, threshold: 10,
      titleDe: 'Zehn Gebiete', titleEn: 'Ten resorts', hintDe: 'Ski in 10 Skigebieten', hintEn: 'Skied in 10 resorts'),
  MedalDef(id: 'resorts-gold', metric: AchievementMetric.resorts, tier: MedalTier.gold, threshold: 25,
      titleDe: 'Fünfundzwanzig Gebiete', titleEn: 'Twenty-five resorts', hintDe: 'Ski in 25 Skigebieten', hintEn: 'Skied in 25 resorts'),
  MedalDef(id: 'resorts-black', metric: AchievementMetric.resorts, tier: MedalTier.black, threshold: 50,
      titleDe: 'Fünfzig Gebiete', titleEn: 'Fifty resorts', hintDe: 'Ski in 50 Skigebieten', hintEn: 'Skied in 50 resorts'),

  // points (lifetime)
  MedalDef(id: 'points-bronze', metric: AchievementMetric.points, tier: MedalTier.bronze, threshold: 1000,
      titleDe: 'Tausend Punkte', titleEn: 'Thousand points', hintDe: '1.000 Punkte insgesamt', hintEn: '1,000 points in total'),
  MedalDef(id: 'points-silver', metric: AchievementMetric.points, tier: MedalTier.silver, threshold: 5000,
      titleDe: 'Fünftausend Punkte', titleEn: 'Five thousand points', hintDe: '5.000 Punkte insgesamt', hintEn: '5,000 points in total'),
  MedalDef(id: 'points-gold', metric: AchievementMetric.points, tier: MedalTier.gold, threshold: 20000,
      titleDe: 'Zwanzigtausend Punkte', titleEn: 'Twenty thousand points', hintDe: '20.000 Punkte insgesamt', hintEn: '20,000 points in total'),
  MedalDef(id: 'points-black', metric: AchievementMetric.points, tier: MedalTier.black, threshold: 100000,
      titleDe: 'Hunderttausend Punkte', titleEn: 'Hundred thousand points', hintDe: '100.000 Punkte insgesamt', hintEn: '100,000 points in total'),
];

final Map<String, MedalDef> _byId = {for (final m in medalCatalog) m.id: m};

/// Medal definition by id, or null for an unknown id.
MedalDef? medalById(String id) => _byId[id];

/// The four medals of one metric, bronze → black.
List<MedalDef> medalsOf(AchievementMetric metric) => medalCatalog.where((m) => m.metric == metric).toList();
