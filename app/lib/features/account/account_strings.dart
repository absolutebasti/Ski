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
        de: 'Sichtbar sind dein Name, dein Avatar und die Tagessummen je Skigebiet — nie deine Strecke. Die Top 10 sind öffentlich.',
        en: 'Visible are your name, your avatar and the day totals per resort — never your track. The top 10 are public.',
      );

  // --- sync ----------------------------------------------------------------
  String get syncNow => l.pick(de: 'Jetzt synchronisieren', en: 'Sync now');
  String get syncing => l.pick(de: 'Wird synchronisiert …', en: 'Syncing …');
  String get syncOffline => l.pick(de: 'Offline — wird nachgeholt', en: 'Offline — will catch up');
  String get syncError => l.pick(de: 'Synchronisierung fehlgeschlagen', en: 'Sync failed');
  /// Server rate limit (P0005): the outbox resumes by itself — never 'offline'.
  String get syncThrottled => l.pick(de: 'Sync pausiert, geht gleich weiter', en: 'Sync paused, resuming shortly');
  String get reSignIn => l.pick(de: 'Anmeldung abgelaufen – bitte neu mit Apple anmelden', en: 'Session expired – please sign in with Apple again');
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
  /// The delete-account function failed: nothing was deleted, the session stays.
  String get deleteFailed => l.pick(de: 'Löschen hat nicht geklappt, bitte später erneut', en: 'Deleting did not work, please try again later');
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
  /// Caption of the signed-out Konto row — mirrors the page's three benefits.
  String get rowHint => l.pick(de: 'Anmelden – Sichern, Ranglisten, Freunde', en: 'Sign in – backup, leaderboards, friends');
  String get holdToDelete => l.pick(de: 'Endgültig löschen · halten', en: 'Delete for good · hold');

  // --- profile page (PROFILE-PAGE) ------------------------------------------
  String get profileTitle => l.pick(de: 'Konto', en: 'Account');
  String get changePhoto => l.pick(de: 'Foto ändern', en: 'Change photo');
  String get photoUploading => l.pick(de: 'Foto wird hochgeladen …', en: 'Uploading photo …');
  String get photoSaved => l.pick(de: 'Foto gesichert', en: 'Photo saved');
  String get photoFailed => l.pick(de: 'Foto konnte nicht gesichert werden.', en: 'The photo could not be saved.');
  String get photoUnavailable => l.pick(de: 'Fotoauswahl ist auf diesem Gerät nicht verfügbar.', en: 'Photo picking is not available on this device.');
  String get team => l.pick(de: 'Team', en: 'Team');
  String get noTeam => l.pick(de: 'Kein Team', en: 'No team');
  String get changeTeam => l.pick(de: 'Team ändern', en: 'Change team');
  String get teamHint => l.pick(
        de: 'Dein Land in der Länderwertung. Deine Tage zählen ab sofort für das neue Team.',
        en: 'Your country in the country ranking. From now on your days count for the new team.',
      );
  String get teamSaved => l.pick(de: 'Team geändert', en: 'Team changed');
  String get sectionLevel => l.pick(de: 'Level', en: 'Level');
  String get sectionSeason => l.pick(de: 'Saison', en: 'Season');
  String get lifetime => l.pick(de: 'Gesamt', en: 'All time');
  String season(String key) => l.pick(de: 'Saison $key', en: 'Season $key');
  String get days => l.pick(de: 'Tage', en: 'Days');
  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get distance => l.pick(de: 'Ski-km', en: 'Ski km');
  String get topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed');
  String get sectionFriends => l.pick(de: 'Freunde', en: 'Friends');
  String get friendCode => l.pick(de: 'Dein Freundescode', en: 'Your friend code');
  String get friendCodeUnavailable => l.pick(de: 'Gerade nicht verfügbar', en: 'Not available right now');
  String get friends => l.pick(de: 'Freunde', en: 'Friends');
  String get sectionSupport => l.pick(de: 'Hilfe', en: 'Help');
  String get contact => l.pick(de: 'Kontakt', en: 'Contact');
  String get contactHint => l.pick(de: 'Fragen, Fehler, Wünsche — schreib uns.', en: 'Questions, bugs, wishes — write to us.');
  String get mailSubject => l.pick(de: 'SlopeTrack — Feedback', en: 'SlopeTrack — feedback');
  String get medalsOpen => l.pick(de: 'Medaillen', en: 'Medals');

  // --- signed-out page (SETTINGS-ACCOUNT-2) ---------------------------------
  String get sectionBenefits => l.pick(de: 'Mit Konto', en: 'With an account');
  String get benefitBackup => l.pick(de: 'Backup', en: 'Backup');
  String get benefitBackupHint => l.pick(
        de: 'Deine Skitage auf jedem neuen iPhone.',
        en: 'Your ski days on every new iPhone.',
      );
  String get benefitBoards => l.pick(de: 'Ranglisten & Duelle', en: 'Leaderboards & duels');
  String get benefitBoardsHint => l.pick(
        de: 'Je Skigebiet und im Tagesduell.',
        en: 'Per resort and in the day duel.',
      );
  String get benefitFriends => l.pick(de: 'Freunde', en: 'Friends');
  String get benefitFriendsHint => l.pick(
        de: 'Freundescode und eigene Rangliste.',
        en: 'Friend code and your own leaderboard.',
      );
  String get continueWithout => l.pick(de: 'Ohne Konto weiter', en: 'Continue without an account');
  String get deviceLevelHint => l.pick(
        de: 'Level und Medaillen zählen auch ohne Konto – sie bleiben auf diesem iPhone.',
        en: 'Level and medals count without an account – they stay on this iPhone.',
      );

  // --- season goal row -------------------------------------------------------
  String get seasonGoal => l.pick(de: 'Saisonziel', en: 'Season goal');
  String get seasonGoalHint => l.pick(de: 'Höhenmeter bis Saisonende', en: 'Vertical until the end of the season');
  String get seasonGoalNone => l.pick(de: 'Kein Ziel', en: 'No goal');
  String get unitHm => l.pick(de: 'hm', en: 'm');
}
