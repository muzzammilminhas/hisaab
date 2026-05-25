import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../models/member_model.dart';
import '../models/settlement_model.dart';
import '../models/trip_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TRIP PROVIDER
///
/// Single source of truth for all app state. Responsibilities:
///   1. CRUD for Trips (create, read, update, delete)
///   2. CRUD for Members within a Trip
///   3. CRUD for Expenses within a Trip
///   4. Settlement algorithm — computes simplified "who owes whom" statements
///
/// All mutations immediately persist to Hive so data survives app restarts.
/// ─────────────────────────────────────────────────────────────────────────────
class TripProvider extends ChangeNotifier {
  // ── Private State ──────────────────────────────────────────────────────────

  /// The Hive box holding all Trip documents.
  late Box<Trip> _box;

  /// In-memory list of trips, kept in sync with Hive.
  /// Sorted newest-first for the home screen.
  List<Trip> _trips = [];

  /// UUID generator — cryptographically unique IDs for all entities.
  final _uuid = const Uuid();

  // ── Public Getters ─────────────────────────────────────────────────────────

  /// All trips, sorted by creation date descending (newest first).
  List<Trip> get trips => List.unmodifiable(_trips);

  /// Total number of trips.
  int get tripCount => _trips.length;

  // ── Initialisation ─────────────────────────────────────────────────────────

  TripProvider() {
    _init();
  }

  /// Opens the Hive box and loads persisted data into memory.
  void _init() {
    _box = Hive.box<Trip>('trips_box');
    _loadTrips();
  }

