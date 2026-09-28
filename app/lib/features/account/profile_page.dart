import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../core/settings.dart';
import '../../data/db/providers.dart';
import '../../data/sync/auth_service.dart';
import '../achievements/achievements_providers.dart';
import '../achievements/achievements_strings.dart';
import '../achievements/ui/level_ring.dart';
import '../achievements/ui/medals_sheet.dart';
import '../achievements/ui/streak_chip.dart';
import '../onboarding/onboarding_countries.dart';
import '../social/country_card.dart';
import '../social/friends/friends_providers.dart';
import '../social/friends/friends_sheet.dart';
import '../social/moderation/display_name_policy.dart';
import '../social/moderation/name_rules.dart';
import '../social/social_controls.dart';
import 'account_providers.dart';
import 'account_strings.dart';
import 'account_widgets.dart';
import 'avatar_picker.dart';
import 'country_picker_sheet.dart';
import 'profile_service.dart';
import 'resort_picker.dart';

/// Eigenes Profil (PROFILE-PAGE): avatar, name, team, home resort, level and
/// medals, season and lifetime numbers, friend code, opt-in, sync, support,
/// sign out / delete. Signed out it shows the Apple button. Opened from the
/// Einstellungen 'Konto' row via [ProfilePage.open].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<void>(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));

  @override
  Widget build(BuildContext context) {
    final s = AccountStrings.of(context);
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 40),
            children: [
              ScreenHeader(
                title: s.profileTitle,
                leading: HeaderButton(
                  glyph: Glyph.back,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const ProfilePageBody(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page content without the scaffold; exposed for tests.
class ProfilePageBody extends ConsumerStatefulWidget {
  const ProfilePageBody({super.key});

  @override
  ConsumerState<ProfilePageBody> createState() => _ProfilePageBodyState();
}

class _ProfilePageBodyState extends ConsumerState<ProfilePageBody> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  /// Name the field was seeded with; a differing text shows 'Sichern'.
  String _seededName = '';
  String? _nameHint;
  bool _busy = false;
  bool _uploading = false;
  bool _signInFailed = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  ProfileService get _service => ref.read(profileServiceProvider);

  bool get _nameDirty => _name.text != _seededName;

  // ---------------------------------------------------------------- actions

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _signInFailed = false;
    });
    final ok = await accountSignIn(ref);
    if (mounted) {
      setState(() {
        _busy = false;
        _signInFailed = !ok;
      });
    }
  }

  Future<void> _saveName() async {
    final raw = _name.text;
    final hint = DisplayNamePolicy.validate(raw, locale: AppLocale.of(context));
    if (hint != null) {
      setState(() => _nameHint = hint);
      return;
    }
    final name = DisplayNamePolicy.normalized(raw)!;
    setState(() {
      _nameHint = null;
      _seededName = name;
      _name.text = name;
    });
    _nameFocus.unfocus();
    await _service.update(displayName: name);
    if (!mounted) return;
    showToast(context, AccountStrings.of(context).savedToast, icon: Icons.check_rounded);
  }

  void _resetName() {
    setState(() {
      _name.text = _seededName;
      _nameHint = null;
    });
    _nameFocus.unfocus();
  }

  Future<void> _pickAvatar() async {
    if (_uploading) return;
    final s = AccountStrings.of(context);
    final picker = ref.read(avatarPickerProvider);
    if (picker == null) {
      showToast(context, s.photoUnavailable);
      return;
    }
    final PickedAvatar? picked;
    try {
      picked = await picker.pick();
    } catch (_) {
      if (mounted) showToast(context, s.photoFailed);
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    final ok = await _service.setAvatar(picked);
    if (!mounted) return;
    setState(() => _uploading = false);
    showToast(context, ok ? s.photoSaved : s.photoFailed, icon: ok ? Icons.check_rounded : null);
  }

  Future<void> _changeTeam(String? current) async {
    final code = await CountryPickerSheet.show(context, selected: current);
    if (code == null || code == current || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    await ref.read(settingsProvider.notifier).setCountry(code);
    await _service.pushCountry(code);
    if (!mounted) return;
    showToast(context, AccountStrings.of(context).teamSaved, icon: Icons.check_rounded);
  }

  Future<void> _pickResort(String? current) async {
    final choice = await ResortPicker.show(context, selectedId: current);
    if (choice == null) return;
    await _service.update(homeResortId: choice.resortId);
    if (choice.resortId != null) {
      await ref.read(settingsProvider.notifier).setLastResort(choice.resortId);
    }
  }

  Future<void> _contact() async {
    final s = AccountStrings.of(context);
    final uri = Uri(scheme: 'mailto', path: kSupportEmail, queryParameters: {'subject': s.mailSubject});
    try {
      await ref.read(accountOpenUriProvider)(uri);
    } catch (_) {
      if (mounted) showToast(context, s.somethingWrong);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await accountSignOut(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(context, AccountStrings.of(context).signedOutToast);
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final s = AccountStrings.of(context);
    setState(() => _busy = true);
    final result = await accountDeleteWithConfirm(context, ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    showToast(context, result ? s.deletedToast : s.somethingWrong);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final user = watchAuthUser(ref);
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AccountSignedOutBody(
          onSignIn: _busy ? null : _signIn,
          failed: _signInFailed,
          available: ref.watch(accountAvailableProvider),
        ),
      );
    }
    return _buildSignedIn(context, user);
  }

  Widget _buildSignedIn(BuildContext context, AuthUser user) {
    final s = AccountStrings.of(context);
    final profile = ref.watch(profileProvider).value;
    final name = profile?.displayName ?? user.displayName;
    if (!_nameFocus.hasFocus && !_nameDirty && _seededName != name) {
      // Seed (or follow a remote change) while the user is not typing.
      _seededName = name;
      _name.value = TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length));
    }
    final country = Profile.normaliseCountry(ref.watch(settingsProvider.select((st) => st.countryCode))) ?? profile?.countryCode;
    return Column(
      key: const ValueKey('profile-signed-in'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderCard(
          name: name,
          avatarUrl: profile?.avatarUrl,
          uploading: _uploading,
          onAvatar: _pickAvatar,
          field: _nameField(context),
          country: country,
          onTeam: () => _changeTeam(country),
        ),
        accountCardGap,
        HomeResortCard(resortId: profile?.homeResortId, onTap: () => _pickResort(profile?.homeResortId)),
        AccountSection(s.sectionLevel),
        const _LevelCard(),
        AccountSection(s.sectionSeason),
        const _NumbersCard(),
        AccountSection(s.sectionFriends),
        _FriendCodeCard(onFriends: () => FriendsSheet.show(context)),
        accountCardGap,
        ShareOptInCard(
          value: profile?.shareLeaderboards ?? false,
          onChanged: profile == null ? null : (on) => _service.update(shareLeaderboards: on),
        ),
        AccountSection(s.sectionSync),
        const SyncCard(),
        AccountSection(s.sectionSupport),
        _ContactCard(onTap: _contact),
        AccountSection(s.sectionAccount),
        AccountDangerActions(onSignOut: _busy ? null : _signOut, onDelete: _busy ? null : _deleteAccount),
      ],
    );
  }

  Widget _nameField(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.displayName.overline, style: AppText.label(c.textTertiary)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('profile-name-field'),
                controller: _name,
                focusNode: _nameFocus,
                maxLength: NameRules.maxLength,
                inputFormatters: [LengthLimitingTextInputFormatter(NameRules.maxLength)],
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_nameHint != null) setState(() => _nameHint = null);
                },
                onSubmitted: (_) => _saveName(),
                style: AppText.title(c.textPrimary),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: s.displayNameHint,
                  hintStyle: AppText.bodyText(c.textTertiary, size: 15),
                ),
              ),
            ),
            if (_nameDirty) ...[
              const SizedBox(width: 8),
              SecondaryButton(key: const ValueKey('profile-name-cancel'), label: s.cancel, height: 36, onPressed: _resetName),
              const SizedBox(width: 8),
              SecondaryButton(key: const ValueKey('profile-name-save'), label: s.save, height: 36, onPressed: _saveName),
            ],
          ],
        ),
        if (_nameHint != null) ...[
          const SizedBox(height: 6),
          Text(_nameHint!, key: const ValueKey('profile-name-hint'), style: AppText.caption(c.danger)),
        ] else ...[
          const SizedBox(height: 4),
          Text('${NameRules.length(_name.text)} / ${NameRules.maxLength}', style: AppText.caption(c.textTertiary, size: 12)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- header

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.avatarUrl,
    required this.uploading,
    required this.onAvatar,
    required this.field,
    required this.country,
    required this.onTeam,
  });

  final String name;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onAvatar;
  final Widget field;
  final String? country;
  final VoidCallback onTeam;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AccountStrings.of(context);
    final team = teamCountry(country);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: s.changePhoto,
                child: Pressable(
                  key: const ValueKey('profile-avatar'),
                  onTap: uploading ? null : onAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarCircle(name: name, avatarUrl: avatarUrl, size: 88, ring: true),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                          child: uploading
                              ? Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: c.onAccent),
                                )
                              : Icon(Icons.photo_camera_rounded, size: 16, color: c.onAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: field),
            ],
          ),
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 14),
          Row(
            children: [
              if (country != null)
                CountryFlag(countryCode: country!, size: 36, ring: true)
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.surfaceRaised, shape: BoxShape.circle, border: Border.all(color: c.hairline, width: c.hairlineWidth)),
                  child: Icon(Icons.flag_outlined, size: 18, color: c.textTertiary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.team.overline, style: AppText.label(c.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      team?.name(l) ?? (country ?? s.noTeam),
                      key: const ValueKey('profile-team-name'),
                      style: AppText.title(country == null ? c.textSecondary : c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SecondaryButton(key: const ValueKey('profile-team-change'), label: s.changeTeam, height: 40, onPressed: onTeam),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- level

/// Level ring, level line, points, streak chip and the medal count; the card
/// opens the Medaillen sheet.
class _LevelCard extends ConsumerWidget {
  const _LevelCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(achievementsProvider);
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AchievementsStrings.of(context);
    final nextAt = a.level.nextAtM;
    final nextLine = nextAt == null ? s.topLevel : s.nextLevelShort((nextAt - a.level.distanceM).clamp(0, double.infinity), a.level.index + 1);
    return Semantics(
      label: s.openMedals,
      child: AppCard(
        onTap: () => MedalsSheet.show(context),
        child: Row(
          key: const ValueKey('profile-level'),
          children: [
            LevelRing(level: a.level, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.levelLine(a.level).overline, style: AppText.label(c.textSecondary)),
                  const SizedBox(height: 4),
                  Text(nextLine, style: AppText.caption(c.textSecondary, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.metres(a.points.toDouble(), locale: l.code), style: AppText.numS(c.accent)),
                      const SizedBox(width: 6),
                      Text(s.points, style: AppText.unit(c.textTertiary, size: 12)),
                      const Spacer(),
                      StreakChip(streak: a.streak, compact: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.medalCount(a.earned.length, a.medals.length), key: const ValueKey('profile-medals'), style: AppText.bodyStrong(c.textPrimary, size: 15)),
                      ),
                      GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- numbers

/// Current season (from the day totals) above the lifetime row (from the
/// achievements snapshot): Tage · Höhenmeter · Ski-km · Top-Speed.
class _NumbersCard extends ConsumerWidget {
  const _NumbersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AccountStrings.of(context);
    final a = ref.watch(achievementsProvider);
    final key = seasonKey(DateTime.now());
    final seasons = ref.watch(seasonTotalsProvider).value ?? const <SeasonTotals>[];
    final season = seasons.where((t) => t.seasonKey == key).firstOrNull ?? SeasonTotals(seasonKey: key);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.season(key).overline, style: AppText.label(c.textSecondary)),
          const SizedBox(height: 10),
          _StatRow(
            key: const ValueKey('profile-season'),
            days: season.dayCount,
            dropM: season.dropM,
            distanceM: season.skiDistanceM,
            topSpeedMs: season.maxSpeedMs,
            locale: l.code,
            accent: true,
          ),
          const SizedBox(height: 14),
          const Hairline(),
          const SizedBox(height: 12),
          Text(s.lifetime.overline, style: AppText.label(c.textTertiary)),
          const SizedBox(height: 10),
          _StatRow(
            key: const ValueKey('profile-lifetime'),
            days: a.dayCount,
            dropM: a.dropM,
            distanceM: a.distanceM,
            topSpeedMs: a.topSpeedMs,
            locale: l.code,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    super.key,
    required this.days,
    required this.dropM,
    required this.distanceM,
    required this.topSpeedMs,
    required this.locale,
    this.accent = false,
  });

  final int days;
  final double dropM;
  final double distanceM;
  final double topSpeedMs;
  final String locale;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final colour = accent ? c.accent : c.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Stat(label: s.days, value: '$days', colour: colour)),
        Expanded(child: _Stat(label: s.vertical, value: Fmt.metres(dropM, locale: locale), unit: 'hm', colour: colour)),
        Expanded(child: _Stat(label: s.distance, value: Fmt.km(distanceM, decimals: 0, locale: locale), unit: 'km', colour: colour)),
        Expanded(child: _Stat(label: s.topSpeed, value: Fmt.kmh(topSpeedMs, locale: locale), unit: 'km/h', colour: colour)),
      ],
    );
  }
}

/// Overline above the numeral, unit tertiary beside it.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.colour, this.unit});
  final String label;
  final String value;
  final String? unit;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.overline, style: AppText.label(c.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppText.numS(colour)),
              if (unit != null) ...[const SizedBox(width: 4), Text(unit!, style: AppText.unit(c.textTertiary, size: 11))],
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- friend code

class _FriendCodeCard extends ConsumerWidget {
  const _FriendCodeCard({required this.onFriends});
  final VoidCallback onFriends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final code = ref.watch(myFriendCodeProvider).asData?.value;
    return AppCard(
      child: Row(
        key: const ValueKey('profile-friend-code'),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.friendCode.overline, style: AppText.label(c.textTertiary)),
                const SizedBox(height: 6),
                code == null
                    ? Text(s.friendCodeUnavailable, style: AppText.bodyText(c.textSecondary, size: 15))
                    : Text(code, style: AppText.numS(c.accent).copyWith(letterSpacing: 4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SecondaryButton(key: const ValueKey('profile-friends'), label: s.friends, icon: Icons.people_outline_rounded, height: 40, onPressed: onFriends),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- contact

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        key: const ValueKey('profile-contact'),
        children: [
          Icon(Icons.mail_outline_rounded, size: 22, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.contact, style: AppText.title(c.textPrimary)),
                const SizedBox(height: 2),
                Text(s.contactHint, style: AppText.caption(c.textSecondary)),
                const SizedBox(height: 2),
                Text(kSupportEmail, style: AppText.caption(c.textTertiary)),
              ],
            ),
          ),
          GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
        ],
      ),
    );
  }
}
