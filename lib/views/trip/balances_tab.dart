import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/settlement_model.dart';
import '../../../providers/trip_provider.dart';
import '../shared/member_avatar.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// BALANCES TAB
///
/// Tab 2 of the Trip Dashboard. Shows:
///   1. Per-member summary (paid / owed / net)
///   2. Simplified settlement statements ("X owes Y PKR Z")
///
/// All data is derived live from the settlement algorithm in TripProvider.
/// ─────────────────────────────────────────────────────────────────────────────
class BalancesTab extends StatelessWidget {
  final String tripId;

  const BalancesTab({super.key, required this.tripId});

  static final _currency = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trip = provider.getTripById(tripId);
        if (trip == null) return const SizedBox.shrink();

        if (trip.expenses.isEmpty) {
          return _EmptyBalances(tripName: trip.name);
        }

        final settlements = provider.calculateSettlements(tripId);
        final summary = provider.getMemberSummary(tripId);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // ── Per-member breakdown ─────────────────────────────────────
            _SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Member Summary',
              subtitle: 'Who paid vs. who owes',
            ),
            const SizedBox(height: 10),
            ...trip.members.map((member) {
              final data = summary[member.id];
              if (data == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MemberSummaryCard(
                  name: member.name,
                  colorIndex: member.colorIndex,
                  paid: data['paid'] ?? 0,
                  owes: data['owes'] ?? 0,
                  net: data['net'] ?? 0,
                ),
              );
            }),

            const SizedBox(height: 24),

            // ── Settlement statements ────────────────────────────────────
            _SectionHeader(
              icon: Icons.swap_horiz_rounded,
              title: 'Settlements',
              subtitle: settlements.isEmpty
                  ? 'Everyone is even!'
                  : '${settlements.length} transaction${settlements.length == 1 ? '' : 's'} to settle all debts',
            ),
            const SizedBox(height: 10),

            if (settlements.isEmpty)
              _AllEvenCard()
            else
              ...settlements.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettlementCard(
                    settlement: entry.value,
                    index: entry.key,
                  ),
                );
              }),

            // ── Complexity note ──────────────────────────────────────────
            if (settlements.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AlgorithmNote(),
            ],
          ],
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

/// Per-member card showing paid / owes / net with a colored net indicator.
class _MemberSummaryCard extends StatelessWidget {
  final String name;
  final int colorIndex;
  final double paid;
  final double owes;
  final double net;

  static final _currency = NumberFormat('#,##0', 'en_US');

  const _MemberSummaryCard({
    required this.name,
    required this.colorIndex,
    required this.paid,
    required this.owes,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPositive = net >= 0;
    final netColor = isPositive ? const Color(0xFF22C55E) : colorScheme.error;
    final netBg = isPositive
        ? const Color(0xFF22C55E).withOpacity(0.1)
        : colorScheme.errorContainer;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            MemberAvatar(name: name, colorIndex: colorIndex, size: 42),
            const SizedBox(width: 12),

            // Name + paid/owes breakdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniStat(
                          label: 'Paid',
                          value: 'PKR ${_currency.format(paid)}',
                          color: const Color(0xFF22C55E)),
                      const SizedBox(width: 12),
                      _MiniStat(
                          label: 'Share',
                          value: 'PKR ${_currency.format(owes)}',
                          color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),

            // Net badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: netBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    isPositive ? 'Gets back' : 'Owes',
                    style: TextStyle(
                        fontSize: 9,
                        color: netColor,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'PKR ${_currency.format(net.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A single settlement card: "Muzammil owes Saad PKR 450"
class _SettlementCard extends StatelessWidget {
  final Settlement settlement;
  final int index;

  static final _currency = NumberFormat('#,##0.00', 'en_US');

  const _SettlementCard({
    required this.settlement,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),

            // From member (debtor)
            _PersonPill(
              name: settlement.fromMemberName,
              isDebtor: true,
              colorScheme: colorScheme,
            ),

            const SizedBox(width: 8),

            // Arrow + Amount
            Column(
              children: [
                Icon(Icons.arrow_forward_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PKR ${_currency.format(settlement.amount)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),

            // To member (creditor)
            _PersonPill(
              name: settlement.toMemberName,
              isDebtor: false,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonPill extends StatelessWidget {
  final String name;
  final bool isDebtor;
  final ColorScheme colorScheme;

  const _PersonPill({
    required this.name,
    required this.isDebtor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDebtor ? colorScheme.error : const Color(0xFF22C55E);
    final bg = isDebtor
        ? colorScheme.errorContainer
        : const Color(0xFF22C55E).withOpacity(0.12);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              isDebtor ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              isDebtor ? 'pays' : 'receives',
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllEvenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(
            'All settled up!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everyone has paid their fair share.',
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AlgorithmNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Debts are simplified using a min-cash-flow algorithm '
              'to minimize the number of transactions.',
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBalances extends StatelessWidget {
  final String tripName;

  const _EmptyBalances({required this.tripName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                  child: Text('⚖️', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing to settle yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses in the Expenses tab\nand balances will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