  /// Reads all trips from Hive and sorts them newest-first.
  void _loadTrips() {
    _trips = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — TRIP CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a new Trip with an initial list of member names.
  ///
  /// [memberNames] — raw strings like ["Muzammil", "Saad", "Muqi"].
  /// Each is converted to a [Member] with a unique ID and a color index
  /// derived from the loop index so avatars are visually distinct.
  Future<Trip> createTrip({
    required String name,
    String? destination,
    String emoji = '🧳',
    required List<String> memberNames,
  }) async {
    // Build Member objects from the supplied name strings.
    final members = memberNames
        .asMap()
        .entries
        .where((e) => e.value.trim().isNotEmpty)
        .map(
          (e) => Member(
            id: _uuid.v4(),
            name: e.value.trim(),
            colorIndex: e.key % 10, // cycles through 10 avatar colors
          ),
        )
        .toList();

    final trip = Trip(
      id: _uuid.v4(),
      name: name.trim(),
      destination: destination?.trim(),
      emoji: emoji,
      members: members,
      expenses: [],
      createdAt: DateTime.now(),
    );

    // Persist to Hive using the trip's own ID as the box key.
    await _box.put(trip.id, trip);
    _loadTrips();
    return trip;
  }

  /// Updates the metadata of an existing trip (name, destination, emoji).
  Future<void> updateTrip({
    required String tripId,
    required String name,
    String? destination,
    String? emoji,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null) return;

    trip.name = name.trim();
    trip.destination = destination?.trim();
    if (emoji != null) trip.emoji = emoji;

    await trip.save(); // HiveObject.save() persists in-place
    _loadTrips();
  }

  /// Permanently deletes a trip and ALL its members and expenses.
  Future<void> deleteTrip(String tripId) async {
    await _box.delete(tripId);
    _loadTrips();
  }

  /// Retrieves a single trip by ID. Returns null if not found.
  Trip? getTripById(String tripId) {
    return _box.get(tripId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — MEMBER CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a new member to an existing trip.
  Future<void> addMember({
    required String tripId,
    required String memberName,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null || memberName.trim().isEmpty) return;

    final member = Member(
      id: _uuid.v4(),
      name: memberName.trim(),
      colorIndex: trip.members.length % 10,
    );

    trip.members = [...trip.members, member];
    await trip.save();
    _loadTrips();
  }

  /// Renames an existing member.
  Future<void> updateMemberName({
    required String tripId,
    required String memberId,
    required String newName,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null || newName.trim().isEmpty) return;

    trip.members = trip.members.map((m) {
      return m.id == memberId ? m.copyWith(name: newName.trim()) : m;
    }).toList();

    await trip.save();
    _loadTrips();
  }

  /// Removes a member from a trip.
  ///
  /// Safety: Also removes this member from [splitAmongIds] on all expenses,
  /// and if the member was the payer, that expense's payer is left as-is
  /// (a warning can be surfaced in the UI — out of scope here).
  Future<void> removeMember({
    required String tripId,
    required String memberId,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null) return;

    // Remove from members list.
    trip.members = trip.members.where((m) => m.id != memberId).toList();

    // Scrub from all expense split lists.
    trip.expenses = trip.expenses.map((e) {
      final updatedSplits =
          e.splitAmongIds.where((id) => id != memberId).toList();
      return e.copyWith(splitAmongIds: updatedSplits);
    }).toList();

    await trip.save();
    _loadTrips();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — EXPENSE CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a new expense to an existing trip.
  ///
  /// [splitAmongIds] defaults to ALL member IDs if not provided.
  Future<void> addExpense({
    required String tripId,
    required String title,
    required double amount,
    required String paidByMemberId,
    List<String>? splitAmongIds,
    String? note,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null) return;

    // Default: split among everyone.
    final splits =
        splitAmongIds ?? trip.members.map((m) => m.id).toList();

    final expense = Expense(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      paidByMemberId: paidByMemberId,
      splitAmongIds: splits,
      createdAt: DateTime.now(),
      note: note?.trim(),
    );

    trip.expenses = [...trip.expenses, expense];
    await trip.save();
    _loadTrips();
  }

  /// Updates an existing expense inside a trip.
  Future<void> updateExpense({
    required String tripId,
    required String expenseId,
    required String title,
    required double amount,
    required String paidByMemberId,
    required List<String> splitAmongIds,
    String? note,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null) return;

    trip.expenses = trip.expenses.map((e) {
      if (e.id != expenseId) return e;
      return e.copyWith(
        title: title.trim(),
        amount: amount,
        paidByMemberId: paidByMemberId,
        splitAmongIds: splitAmongIds,
        note: note?.trim(),
      );
    }).toList();

    await trip.save();
    _loadTrips();
  }

  /// Deletes a single expense from a trip.
  Future<void> deleteExpense({
    required String tripId,
    required String expenseId,
  }) async {
    final trip = _box.get(tripId);
    if (trip == null) return;

    trip.expenses =
        trip.expenses.where((e) => e.id != expenseId).toList();
    await trip.save();
    _loadTrips();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION 4 — SETTLEMENT ALGORITHM
  //
  // The core math of the app. Produces a minimal list of transactions that
  // settles all debts. Uses the classic "net balance → min-cash-flow" approach.
  //
  // ALGORITHM IN PLAIN ENGLISH:
  //   Step 1 — For every expense, the payer "gains credit" equal to the full
  //            amount, and every person in the split "incurs a debt" equal to
  //            their per-person share (including the payer themselves).
  //
  //   Step 2 — Compute each member's NET BALANCE:
  //              net = totalPaid − totalOwed
  //            Positive net  → others owe this person  (creditor)
  //            Negative net  → this person owes others (debtor)
  //
  //   Step 3 — Greedily match the largest debtor with the largest creditor.
  //            The smaller of the two absolute values becomes a Settlement.
  //            Repeat until all balances are ~zero.
  //
  // This minimises the number of transactions (NP-hard in general, but the
  // greedy approach is optimal for typical trip sizes of 2–15 people).
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the simplified list of [Settlement] objects for a given trip.
  List<Settlement> calculateSettlements(String tripId) {
    final trip = _box.get(tripId);
    if (trip == null || trip.expenses.isEmpty) return [];

    // ── Step 1 & 2: Build net balance map ───────────────────────────────────
    // Key: memberId, Value: net amount (positive = owed to them)
    final Map<String, double> netBalance = {
      for (final m in trip.members) m.id: 0.0,
    };

    for (final expense in trip.expenses) {
      // Validate payer exists in the trip
      if (!netBalance.containsKey(expense.paidByMemberId)) continue;

      final validSplits = expense.splitAmongIds
          .where((id) => netBalance.containsKey(id))
          .toList();

      if (validSplits.isEmpty) continue;

      final share = expense.amount / validSplits.length;

      // Payer gets credited the full amount
      netBalance[expense.paidByMemberId] =
          (netBalance[expense.paidByMemberId] ?? 0) + expense.amount;

      // Everyone in the split is debited their share
      for (final memberId in validSplits) {
        netBalance[memberId] = (netBalance[memberId] ?? 0) - share;
      }
    }

    // ── Step 3: Greedy min-cash-flow settlement ──────────────────────────────

    // Separate into creditors (net > 0) and debtors (net < 0)
    // Use mutable lists so we can update balances in-place
    final List<_BalanceEntry> creditors = [];
    final List<_BalanceEntry> debtors = [];

    netBalance.forEach((memberId, balance) {
      final member = trip.memberById(memberId);
      if (member == null) return;

      // Use a small epsilon to avoid floating-point ghost debts
      if (balance > 0.005) {
        creditors.add(_BalanceEntry(memberId, member.name, balance));
      } else if (balance < -0.005) {
        debtors.add(_BalanceEntry(memberId, member.name, balance.abs()));
      }
    });

    final List<Settlement> settlements = [];

    // Sort both lists descending by absolute amount for optimal greedy matching
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    int ci = 0; // creditor pointer
    int di = 0; // debtor pointer

    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];

      // The transaction amount is the smaller of the two outstanding values
      final transactionAmount =
          creditor.amount < debtor.amount ? creditor.amount : debtor.amount;

      // Round to 2 decimal places to avoid floating-point noise
      final rounded = double.parse(transactionAmount.toStringAsFixed(2));

      if (rounded > 0.005) {
        settlements.add(Settlement(
          fromMemberId: debtor.memberId,
          fromMemberName: debtor.memberName,
          toMemberId: creditor.memberId,
          toMemberName: creditor.memberName,
          amount: rounded,
        ));
      }

      // Reduce both balances
      creditor.amount -= transactionAmount;
      debtor.amount -= transactionAmount;

      // Advance pointer if fully settled
      if (creditor.amount <= 0.005) ci++;
      if (debtor.amount <= 0.005) di++;
    }

    return settlements;
  }

  // ── Helper: Per-member spend summary ──────────────────────────────────────

  /// Returns a map of memberId → { 'paid': double, 'owes': double, 'net': double }
  /// Used by the Balances tab to show individual summaries.
  Map<String, Map<String, double>> getMemberSummary(String tripId) {
    final trip = _box.get(tripId);
    if (trip == null) return {};

    final Map<String, Map<String, double>> summary = {
      for (final m in trip.members)
        m.id: {'paid': 0.0, 'owes': 0.0, 'net': 0.0},
    };

    for (final expense in trip.expenses) {
      if (!summary.containsKey(expense.paidByMemberId)) continue;

      final validSplits = expense.splitAmongIds
          .where((id) => summary.containsKey(id))
          .toList();
      if (validSplits.isEmpty) continue;

      final share = expense.amount / validSplits.length;

      // Credit the payer
      summary[expense.paidByMemberId]!['paid'] =
          summary[expense.paidByMemberId]!['paid']! + expense.amount;

      // Debit each split participant
      for (final id in validSplits) {
        summary[id]!['owes'] = summary[id]!['owes']! + share;
      }
    }

    // Compute net = paid − owes for each member
    for (final id in summary.keys) {
      final paid = summary[id]!['paid']!;
      final owes = summary[id]!['owes']!;
      summary[id]!['net'] = paid - owes;
    }

    return summary;
  }
}

// ── Private helper class (not exported) ──────────────────────────────────────

/// Mutable balance entry used during the greedy settlement matching.
class _BalanceEntry {
  final String memberId;
  final String memberName;
  double amount; // mutable — decremented during matching

  _BalanceEntry(this.memberId, this.memberName, this.amount);
}
