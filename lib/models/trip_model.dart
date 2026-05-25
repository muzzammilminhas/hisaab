import 'package:hive/hive.dart';

import 'expense_model.dart';
import 'member_model.dart';

part 'trip_model.g.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TRIP MODEL
///
/// The root aggregate — one Trip owns its Members and Expenses.
/// typeId: 2
///
/// Architecture note:
///   Hive stores Trip objects as the top-level document in 'trips_box'.
///   Members and Expenses are embedded lists inside each Trip, so there are
///   no foreign-key lookups or joins — pure offline NoSQL document model.
/// ─────────────────────────────────────────────────────────────────────────────
@HiveType(typeId: 2)
class Trip extends HiveObject {
  /// Unique identifier — generated via `uuid` package.
  @HiveField(0)
  final String id;

  /// Trip name displayed on the home card (e.g., "Khunjerab Tour 2026").
  @HiveField(1)
  String name;

  /// Optional destination or short description shown as a subtitle.
  @HiveField(2)
  String? destination;

  /// All members participating in this trip.
  @HiveField(3)
  List<Member> members;

  /// All expenses logged under this trip.
  @HiveField(4)
  List<Expense> expenses;

  /// When the trip was created — used for sorting on the home screen.
  @HiveField(5)
  final DateTime createdAt;

  /// Optional emoji for quick visual identification (e.g., "🏔️", "🚗").
  @HiveField(6)
  String emoji;

  Trip({
    required this.id,
    required this.name,
    this.destination,
    required this.members,
    required this.expenses,
    required this.createdAt,
    this.emoji = '🧳',
  });

  // ── Computed Properties ────────────────────────────────────────────────────

  /// Sum of all expense amounts in this trip.
  double get totalCost =>
      expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  /// Number of expenses logged.
  int get expenseCount => expenses.length;

  /// Number of members in this trip.
  int get memberCount => members.length;

  /// Looks up a Member by their ID. Returns null if not found.
  /// Used by the settlement algorithm in TripProvider.
  Member? memberById(String memberId) {
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return null;
    }
  }

  /// Returns a safe display string for currency (e.g., "PKR 12,450.00").
  /// Actual formatting is handled in the UI layer with `intl`.
  String get totalCostRaw => totalCost.toStringAsFixed(2);

  /// Creates a copy of this Trip with optional field overrides.
  Trip copyWith({
    String? id,
    String? name,
    String? destination,
    List<Member>? members,
    List<Expense>? expenses,
    DateTime? createdAt,
    String? emoji,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      members: members ?? List.from(this.members),
      expenses: expenses ?? List.from(this.expenses),
      createdAt: createdAt ?? this.createdAt,
      emoji: emoji ?? this.emoji,
    );
  }

  @override
  String toString() => 'Trip(id: $id, name: $name, members: ${members.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Trip && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
