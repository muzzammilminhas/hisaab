import 'package:hive/hive.dart';

part 'expense_model.g.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// EXPENSE MODEL
///
/// Represents a single expense entry inside a Trip.
/// typeId: 1
///
/// Key design decision:
///   - [paidByMemberId]   → stores the ID of the member who paid.
///   - [splitAmongIds]    → stores IDs of members sharing this expense.
///   Using IDs (not nested Member objects) prevents data duplication and
///   keeps the model lean. The Provider resolves names at runtime.
/// ─────────────────────────────────────────────────────────────────────────────
@HiveType(typeId: 1)
class Expense extends HiveObject {
  /// Unique identifier — generated via `uuid` package.
  @HiveField(0)
  final String id;

  /// Human-readable label (e.g., "Fuel for Bikes", "Hotel Night 1").
  @HiveField(1)
  String title;

  /// Total amount paid — stored as double for decimal precision.
  @HiveField(2)
  double amount;

  /// Member ID of the person who physically paid this expense.
  @HiveField(3)
  String paidByMemberId;

  /// List of Member IDs among whom this expense is split equally.
  /// Defaults to all trip members when an expense is created.
  @HiveField(4)
  List<String> splitAmongIds;

  /// Timestamp of when the expense was logged.
  @HiveField(5)
  final DateTime createdAt;

  /// Optional note/description for extra context.
  @HiveField(6)
  String? note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidByMemberId,
    required this.splitAmongIds,
    required this.createdAt,
    this.note,
  });

  /// The share each person in [splitAmongIds] owes for this expense.
  double get perPersonShare {
    if (splitAmongIds.isEmpty) return 0.0;
    return amount / splitAmongIds.length;
  }

  /// Creates a copy with optional overrides (useful for edit flows).
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? paidByMemberId,
    List<String>? splitAmongIds,
    DateTime? createdAt,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      splitAmongIds: splitAmongIds ?? List.from(this.splitAmongIds),
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  @override
  String toString() => 'Expense(id: $id, title: $title, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Expense && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
