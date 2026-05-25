import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';
import '../home/add_edit_trip_sheet.dart';
import '../shared/delete_confirm_dialog.dart';
import 'add_edit_expense_sheet.dart';
import 'balances_tab.dart';
import 'expenses_tab.dart';
import 'manage_members_sheet.dart';

class TripDashboard extends StatefulWidget {
  final String tripId;
  const TripDashboard({super.key, required this.tripId});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trip = provider.getTripById(widget.tripId);

        // FIX #3: Trip was deleted externally (e.g. from another screen).
        // Show nothing and schedule a pop — avoids blank screen.
        if (trip == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: colorScheme.surface,
                surfaceTintColor: colorScheme.surfaceTint,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // FIX #1: Trip name lives here in the normal AppBar title slot.
                // Previously it was in FlexibleSpaceBar.title which caused the
                // "BOTTOM OVERFLOWED BY 30 PIXELS" debug banner — that text was
                // Flutter's overflow indicator rendering inside the UI because
                // the title row couldn't fit alongside the bottom: TabBar.
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trip.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        trip.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.group_outlined),
                    tooltip: 'Manage Members',
                    onPressed: () =>
                        ManageMembersSheet.show(context, trip: trip),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await AddEditTripSheet.show(context,
                            existingTrip: trip);
                      } else if (v == 'delete') {
                        await _confirmDeleteTrip(context, provider);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Trip'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: colorScheme.error),
                          const SizedBox(width: 10),
                          Text('Delete Trip',
                              style: TextStyle(color: colorScheme.error)),
                        ]),
                      ),
                    ],
                  ),
                ],
                // FlexibleSpaceBar now only has the background — no title here
                flexibleSpace: FlexibleSpaceBar(
                  background: _DashboardHeader(
                    trip: trip,
                    colorScheme: colorScheme,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.receipt_long_outlined),
                      text: 'Expenses',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    Tab(
                      icon: Icon(Icons.balance_outlined),
                      text: 'Balances',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                  ],
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: colorScheme.outlineVariant,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                ExpensesTab(tripId: widget.tripId),
                BalancesTab(tripId: widget.tripId),
              ],
            ),
          ),

          floatingActionButton: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            offset: _currentTab == 0 ? Offset.zero : const Offset(0, 2.5),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _currentTab == 0 ? 1.0 : 0.0,
              child: FloatingActionButton.extended(
                onPressed: _currentTab == 0
                    ? () => AddEditExpenseSheet.show(context, trip: trip)
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Expense',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteTrip(
      BuildContext context, TripProvider provider) async {
    final trip = provider.getTripById(widget.tripId);
    if (trip == null) return;

    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Delete "${trip.name}"?',
      message: 'This will permanently delete the trip and all its expenses.',
    );

    if (confirmed && context.mounted) {
      // FIX #3: Pop FIRST, then delete.
      // If we delete first, Consumer rebuilds immediately with trip == null
      // before Navigator.pop() runs, leaving a blank Scaffold on screen.
      // Popping first means we're already gone before the state changes.
      Navigator.of(context).pop();
      await provider.deleteTrip(widget.tripId);
    }
  }
}

// ── Expandable header background ──────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final dynamic trip;
  final ColorScheme colorScheme;

  const _DashboardHeader({required this.trip, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.7),
            colorScheme.secondaryContainer.withOpacity(0.5),
          ],
        ),
      ),
      // Anchor content to the bottom-left of the expanded area.
      // bottom: 58 clears the TabBar (~48px) + 10px breathing room.
      // No top padding needed — gradient fills the full background.
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 58),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (trip.destination != null &&
                  (trip.destination as String).isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        trip.destination as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              _MemberAvatarRow(trip: trip, colorScheme: colorScheme),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatarRow extends StatelessWidget {
  final dynamic trip;
  final ColorScheme colorScheme;

  const _MemberAvatarRow({required this.trip, required this.colorScheme});

  Color _colorFromIndex(int index) {
    const colors = [
      Color(0xFF4A6CF7), Color(0xFF22C55E), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
      Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF97316),
      Color(0xFF6366F1),
    ];
    return colors[index.clamp(0, 9)];
  }

  @override
  Widget build(BuildContext context) {
    const maxVisible = 5;
    final members = trip.members as List;
    final visible = members.take(maxVisible).toList();
    final overflow = members.length - maxVisible;
    final totalWidth =
        (visible.length * 24 + 8).toDouble() + (overflow > 0 ? 36 : 0);

    return Row(
      children: [
        SizedBox(
          height: 32,
          width: totalWidth,
          child: Stack(
            children: [
              ...visible.asMap().entries.map((e) {
                final m = e.value;
                final color = _colorFromIndex(m.colorIndex as int);
                return Positioned(
                  left: e.key * 24.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(
                        (m.name as String)[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (overflow > 0)
                Positioned(
                  left: visible.length * 24.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Text(
                        '+$overflow',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${members.length} ${members.length == 1 ? 'member' : 'members'}',
          style:
              TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}