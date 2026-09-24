import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import '../../platform/permission_service.dart';

/// Copy for the Einstellungen sheet and the hidden Diagnose page.
class SettingsStrings {
  const SettingsStrings(this.l);
  final AppLocale l;

  static SettingsStrings of(BuildContext context) => SettingsStrings(AppLocale.of(context));

  String get title => l.pick(de: 'Einstellungen', en: 'Settings');

  // --- section overlines ---------------------------------------------------
  String get sectionGeneral => l.pick(de: 'Allgemein', en: 'General');
  String get sectionAccount => l.pick(de: 'Konto', en: 'Account');
  String get sectionPermissions => l.pick(de: 'Berechtigungen', en: 'Permissions');
  String get sectionData => l.pick(de: 'Daten', en: 'Data');

  // --- Erscheinungsbild ----------------------------------------------------
  String get appearance => l.pick(de: 'Erscheinungsbild', en: 'Appearance');
  String get appearanceHint => l.pick(de: 'Dunkel liest sich auf dem Berg am besten.', en: 'Dark reads best on the mountain.');
  String get appearanceSystem => l.pick(de: 'System', en: 'System');
  String get appearanceLight => l.pick(de: 'Hell', en: 'Light');
  String get appearanceDark => l.pick(de: 'Dunkel', en: 'Dark');

  String get language => l.pick(de: 'Sprache', en: 'Language');
  String get system => l.pick(de: 'System', en: 'System');
  String get german => 'Deutsch';
  String get english => 'English';
  String get units => l.pick(de: 'Einheiten', en: 'Units');
  String get unitsValue => l.pick(de: 'Folgt der Sprache', en: 'Follows the language');

  // --- Konto ---------------------------------------------------------------
  String get account => l.pick(de: 'Konto', en: 'Account');
  String get accountHint => l.pick(
        de: 'Anmelden, Profil und Bestenlisten.',
        en: 'Sign in, profile and leaderboards.',
      );
  String get comingSoon => l.pick(de: 'Bald verfügbar', en: 'Coming soon');

  String get location => l.pick(de: 'Standortzugriff', en: 'Location access');
  String get locationHint => l.pick(
        de: 'Ohne Standort im Hintergrund bricht die Aufzeichnung im Lift ab.',
        en: 'Without background location the recording stops on the lift.',
      );
  String get openSettings => l.pick(de: 'Einstellungen öffnen', en: 'Open settings');
  String get notifications => l.pick(de: 'Benachrichtigungen', en: 'Notifications');
  String get notificationsHint => l.pick(
        de: 'Erinnerung nach 4 Stunden und Akku-Warnung — sonst nie.',
        en: 'Reminder after 4 hours and a battery warning — nothing else.',
      );
  String get deleteAll => l.pick(de: 'Alle Daten löschen', en: 'Delete all data');
  String get deleteAllHint => l.pick(de: 'Jeder Skitag auf diesem iPhone.', en: 'Every ski day on this iPhone.');
  String get privacy => l.pick(de: 'Datenschutz', en: 'Privacy');
  String get privacyHint => l.pick(de: 'Alles bleibt auf dem Gerät.', en: 'Everything stays on the device.');
  String get version => l.pick(de: 'Version', en: 'Version');
  String get licences => l.pick(de: 'Quellen & Lizenzen', en: 'Sources & licences');
  String get licencesHint => l.pick(de: 'Karten, Wetter, Schrift, Pakete', en: 'Maps, weather, font, packages');
  String get licencesIntro => l.pick(
        de: 'SlopeTrack baut auf offenen Daten und Software auf. Danke an alle, die sie pflegen.',
        en: 'SlopeTrack is built on open data and software. Thanks to everyone who maintains them.',
      );
  String get packageLicences => l.pick(de: 'Alle Paket-Lizenzen', en: 'All package licences');
  String get diagnostics => l.pick(de: 'Diagnose', en: 'Diagnostics');
  String get diagnosticsHint => l.pick(de: 'Sensoren, Zähler und Reparatur.', en: 'Sensors, counters and repair.');
  String get diagnosticsUnlockedToast => l.pick(de: 'Diagnose ist jetzt sichtbar', en: 'Diagnostics is now visible');

