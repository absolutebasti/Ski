/// Notification copy (no BuildContext in the controller → picked by settings locale).
class RecordingStrings {
  const RecordingStrings(this.de);
  final bool de;
  static RecordingStrings forLocale(String setting, String deviceLang) =>
      RecordingStrings(setting == 'de' || (setting != 'en' && deviceLang != 'en'));

  String get idleTitle => de ? 'Noch am Fahren?' : 'Still skiing?';
  String get idleBody => de ? 'Seit 90 Minuten keine Abfahrt. Tippe, um den Tag zu beenden.' : 'No run for 90 minutes. Tap to end the day.';
  String get autoEndTitle => de ? 'Skitag beendet' : 'Ski day ended';
  String get autoEndIdleBody => de ? 'Nach 3 Stunden Pause haben wir den Tag für dich gespeichert.' : 'Saved after 3 hours of rest.';
  String get autoEndVehicleBody => de ? 'Sieht nach Autofahrt aus – der Tag wurde gespeichert.' : 'Looks like a car ride – your day was saved.';
  String get fourHoursTitle => de ? 'Aufnahme läuft seit 4 Stunden' : 'Recording for 4 hours';
  String get fourHoursBody => de ? 'Alles gut? Beenden kannst du jederzeit in der App.' : 'All good? You can end the day in the app any time.';
  String get batteryTitle => de ? 'Akku bei 15 %' : 'Battery at 15 %';
  String get batteryBody => de ? 'Die Aufnahme läuft weiter, wird aber beim Ausschalten gespeichert.' : 'Recording continues; everything is saved if the phone dies.';
}
