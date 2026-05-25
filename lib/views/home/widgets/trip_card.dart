import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/trip_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TRIP CARD
///
/// The primary card displayed on the Home Screen for each Trip.
/// Shows: emoji, name, destination, member count, expense count, total cost.
/// Tapping navigates to the Trip Dashboard.
/// Long-press reveals a context menu for edit/delete.
/// ─────────────────────────────────────────────────────────────────────────────
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  // Currency formatter — adjust locale/symbol as needed
  static final _currency = NumberFormat('#,##0.00', 'en_US');

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Derive a subtle tonal background for each card from the primary color
    final cardBg = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surface;

    return Card(
      color: cardBg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: Emoji + Name + More menu ─────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji avatar
                  _EmojiAvatar(emoji: trip.emoji, colorScheme: colorScheme),

                  const SizedBox(width: 12),

                  // Trip name + destination
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.destination != null &&
                            trip.destination!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  trip.destination!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(trip.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Context menu (edit / delete)
                  _MoreMenu(onEdit: onEdit, onDelete: onDelete),
                ],
              ),

              const SizedBox(height: 16),

              // ── Divider ────────────────────────────────────────────────────
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),

              const SizedBox(height: 14),

              // ── Bottom row: Stats ──────────────────────────────────────────
              Row(
                children: [
                  // Members
                  _StatPill(
                    icon: Icons.group_outlined,
                    label:
                        '${trip.memberCount} ${trip.memberCount == 1 ? 'member' : 'members'}',
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(width: 8),

                  // Expenses
                  _StatPill(
                    icon: Icons.receipt_long_outlined,
                    label:
                        '${trip.expenseCount} ${trip.expenseCount == 1 ? 'expense' : 'expenses'}',
                    colorScheme: colorScheme,
                  ),

                  const Spacer(),

                  // Total cost — highlighted
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PKR ${_currency.format(trip.totalCost)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _EmojiAvatar extends StatelessWidget {
  final String emoji;
  final ColorScheme colorScheme;

  const _EmojiAvatar({required this.emoji, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MoreMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit Trip'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: colorScheme.error),
              const SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