  String locationState(LocationPermissionState s) => switch (s) {
        LocationPermissionState.always => l.pick(de: 'Immer', en: 'Always'),
        LocationPermissionState.whileInUse => l.pick(de: 'Beim Verwenden', en: 'While using'),
        LocationPermissionState.denied => l.pick(de: 'Nicht erlaubt', en: 'Not allowed'),
        LocationPermissionState.deniedForever => l.pick(de: 'Abgelehnt', en: 'Denied'),
        LocationPermissionState.unknown => l.pick(de: 'Unbekannt', en: 'Unknown'),
      };

  // --- delete all (two confirmations) -------------------------------------
  String get deleteTitle => l.pick(de: 'Alle Skitage löschen?', en: 'Delete all ski days?');
  String get deleteBody => l.pick(
        de: 'Jeder aufgezeichnete Tag, jede Abfahrt und alle Rekorde verschwinden von diesem iPhone.',
        en: 'Every recorded day, every run and all records disappear from this iPhone.',
      );
  String get deleteConfirmTitle => l.pick(de: 'Wirklich endgültig löschen?', en: 'Really delete for good?');
  String get deleteConfirmBody => l.pick(
        de: 'Das lässt sich nicht rückgängig machen. Es gibt keine Kopie in der Cloud.',
        en: 'This cannot be undone. There is no copy in the cloud.',
      );
  String get deleteConfirm => l.pick(de: 'Endgültig löschen', en: 'Delete for good');
  String get cancel => l.pick(de: 'Abbrechen', en: 'Cancel');
  String get delete => l.pick(de: 'Löschen', en: 'Delete');
  String get deletedToast => l.pick(de: 'Alle Daten gelöscht', en: 'All data deleted');

  // --- notification opt-in -------------------------------------------------
  String get notificationsDenied => l.pick(
        de: 'In den iPhone-Einstellungen erlauben.',
        en: 'Allow this in the iPhone settings.',
      );

  // --- diagnostics ---------------------------------------------------------
  String get diagnosticsCaption => l.pick(de: 'Sensoren und Reparatur', en: 'Sensors and repair');
  String get sectionSensors => l.pick(de: 'Sensoren', en: 'Sensors');
  String get sectionDay => l.pick(de: 'Skitag', en: 'Ski day');
  String get gps => l.pick(de: 'Standort', en: 'Location');
  String get precise => l.pick(de: 'Genauer Standort', en: 'Precise location');
  String get barometer => l.pick(de: 'Barometer', en: 'Barometer');
  String get yes => l.pick(de: 'Ja', en: 'Yes');
  String get no => l.pick(de: 'Nein', en: 'No');
  String get fixesToday => l.pick(de: 'Fixes heute', en: 'Fixes today');
  String get streamRestarts => l.pick(de: 'Stream-Neustarts', en: 'Stream restarts');
  String get selectedDay => l.pick(de: 'Ausgewählter Tag', en: 'Selected day');
  String get pickDay => l.pick(de: 'Tag wählen', en: 'Pick a day');
  String get recompute => l.pick(de: 'Neu berechnen', en: 'Recompute');
  String get recomputed => l.pick(de: 'Neu berechnet', en: 'Recomputed');
  String get shareDiagnostics => l.pick(de: 'Diagnosepaket teilen', en: 'Share diagnostics bundle');
  String get noDays => l.pick(de: 'Noch kein Skitag gespeichert.', en: 'No ski day stored yet.');
  String get noDaysHeadline => l.pick(de: 'Nichts zu diagnostizieren', en: 'Nothing to diagnose');

  /// '1.234 akzeptiert · 12 verworfen'
  String fixes({required String accepted, required String rejected}) =>
      l.pick(de: '$accepted akzeptiert · $rejected verworfen', en: '$accepted accepted · $rejected rejected');
}
