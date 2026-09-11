import 'package:flutter/material.dart';

/// A stable identity avatar backed by the project's avatar image assets.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar.person({
    super.key,
    required this.name,
    this.radius = 20,
    this.emphasized = false,
  }) : members = const [],
       isGroup = false;

  const ChatAvatar.group({super.key, required this.members, this.radius = 20})
    : name = '',
      emphasized = false,
      isGroup = true;

  final List<String> members;
  final String name;
  final double radius;
  final bool emphasized;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    if (isGroup) {
      final visibleMembers = members
          .where((member) => member.trim().isNotEmpty)
          .take(9)
          .toList();
      return Semantics(
        label: '群组头像：${visibleMembers.join('、')}',
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: radius * 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.24),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gridCount = visibleMembers.length <= 4 ? 2 : 3;
                    final cellSize = constraints.maxWidth / gridCount;
                    return Stack(
                      children: [
                        for (
                          var index = 0;
                          index < visibleMembers.length;
                          index++
                        )
                          Positioned(
                            left: (index % gridCount) * cellSize,
                            top: (index ~/ gridCount) * cellSize,
                            width: cellSize,
                            height: cellSize,
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: _AvatarCell(name: visibleMembers[index]),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    final displayName = name.trim().isEmpty ? '我' : name.trim();
    return Semantics(
      label: '$displayName 的头像',
      child: ExcludeSemantics(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          padding: emphasized ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: emphasized
                ? Border.all(color: const Color(0xFF6256E8), width: 2)
                : null,
          ),
          child: ClipOval(
            child: Image.asset(_avatarAssetFor(displayName), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _AvatarCell extends StatelessWidget {
  const _AvatarCell({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white, width: 1.2),
    ),
    child: Image.asset(_avatarAssetFor(name), fit: BoxFit.cover),
  );
}

String _avatarAssetFor(String name) {
  const assets = [
    'assets/avatar/Avatar-1_1_11zon.png',
    'assets/avatar/Avatar-2_2_11zon.png',
    'assets/avatar/Avatar-3_3_11zon.png',
    'assets/avatar/Avatar-4_4_11zon.png',
    'assets/avatar/Avatar-5_5_11zon.png',
    'assets/avatar/Avatar-6_6_11zon.png',
    'assets/avatar/Avatar-7_7_11zon.png',
    'assets/avatar/Avatar-8_8_11zon.png',
    'assets/avatar/Avatar-9_9_11zon.png',
    'assets/avatar/Avatar-10_10_11zon.png',
    'assets/avatar/Avatar-11_11_11zon.png',
    'assets/avatar/Avatar_12_11zon.png',
  ];
  final hash = name.runes.fold<int>(0, (value, rune) => value + rune);
  return assets[hash % assets.length];
}
