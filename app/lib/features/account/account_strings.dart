import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the Konto sheet (WP-15).
class AccountStrings {
  const AccountStrings(this.l);
  final AppLocale l;

  static AccountStrings of(BuildContext context) => AccountStrings(AppLocale.of(context));

  String get title => l.pick(de: 'Konto', en: 'Account');

  // --- signed out ----------------------------------------------------------
  String get signedOutLine => l.pick(
        de: 'Melde dich an, um deine Skitage zu sichern und dich mit Freunden zu messen.',
        en: 'Sign in to back up your ski days and to measure yourself against friends.',
      );
  String get signInWithApple => l.pick(de: 'Mit Apple anmelden', en: 'Sign in with Apple');
  String get signInFailed => l.pick(
        de: 'Anmeldung hat nicht geklappt. Später nochmal versuchen.',
        en: 'Sign-in did not work. Try again later.',
      );
  String get unavailable => l.pick(
        de: 'Das Konto ist gerade nicht erreichbar. Alles bleibt lokal auf diesem iPhone.',
        en: 'The account is not reachable right now. Everything stays local on this iPhone.',
      );

  // --- profile -------------------------------------------------------------
  String get displayName => l.pick(de: 'Anzeigename', en: 'Display name');
  String get displayNameHint => l.pick(de: 'So erscheinst du in der Rangliste', en: 'How you appear in the Rangliste');
  String get save => l.pick(de: 'Sichern', en: 'Save');
  String get homeResort => l.pick(de: 'Heimatgebiet', en: 'Home resort');
  String get noResort => l.pick(de: 'Nicht gewählt', en: 'Not chosen');
  String get clearResort => l.pick(de: 'Kein Heimatgebiet', en: 'No home resort');
  String get searchResort => l.pick(de: 'Skigebiet suchen', en: 'Search resort');
  String get noResortFound => l.pick(de: 'Kein Skigebiet gefunden.', en: 'No resort found.');
  String get share => l.pick(de: 'In Ranglisten erscheinen', en: 'Appear in Ranglisten');
  String get shareHint => l.pick(
        de: 'Sichtbar sind dein Name und die Tagessummen je Skigebiet — nie deine Strecke.',
        en: 'Visible are your name and the day totals per resort — never your track.',
      );

  // --- sync ----------------------------------------------------------------
  String get syncNow => l.pick(de: 'Jetzt synchronisieren', en: 'Sync now');
  String get syncing => l.pick(de: 'Wird synchronisiert …', en: 'Syncing …');
  String get syncOffline => l.pick(de: 'Offline — wird nachgeholt', en: 'Offline — will catch up');
  String get syncError => l.pick(de: 'Synchronisierung fehlgeschlagen', en: 'Sync failed');
  String get neverSynced => l.pick(de: 'Noch nie synchronisiert', en: 'Never synced');

  /// 'Zuletzt synchronisiert 14:02 · 3 ausstehend'
  String syncLine(String time, int pending) {
    final base = l.pick(de: 'Zuletzt synchronisiert $time', en: 'Last synced $time');
    return pending == 0 ? base : '$base · ${pendingCount(pending)}';
  }

  String pendingCount(int pending) => l.pick(de: '$pending ausstehend', en: '$pending pending');

  // --- sign out / delete ---------------------------------------------------
  String get signOut => l.pick(de: 'Abmelden', en: 'Sign out');
  String get signedOutToast => l.pick(de: 'Abgemeldet', en: 'Signed out');
  String get deleteAccount => l.pick(de: 'Konto löschen', en: 'Delete account');
  String get deleteTitle => l.pick(de: 'Konto löschen?', en: 'Delete account?');
  String get deleteBody => l.pick(
        de: 'Dein Konto und alle Daten auf dem Server verschwinden. Die Skitage auf diesem iPhone bleiben.',
        en: 'Your account and all data on the server disappear. The ski days on this iPhone stay.',
      );
  String get deleteConfirmTitle => l.pick(de: 'Wirklich endgültig löschen?', en: 'Really delete for good?');
  String get deleteConfirmBody => l.pick(
        de: 'Das lässt sich nicht rückgängig machen.',
        en: 'This cannot be undone.',
      );
  String get delete => l.pick(de: 'Löschen', en: 'Delete');
  String get deleteConfirm => l.pick(de: 'Endgültig löschen', en: 'Delete for good');
  String get deletedToast => l.pick(de: 'Konto gelöscht', en: 'Account deleted');
  String get cancel => l.pick(de: 'Abbrechen', en: 'Cancel');
  String get somethingWrong => l.pick(de: 'Hat nicht geklappt. Später nochmal versuchen.', en: 'That did not work. Try again later.');

  // --- row + sections (settings sheet, overlines) ---------------------------
  String get signIn => l.pick(de: 'Anmelden', en: 'Sign in');
  String get sectionProfile => l.pick(de: 'Profil', en: 'Profile');
  String get sectionSync => l.pick(de: 'Synchronisierung', en: 'Sync');
  String get sectionAccount => l.pick(de: 'Konto', en: 'Account');
  String get edit => l.pick(de: 'Ändern', en: 'Edit');
  String get savedToast => l.pick(de: 'Gesichert', en: 'Saved');
  String get syncedToast => l.pick(de: 'Synchronisiert', en: 'Synced');
  String get signedInAs => l.pick(de: 'Angemeldet', en: 'Signed in');
  String get rowHint => l.pick(de: 'Sichern, Ranglisten, Freunde', en: 'Backup, leaderboards, friends');
  String get holdToDelete => l.pick(de: 'Endgültig löschen · halten', en: 'Delete for good · hold');
}
