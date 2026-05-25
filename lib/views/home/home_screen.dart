import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';
import '../shared/delete_confirm_dialog.dart';
import '../trip/trip_dashboard.dart';
import 'add_edit_trip_sheet.dart';
import 'widgets/empty_state.dart';
import 'widgets/trip_card.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// HOME SCREEN
///
/// The root screen of the app. Shows all trips in a scrollable list.
/// - Animated app bar with stats
/// - FAB opens AddEditTripSheet
/// - Trips are rendered as TripCard widgets
/// - Empty state shown when no trips exist
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const _HomeBody(),
      floatingActionButton: _AddTripFAB(),
    );
  }
}

// ── Main body with CustomScrollView (collapsible header) ─────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trips = provider.trips;

        return CustomScrollView(
          slivers: [
            // ── Collapsible App Bar ──────────────────────────────────────────
            SliverAppBar.large(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Trips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (trips.isNotEmpty)
                      Text(
                        '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                // Subtle background gradient for the expanded header
                background: _HeaderBackground(colorScheme: colorScheme),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            if (trips.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return _AnimatedTripCard(
                      key: ValueKey(trip.id),
                      index: index,
                      child: TripCard(
                        trip: trip,
                        onTap: () => _openTrip(context, trip.id),
                        onEdit: () => AddEditTripSheet.show(
                          context,
                          existingTrip: trip,
                        ),
                        onDelete: () => _confirmDelete(context, trip.id, trip.name),
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

  void _openTrip(BuildContext context, String tripId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDashboard(tripId: tripId),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String tripId,
    String tripName,
  ) async {
    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Delete "$tripName"?',
      message:
          'This will permanently delete the trip, all its members and expenses. This cannot be undone.',
    );

    if (confirmed && context.mounted) {
      await context.read<TripProvider>().deleteTrip(tripId);
    }
  }
}

// ── Header background with subtle decorative gradient ────────────────────────

class _HeaderBackground extends StatelessWidget {
  final ColorScheme colorScheme;

  const _HeaderBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.6),
            colorScheme.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle blobs
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 70,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: colorScheme.secondary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated list item wrapper (staggered entrance) ──────────────────────────

class _AnimatedTripCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedTripCard({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedTripCard> createState() => _AnimatedTripCardState();
}

class _AnimatedTripCardState extends State<_AnimatedTripCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Stagger: each card starts slightly after the previous
    final delay = Duration(milliseconds: widget.index * 60);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _AddTripFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => AddEditTripSheet.show(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Trip',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
