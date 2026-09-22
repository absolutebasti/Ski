import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/resorts/resort_repository.dart';
import 'account_strings.dart';

/// Result of [ResortPicker.show]: `null` inside means "Kein Heimatgebiet".
@immutable
class ResortSelection {
  const ResortSelection(this.resortId);
  final String? resortId;
}

/// Searchable full-height sheet over the bundled resort list.
class ResortPicker {
  const ResortPicker._();

  /// Returns null when the sheet was dismissed without a choice.
  static Future<ResortSelection?> show(BuildContext context, {String? selectedId}) => AppSheet.show<ResortSelection>(
        context,
        title: AccountStrings.of(context).homeResort,
        expand: true,
        builder: (_) => _ResortPickerBody(selectedId: selectedId),
      );
}

class _ResortPickerBody extends ConsumerStatefulWidget {
  const _ResortPickerBody({this.selectedId});
  final String? selectedId;

  @override
  ConsumerState<_ResortPickerBody> createState() => _ResortPickerBodyState();
}

class _ResortPickerBodyState extends ConsumerState<_ResortPickerBody> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Umlaut-tolerant contains match on name and country.
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e');

  List<Resort> _filter(List<Resort> all) {
    final q = _fold(_query.text.trim());
    if (q.isEmpty) return all;
    return all.where((r) => _fold(r.name).contains(q) || _fold(r.country).contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = AccountStrings.of(context);
    final repo = ref.watch(resortRepositoryProvider);
    final all = repo.asData?.value.all ?? const <Resort>[];
    final list = _filter(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12),
          child: SurfaceCard(
            radius: Tokens.rPill,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            fill: c.glassFill,
            border: c.glassStroke,
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('resort-search'),
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: AppText.bodyText(c.textPrimary, size: 16),
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: s.searchResort,
                      hintStyle: AppText.bodyText(c.textTertiary, size: 16),
                    ),
                  ),
                ),
                if (_query.text.isNotEmpty)
                  Pressable(
                    onTap: () {
                      _query.clear();
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded, size: 18, color: c.textTertiary),
                  ),
              ],
            ),
          ),
        ),
        const Hairline(),
        Expanded(
          child: repo.isLoading
              ? const SizedBox.shrink()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: Tokens.pad),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, _) => const Hairline(inset: Tokens.pad),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _PickerRow(
                        key: const ValueKey('resort-none'),
                        label: s.clearResort,
                        selected: widget.selectedId == null,
                        onTap: () => Navigator.of(context).pop(const ResortSelection(null)),
                      );
                    }
                    final r = list[i - 1];
                    return _PickerRow(
                      key: ValueKey('resort-${r.id}'),
                      label: r.name,
                      trailing: r.country,
                      selected: r.id == widget.selectedId,
                      onTap: () => Navigator.of(context).pop(ResortSelection(r.id)),
                    );
                  },
                ),
        ),
        if (!repo.isLoading && list.isEmpty && _query.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(Tokens.pad),
            child: Text(s.noResortFound, style: AppText.bodyText(c.textSecondary, size: 15)),
          ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({super.key, required this.label, required this.selected, required this.onTap, this.trailing});
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: Tokens.minTarget,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
        color: selected ? c.accentWash : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.bodyText(selected ? c.accent : c.textPrimary, size: 16, weight: selected ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) Text(trailing!, style: AppText.label(c.textTertiary)),
            if (selected) ...[const SizedBox(width: 10), Icon(Icons.check_rounded, size: 18, color: c.accent)],
          ],
        ),
      ),
    );
  }
}
