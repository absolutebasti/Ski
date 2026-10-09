import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import 'recording_access.dart';

/// Notification copy (no BuildContext in the controller → picked by settings locale).
class RecordingStrings {
  const RecordingStrings(this.de);
  final bool de;
  static RecordingStrings forLocale(String setting, String deviceLang) =>
      RecordingStrings(setting == 'de' || (setting != 'en' && deviceLang == 'de'));
  static RecordingStrings of(BuildContext context) => RecordingStrings(AppLocale.of(context).isGerman);

  String get idleTitle => de ? 'Noch am Fahren?' : 'Still skiing?';
  String get idleBody => de ? 'Seit 90 Minuten keine Abfahrt. Tippe, um den Tag zu beenden.' : 'No run for 90 minutes. Tap to end the day.';
  String get autoEndTitle => de ? 'Skitag beendet' : 'Ski day ended';
  String get autoEndIdleBody => de ? 'Nach 3 Stunden Pause haben wir den Tag für dich gespeichert.' : 'Saved after 3 hours of rest.';
  String get autoEndVehicleBody => de ? 'Sieht nach Autofahrt aus – der Tag wurde gespeichert.' : 'Looks like a car ride – your day was saved.';
  String get autoEndLongBody => de ? 'Der Tag lief sehr lange und wurde gespeichert.' : 'The day ran very long and was saved.';
  String get fourHoursTitle => de ? 'Aufnahme läuft seit 4 Stunden' : 'Recording for 4 hours';
  String get fourHoursBody => de ? 'Alles gut? Beenden kannst du jederzeit in der App.' : 'All good? You can end the day in the app any time.';
  String get batteryTitle => de ? 'Akku bei 15 %' : 'Battery at 15 %';
  String get batteryBody => de ? 'Die Aufnahme läuft weiter, wird aber beim Ausschalten gespeichert.' : 'Recording continues; everything is saved if the phone dies.';

  // --- access lost mid-day --------------------------------------------------
  String get accessLostTitle => de ? 'Kein Zugriff auf den Standort' : 'No location access';
  String accessLostBody(TrackingAccess a) => switch (a) {
        TrackingAccess.serviceOff => de ? 'Ortungsdienste sind aus. Ohne GPS wird nichts aufgezeichnet.' : 'Location services are off. Nothing is recorded without GPS.',
        TrackingAccess.permissionDenied => de ? 'Die Standortfreigabe wurde entzogen. Ohne GPS wird nichts aufgezeichnet.' : 'Location permission was revoked. Nothing is recorded without GPS.',
        TrackingAccess.ok => '',
      };
  String get autoEndNoAccessBody => de ? '30 Minuten ohne Standortzugriff – der Tag wurde gespeichert.' : '30 minutes without location access – your day was saved.';

  /// Live-view chip while access is lost.
  String accessChip(TrackingAccess a) => switch (a) {
        TrackingAccess.serviceOff => de ? 'Kein Zugriff – Ortung aus' : 'No access – location off',
        TrackingAccess.permissionDenied => de ? 'Kein Zugriff – Freigabe entzogen' : 'No access – permission revoked',
        TrackingAccess.ok => '',
      };

  // --- one-line hints at Start ----------------------------------------------
  String get gpsAltitudeBadge => de ? 'GPS-Höhe' : 'GPS altitude';
  String hint(RecordingHint h) => switch (h) {
        RecordingHint.motionDenied => de ? 'Ohne Bewegung & Fitness kommt die Höhe nur vom GPS – Höhenmeter werden ungenauer.' : 'Without Motion & Fitness altitude comes from GPS only – vertical gets less precise.',
        RecordingHint.lowPowerMode => de ? 'Stromsparmodus ist an – GPS kann seltener liefern.' : 'Low Power Mode is on – GPS may report less often.',
      };
}
