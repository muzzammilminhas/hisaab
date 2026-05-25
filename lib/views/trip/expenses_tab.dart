import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../shared/delete_confirm_dialog.dart';
import '../shared/member_avatar.dart';
import 'add_edit_expense_sheet.dart';

/// Expenses tab — shows the total banner + a list of all expenses.
///
/// FIX: Each expense tile now has a visible 3-dot popup menu with Edit and
/// Delete actions in addition to the swipe-left gesture. This makes delete
/// discoverable without needing to know about the swipe.
class ExpensesTab extends StatelessWidget {
  final String tripId;
  static final _currency = NumberFormat('#,##0.00', 'en_US');

  const ExpensesTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trip = provider.getTripById(tripId);
        if (trip == null) return const SizedBox.shrink();

        final expenses = trip.expenses.reversed.toList(); // newest first

        if (expenses.isEmpty) {
          return _EmptyExpenses(trip: trip);
        }

        return Column(
          children: [
            _TotalBanner(trip: trip),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  final payer = trip.memberById(expense.paidByMemberId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Slidable(
                      key: ValueKey(expense.id),
                      // Swipe left → Edit | Delete (power user shortcut)
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.4,
                        children: [
                          SlidableAction(
                            onPressed: (_) => AddEditExpenseSheet.show(
                              context,
                              trip: trip,
                              existingExpense: expense,
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12)),
                          ),
                          SlidableAction(
                            onPressed: (_) => _confirmDelete(
                              context,
                              provider,
                              trip,
                              expense.id,
                              expense.title,
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onErrorContainer,
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12)),
                          ),
                        ],
                      ),
                      child: _ExpenseTile(
                        title: expense.title,
                        amount: expense.amount,
                        payerName: payer?.name ?? 'Unknown',
                        payerColorIndex: payer?.colorIndex ?? 0,
                        splitCount: expense.splitAmongIds.length,
                        perPersonShare: expense.perPersonShare,
                        date: expense.createdAt,
                        note: expense.note,
                        // Tap tile body → Edit
                        onTap: () => AddEditExpenseSheet.show(
                          context,
                          trip: trip,
                          existingExpense: expense,
                        ),
                        // 3-dot menu → Edit or Delete (clearly visible)
                        onEdit: () => AddEditExpenseSheet.show(
                          context,
                          trip: trip,
                          existingExpense: expense,
                        ),
                        onDelete: () => _confirmDelete(
                          context,
                          provider,
                          trip,
                          expense.id,
                          expense.title,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TripProvider provider,
    Trip trip,
    String expenseId,
    String expenseTitle,
  ) async {
    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Delete "$expenseTitle"?',
      message: 'This expense will be permanently removed.',
    );
    if (confirmed && context.mounted) {
      await provider.deleteExpense(tripId: trip.id, expenseId: expenseId);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  final Trip trip;
  static final _currency = NumberFormat('#,##0.00', 'en_US');

  const _TotalBanner({required this.trip});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Trip Cost',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'PKR ${_currency.format(trip.totalCost)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BannerStat(
                  icon: Icons.receipt_long_outlined,
                  label: '${trip.expenseCount} expenses',
                  colorScheme: colorScheme),
              const SizedBox(height: 4),
              _BannerStat(
                  icon: Icons.group_outlined,
                  label: '${trip.memberCount} members',
                  colorScheme: colorScheme),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _BannerStat(
      {required this.icon, required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: colorScheme.onPrimaryContainer.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer.withOpacity(0.8))),
      ],
    );
  }
}

/// Individual expense row.
///
/// Has THREE ways to access Edit / Delete:
///   1. Tap the tile body → opens Edit sheet
///   2. Swipe left → reveals Edit and Delete action buttons
///   3. Tap the ••• icon at top-right → popup menu with Edit and Delete
class _ExpenseTile extends StatelessWidget {
  final String title;
  final double amount;
  final String payerName;
  final int payerColorIndex;
  final int splitCount;
  final double perPersonShare;
  final DateTime date;
  final String? note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _currency = NumberFormat('#,##0.00', 'en_US');

  const _ExpenseTile({
    required this.title,
    required this.amount,
    required this.payerName,
    required this.payerColorIndex,
    required this.splitCount,
    required this.perPersonShare,
    required this.date,
    this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              // ── Payer avatar ───────────────────────────────────────────────
              MemberAvatar(
                  name: payerName,
                  colorIndex: payerColorIndex,
                  size: 42,
                  fontSize: 14),
              const SizedBox(width: 12),

              // ── Title + payer info ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Paid by $payerName',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          ' · $splitCount ${splitCount == 1 ? 'person' : 'people'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (note != null && note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Amount + per-person ────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${_currency.format(amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_currency.format(perPersonShare)}/ea',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d').format(date),
                    style: TextStyle(
                        fontSize: 10, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),

              // ── FIX #2: Visible 3-dot menu ─────────────────────────────────
              // Previously only swipe-to-delete existed — hard to discover.
              // This popup makes Edit and Delete always visible and tappable.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: colorScheme.onSurfaceVariant),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16,
                          color: colorScheme.error),
                      const SizedBox(width: 10),
                      Text('Delete',
                          style: TextStyle(color: colorScheme.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  final Trip trip;
  const _EmptyExpenses({required this.trip});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('💸', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          Text(
            'No expenses yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to log your\nfirst expense for ${trip.name}',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
