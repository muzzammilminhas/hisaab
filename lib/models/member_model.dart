import 'package:hive/hive.dart';

part 'member_model.g.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MEMBER MODEL
///
/// Represents a single person in a trip (e.g., "Muzammil", "Saad").
/// typeId: 0  — must be unique across ALL Hive models in the app.
/// ─────────────────────────────────────────────────────────────────────────────
@HiveType(typeId: 0)
class Member extends HiveObject {
  /// Unique identifier — generated via `uuid` package at creation time.
  @HiveField(0)
  final String id;

  /// Display name of the member.
  @HiveField(1)
  String name;

  /// Optional: avatar color index (0–9) for a colorful placeholder avatar.
  /// We derive a color from this index in the UI layer — no image needed.
  @HiveField(2)
  final int colorIndex;

  Member({
    required this.id,
    required this.name,
    required this.colorIndex,
  });

  /// Creates a copy of this Member with optional field overrides.
  Member copyWith({String? id, String? name, int? colorIndex}) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  String toString() => 'Member(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Member && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
