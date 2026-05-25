import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ADD / EDIT TRIP SHEET
///
/// A full modal bottom sheet used for both creating a new trip and editing
/// an existing one. When [existingTrip] is null, it's in "create" mode.
///
/// Fields:
///   • Trip name (required)
///   • Destination / subtitle (optional)
///   • Emoji picker (horizontal scroll of presets)
///   • Member names (dynamic add/remove rows — minimum 1)
/// ─────────────────────────────────────────────────────────────────────────────
class AddEditTripSheet extends StatefulWidget {
  /// Pass an existing trip to enter edit mode. Null = create mode.
  final Trip? existingTrip;

  const AddEditTripSheet({super.key, this.existingTrip});

  /// Convenience static method — shows the sheet and returns the result.
  static Future<void> show(BuildContext context, {Trip? existingTrip}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTripSheet(existingTrip: existingTrip),
    );
  }

  @override
  State<AddEditTripSheet> createState() => _AddEditTripSheetState();
}

class _AddEditTripSheetState extends State<AddEditTripSheet> {
  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();

  // Each string in this list maps to a member name text field
  final List<TextEditingController> _memberControllers = [];

  String _selectedEmoji = '🧳';
  bool _isLoading = false;

  bool get _isEditMode => widget.existingTrip != null;

  // ── Emoji palette ──────────────────────────────────────────────────────────
  static const _emojiOptions = [
    '🧳', '🏔️', '🚗', '✈️', '🏕️', '🚂', '🛵', '🏖️',
    '🌄', '🗺️', '⛺', '🚴', '🤿', '🎿', '🛶', '🌍',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      // Populate fields from existing trip
      _nameController.text = widget.existingTrip!.name;
      _destinationController.text =
          widget.existingTrip!.destination ?? '';
      _selectedEmoji = widget.existingTrip!.emoji;
      // Note: Member editing is handled separately (in TripDashboard)
      // so in edit mode, we don't show the members section.
    } else {
      // Create mode — start with 3 empty member fields
      _memberControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    for (final c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<TripProvider>();

    try {
      if (_isEditMode) {
        await provider.updateTrip(
          tripId: widget.existingTrip!.id,
          name: _nameController.text,
          destination: _destinationController.text,
          emoji: _selectedEmoji,
        );
      } else {
        // Collect non-empty member names
        final memberNames = _memberControllers
            .map((c) => c.text.trim())
            .where((n) => n.isNotEmpty)
            .toList();

        await provider.createTrip(
          name: _nameController.text,
          destination: _destinationController.text,
          emoji: _selectedEmoji,
          memberNames: memberNames,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Member field management ────────────────────────────────────────────────
  void _addMemberField() {
    setState(() => _memberControllers.add(TextEditingController()));
  }

  void _removeMemberField(int index) {
    if (_memberControllers.length <= 1) return;
    setState(() {
      _memberControllers[index].dispose();
      _memberControllers.removeAt(index);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // Pad bottom for keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ───────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────────
              Text(
                _isEditMode ? 'Edit Trip' : 'New Trip',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // ── Emoji Picker ─────────────────────────────────────────────
              Text(
                'Choose an icon',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _EmojiPicker(
                options: _emojiOptions,
                selected: _selectedEmoji,
                onSelected: (e) => setState(() => _selectedEmoji = e),
              ),

              const SizedBox(height: 20),

              // ── Trip Name ────────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Trip Name *',
                  hintText: 'e.g. Khunjerab Tour 2026',
                  prefixIcon: Icon(Icons.luggage_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a trip name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ── Destination ──────────────────────────────────────────────
              TextFormField(
                controller: _destinationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Destination (optional)',
                  hintText: 'e.g. Hunza Valley, KPK',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              // ── Members section (create mode only) ───────────────────────
              if (!_isEditMode) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Members',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'You can add more later',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._buildMemberFields(colorScheme),
                const SizedBox(height: 10),
                // Add member button
                TextButton.icon(
                  onPressed: _addMemberField,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add another member'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Submit button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode ? 'Save Changes' : 'Create Trip',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMemberFields(ColorScheme colorScheme) {
    return List.generate(_memberControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            // Color dot for visual distinction
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _memberColor(index, colorScheme),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _memberControllers[index],
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Member ${index + 1} name',
                  isDense: true,
                ),
              ),
            ),
            // Remove button (hide when only 1 field)
            if (_memberControllers.length > 1)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: colorScheme.error,
                ),
                onPressed: () => _removeMemberField(index),
                padding: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    });
  }

  Color _memberColor(int index, ColorScheme cs) {
    const colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.amber, Colors.pink,
      Colors.cyan, Colors.indigo,
    ];
    return colors[index % colors.length];
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// EMOJI PICKER
/// Horizontally scrollable row of emoji options.
/// ─────────────────────────────────────────────────────────────────────────────
class _EmojiPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _EmojiPicker({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final emoji = options[i];
          final isSelected = emoji == selected;
          return GestureDetector(
            onTap: () => onSelected(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}
