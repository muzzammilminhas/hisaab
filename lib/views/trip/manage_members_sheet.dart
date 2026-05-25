import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../shared/delete_confirm_dialog.dart';
import '../shared/member_avatar.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MANAGE MEMBERS SHEET
///
/// Accessible from the Trip Dashboard app bar.
/// Lists all members with an option to rename or remove each.
/// Also provides an "Add Member" input at the bottom.
/// ─────────────────────────────────────────────────────────────────────────────
class ManageMembersSheet extends StatefulWidget {
  final Trip trip;

  const ManageMembersSheet({super.key, required this.trip});

  static Future<void> show(BuildContext context, {required Trip trip}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManageMembersSheet(trip: trip),
    );
  }

  @override
  State<ManageMembersSheet> createState() => _ManageMembersSheetState();
}

class _ManageMembersSheetState extends State<ManageMembersSheet> {
  final _addController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isAdding = true);
    await context.read<TripProvider>().addMember(
          tripId: widget.trip.id,
          memberName: name,
        );
    _addController.clear();
    if (mounted) setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final trip = provider.getTripById(widget.trip.id) ?? widget.trip;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Members',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.members.length} people in ${trip.name}',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Member list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trip.members.length,
                  itemBuilder: (context, index) {
                    final member = trip.members[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      leading: MemberAvatar(
                          name: member.name, colorIndex: member.colorIndex),
                      title: Text(member.name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rename
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 18,
                                color: colorScheme.onSurfaceVariant),
                            onPressed: () =>
                                _showRenameDialog(context, trip.id, member.id,
                                    member.name, provider),
                          ),
                          // Remove (disable if only 1 member)
                          IconButton(
                            icon: Icon(Icons.person_remove_outlined,
                                size: 18,
                                color: trip.members.length > 1
                                    ? colorScheme.error
                                    : colorScheme.outlineVariant),
                            onPressed: trip.members.length > 1
                                ? () => _confirmRemove(
                                    context, trip.id, member.id, member.name,
                                    provider)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Add member input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _addController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Add new member…',
                          prefixIcon: Icon(Icons.person_add_outlined),
                          isDense: true,
                        ),
                        onFieldSubmitted: (_) => _addMember(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isAdding ? null : _addMember,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String tripId,
    String memberId,
    String currentName,
    TripProvider provider,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Member'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rename')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await provider.updateMemberName(
          tripId: tripId, memberId: memberId, newName: ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _confirmRemove(
    BuildContext context,
    String tripId,
    String memberId,
    String memberName,
    TripProvider provider,
  ) async {
    final confirmed = await DeleteConfirmDialog.show(
      context,
      title: 'Remove $memberName?',
      message:
          'They will be removed from all expense splits in this trip.',
    );
    if (confirmed && context.mounted) {
      await provider.removeMember(tripId: tripId, memberId: memberId);
    }
  }
}
