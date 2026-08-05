import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import 'package:flax/shared/country.dart';

/// Width of the leading slot in an info chip.
///
/// Every chip's leading glyph — a flag, an icon — is centred in a box of this
/// size so the rows line up. An emoji and a Material icon have different
/// intrinsic sizes and baselines, and laying them straight into a row left the
/// country sitting at a different height from the years beside it.
const double infoChipLeadingWidth = 20;

/// Height of a flag. 3:4 of the leading width, close to the 2:3 most national
/// flags use, so the box is filled without distorting them.
const double _flagHeight = 14;

/// A country flag, drawn from bundled SVGs.
///
/// Not emoji: Windows ships no flag glyphs at all, so a regional indicator pair
/// renders there as the two letters in boxes — "CA" where a Canadian flag was
/// meant. The vector assets look identical on every platform.
///
/// Returns null when the code is not a country we know, so callers can fall
/// back to an icon rather than render a blank.
class CountryFlagIcon extends StatelessWidget {
  const CountryFlagIcon({super.key, required this.countryCode});

  final String countryCode;

  static bool isSupported(String? code) => countryName(code) != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: infoChipLeadingWidth,
      height: _flagHeight,
      child: CountryFlag.fromCountryCode(
        countryCode,
        theme: const ImageTheme(
          width: infoChipLeadingWidth,
          height: _flagHeight,
          // A hairline radius keeps the edges from looking ragged at this size.
          shape: RoundedRectangle(2),
        ),
      ),
    );
  }
}

/// One metadata item: a leading glyph and a label, aligned with its neighbours.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.countryCode,
  });

  final String label;

  /// Shown when there is no flag to draw.
  final IconData? icon;

  /// When set and recognised, a flag replaces [icon].
  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flagCode =
        CountryFlagIcon.isSupported(countryCode) ? countryCode : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: infoChipLeadingWidth,
          height: infoChipLeadingWidth,
          child: Center(
            child: flagCode != null
                ? CountryFlagIcon(countryCode: flagCode)
                : Icon(
                    icon ?? Icons.public,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
