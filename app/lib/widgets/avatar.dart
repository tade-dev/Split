import 'package:flutter/material.dart';

import '../core/theme/split_colors.dart';

/// A participant's initial on their colour. DESIGN.md's Avatar.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.colourIndex,
    this.size = 36,
  }) : assert(
          size == 24 || size == 30 || size == 36 || size == 40 || size == 44,
          'Avatar sizes are 24, 30, 36, 40 and 44 (DESIGN.md)',
        );

  final String name;
  final int colourIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = SplitColors.of(context).participant(colourIndex);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        key: const Key('avatar-disc'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colour.fill, shape: BoxShape.circle),
        child: Text(
          initial,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colour.text,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
        ),
      ),
    );
  }
}

/// Overlapping avatars, each ringed in the background colour so the edges
/// read as separate people rather than one blob.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.size = 30, this.ring});

  final List<({String name, int colourIndex})> people;
  final double size;

  /// The ring behind each avatar: whatever it sits on. Defaults to the page
  /// background; on Home's dark card it is the card's own colour.
  final Color? ring;

  static const _ring = 2.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final ring = this.ring ?? SplitColors.of(context).background;
    final outer = size + _ring * 2;
    final step = outer - _overlap;
    return SizedBox(
      width: outer + step * (people.length - 1),
      height: outer,
      child: Stack(
        children: [
          for (final (i, p) in people.indexed)
            Positioned(
              left: step * i,
              child: Container(
                padding: const EdgeInsets.all(_ring),
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: Avatar(name: p.name, colourIndex: p.colourIndex, size: size),
              ),
            ),
        ],
      ),
    );
  }
}
