import 'package:flutter/material.dart';

/// A participant's colour: the fill that marks their avatar, receipt dots and
/// claim cards, and the text that sits on it.
@immutable
class ParticipantColour {
  const ParticipantColour(this.fill, this.text);
  final Color fill;
  final Color text;

  @override
  bool operator ==(Object other) =>
      other is ParticipantColour && other.fill == fill && other.text == text;

  @override
  int get hashCode => Object.hash(fill, text);
}

/// The design tokens from docs/design/DESIGN.md that Material's ColorScheme
/// has no home for. Read via SplitColors.of(context); never hardcode a hex
/// value in a widget.
@immutable
class SplitColors extends ThemeExtension<SplitColors> {
  const SplitColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.primaryTint,
    required this.success,
    required this.successTint,
    required this.highlight,
    required this.warningTint,
    required this.warningText,
    required this.warningBorder,
    required this.neutralTint,
    required this.darkBg,
    required this.darkSurface,
    required this.darkTrack,
    required this.darkLink,
    required this.onDarkMuted,
    required this.accentCyan,
    required this.paidBar,
    required this.participants,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;
  final Color primaryTint;
  final Color success;
  final Color successTint;
  final Color highlight;
  final Color warningTint;
  final Color warningText;
  final Color warningBorder;
  final Color neutralTint;
  final Color darkBg;
  final Color darkSurface;
  final Color darkTrack;
  final Color darkLink;
  final Color onDarkMuted;
  final Color accentCyan;
  final Color paidBar;

  /// Assigned in join order, the organiser first. A person's colour follows
  /// their items everywhere, which is Split's signature. Never use colour
  /// alone for meaning: avatars carry the initial, claim cards the name.
  final List<ParticipantColour> participants;

  /// The colour for a participant's `colourIndex`. Wraps past eight people.
  ParticipantColour participant(int colourIndex) =>
      participants[colourIndex % participants.length];

  static const light = SplitColors(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF001C64),
    muted: Color(0xFF515A6B),
    line: Color(0xFFDCE2EA),
    primary: Color(0xFF0070E0),
    primaryTint: Color(0xFFE6F0FC),
    success: Color(0xFF147A47),
    successTint: Color(0xFFE3F4EA),
    highlight: Color(0xFFFFC439),
    warningTint: Color(0xFFFFF4D6),
    warningText: Color(0xFF7A5200),
    warningBorder: Color(0xFFF1D27A),
    neutralTint: Color(0xFFEBEEF3),
    darkBg: Color(0xFF00123F),
    darkSurface: Color(0xFF0B2A78),
    darkTrack: Color(0xFF0F3488),
    darkLink: Color(0xFF123C96),
    onDarkMuted: Color(0xFFB9C8EE),
    accentCyan: Color(0xFF60CDFF),
    paidBar: Color(0xFF5BD08F),
    // 0-4 from DESIGN.md. 5-7 chosen at the same lightness (luminance 0.50,
    // 0.57, 0.59 against 0-4's 0.48-0.61), each text at least 7:1 on its fill.
    participants: [
      ParticipantColour(Color(0xFFFFC439), Color(0xFF3D2B00)),
      ParticipantColour(Color(0xFFFF9F80), Color(0xFF4A1A0A)),
      ParticipantColour(Color(0xFF9DBEFF), Color(0xFF0A2560)),
      ParticipantColour(Color(0xFF7AD9AE), Color(0xFF063D26)),
      ParticipantColour(Color(0xFFD6B0FF), Color(0xFF3A1466)),
      ParticipantColour(Color(0xFFFF9EC7), Color(0xFF4D0A2B)),
      ParticipantColour(Color(0xFF7FD3E6), Color(0xFF053A45)),
      ParticipantColour(Color(0xFFB9D46C), Color(0xFF2E3A05)),
    ],
  );

  static SplitColors of(BuildContext context) =>
      Theme.of(context).extension<SplitColors>() ?? light;

  @override
  SplitColors copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? primary,
    Color? primaryTint,
    Color? success,
    Color? successTint,
    Color? highlight,
    Color? warningTint,
    Color? warningText,
    Color? warningBorder,
    Color? neutralTint,
    Color? darkBg,
    Color? darkSurface,
    Color? darkTrack,
    Color? darkLink,
    Color? onDarkMuted,
    Color? accentCyan,
    Color? paidBar,
    List<ParticipantColour>? participants,
  }) {
    return SplitColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      primary: primary ?? this.primary,
      primaryTint: primaryTint ?? this.primaryTint,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      highlight: highlight ?? this.highlight,
      warningTint: warningTint ?? this.warningTint,
      warningText: warningText ?? this.warningText,
      warningBorder: warningBorder ?? this.warningBorder,
      neutralTint: neutralTint ?? this.neutralTint,
      darkBg: darkBg ?? this.darkBg,
      darkSurface: darkSurface ?? this.darkSurface,
      darkTrack: darkTrack ?? this.darkTrack,
      darkLink: darkLink ?? this.darkLink,
      onDarkMuted: onDarkMuted ?? this.onDarkMuted,
      accentCyan: accentCyan ?? this.accentCyan,
      paidBar: paidBar ?? this.paidBar,
      participants: participants ?? this.participants,
    );
  }

  @override
  SplitColors lerp(ThemeExtension<SplitColors>? other, double t) {
    if (other is! SplitColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SplitColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      primary: c(primary, other.primary),
      primaryTint: c(primaryTint, other.primaryTint),
      success: c(success, other.success),
      successTint: c(successTint, other.successTint),
      highlight: c(highlight, other.highlight),
      warningTint: c(warningTint, other.warningTint),
      warningText: c(warningText, other.warningText),
      warningBorder: c(warningBorder, other.warningBorder),
      neutralTint: c(neutralTint, other.neutralTint),
      darkBg: c(darkBg, other.darkBg),
      darkSurface: c(darkSurface, other.darkSurface),
      darkTrack: c(darkTrack, other.darkTrack),
      darkLink: c(darkLink, other.darkLink),
      onDarkMuted: c(onDarkMuted, other.onDarkMuted),
      accentCyan: c(accentCyan, other.accentCyan),
      paidBar: c(paidBar, other.paidBar),
      participants: [
        for (var i = 0; i < participants.length; i++)
          ParticipantColour(
            c(participants[i].fill, other.participant(i).fill),
            c(participants[i].text, other.participant(i).text),
          ),
      ],
    );
  }
}
