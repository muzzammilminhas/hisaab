/// ─────────────────────────────────────────────────────────────────────────────
/// SETTLEMENT MODEL
///
/// A pure Dart data class (no Hive needed — computed at runtime, never stored).
/// Represents a single simplified debt: "[fromName] owes [toName] [amount]"
/// ─────────────────────────────────────────────────────────────────────────────
class Settlement {
  /// ID of the member who owes money.
  final String fromMemberId;

  /// Display name of the member who owes money.
  final String fromMemberName;

  /// ID of the member who is owed money.
  final String toMemberId;

  /// Display name of the member who is owed money.
  final String toMemberName;

  /// The exact amount owed — always positive.
  final double amount;

  const Settlement({
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
  });

  /// Human-readable summary for debugging.
  @override
  String toString() =>
      '$fromMemberName owes $toMemberName \$${amount.toStringAsFixed(2)}';
}
