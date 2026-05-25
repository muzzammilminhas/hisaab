import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// EMPTY STATE WIDGET
///
/// Displayed on the Home Screen when the user has no trips yet.
///
/// FIX: Was using SingleTickerProviderStateMixin but created TWO controllers.
/// Corrected to TickerProviderStateMixin which supports multiple tickers.
/// Both controllers are properly stored and disposed.
/// ─────────────────────────────────────────────────────────────────────────────
class EmptyState extends StatefulWidget {
  const EmptyState({super.key});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    // TickerProviderStateMixin (NOT Single-) — we create TWO AnimationControllers:
    //   _floatController → infinite looping float on the luggage icon
    //   _fadeController  → one-shot fade-in when the screen first mounts
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ── Float: gentle up/down infinite loop ──────────────────────────────────
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // ── Fade: single forward run on mount ────────────────────────────────────
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    // Both controllers must be disposed to release ticker resources
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Floating hero icon ───────────────────────────────────────
              AnimatedBuilder(
                animation: _floatController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.25),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🧳', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Headline ─────────────────────────────────────────────────
              Text(
                'No trips yet!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // ── Supporting copy ──────────────────────────────────────────
              Text(
                'Plan your next adventure.\nAdd a trip to start splitting expenses with friends.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── Decorative hint chips ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HintChip(icon: '🏔️', label: 'Treks'),
                  const SizedBox(width: 8),
                  _HintChip(icon: '🚗', label: 'Road Trips'),
                  const SizedBox(width: 8),
                  _HintChip(icon: '🏕️', label: 'Camping'),
                ],
              ),

              const SizedBox(height: 80), // breathing room above FAB
            ],
          ),
        ),
      ),
    );
  }
}

/// Small decorative chip shown in the empty state
class _HintChip extends StatelessWidget {
  final String icon;
  final String label;

  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
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
      ),
    );
  }
}
