import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/expense_model.dart';
import '../../../models/member_model.dart';
import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../shared/member_avatar.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ADD / EDIT EXPENSE SHEET
///
/// Modal bottom sheet for logging or editing an expense.
///
/// Fields:
///   • Title / description (required)
///   • Amount (required, numeric)
///   • Paid By  — single-select dropdown of trip members
///   • Split Among — multi-select chips (defaults to ALL members)
///   • Optional note
/// ─────────────────────────────────────────────────────────────────────────────
class AddEditExpenseSheet extends StatefulWidget {
  final Trip trip;
  final Expense? existingExpense; // null = create mode

  const AddEditExpenseSheet({
    super.key,
    required this.trip,
    this.existingExpense,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    Expense? existingExpense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditExpenseSheet(
        trip: trip,
        existingExpense: existingExpense,
      ),
    );
  }

  @override
  State<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _AddEditExpenseSheetState extends State<AddEditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _paidByMemberId;
  late Set<String> _splitAmongIds;
  bool _isLoading = false;

  bool get _isEditMode => widget.existingExpense != null;
  List<Member> get _members => widget.trip.members;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final e = widget.existingExpense!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _noteController.text = e.note ?? '';
      _paidByMemberId = e.paidByMemberId;
      _splitAmongIds = Set.from(e.splitAmongIds);
    } else {
      // Default: first member pays, everyone splits
      _paidByMemberId =
          _members.isNotEmpty ? _members.first.id : null;
      _splitAmongIds = {for (final m in _members) m.id};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toggleSplitMember(String memberId) {
    setState(() {
      if (_splitAmongIds.contains(memberId)) {
        // Always keep at least one person in the split
        if (_splitAmongIds.length > 1) {
          _splitAmongIds.remove(memberId);
        }
      } else {
        _splitAmongIds.add(memberId);
      }
    });
  }

  void _selectAll() =>
      setState(() => _splitAmongIds = {for (final m in _members) m.id});

  void _clearAll() {
    // Keep only the payer selected as minimum
    setState(() {
      _splitAmongIds = _paidByMemberId != null
          ? {_paidByMemberId!}
          : {_members.first.id};
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByMemberId == null) {
      _showSnack('Please select who paid.');
      return;
    }
    if (_splitAmongIds.isEmpty) {
      _showSnack('Please select at least one person to split with.');
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<TripProvider>();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    try {
      if (_isEditMode) {
        await provider.updateExpense(
          tripId: widget.trip.id,
          expenseId: widget.existingExpense!.id,
          title: _titleController.text,
          amount: amount,
          paidByMemberId: _paidByMemberId!,
          splitAmongIds: _splitAmongIds.toList(),
          note: _noteController.text,
        );
      } else {
        await provider.addExpense(
          tripId: widget.trip.id,
          title: _titleController.text,
          amount: amount,
          paidByMemberId: _paidByMemberId!,
          splitAmongIds: _splitAmongIds.toList(),
          note: _noteController.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Live per-person share preview
    final amount =
        double.tryParse(_amountController.text.trim()) ?? 0.0;
    final share = _splitAmongIds.isEmpty
        ? 0.0
        : amount / _splitAmongIds.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
              // Handle bar
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

              // Title row
              Row(
                children: [
                  Text(
                    _isEditMode ? 'Edit Expense' : 'Add Expense',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Live share preview badge
                  if (share > 0)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PKR ${share.toStringAsFixed(0)}/person',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Title field ──────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Fuel for Bikes, Dinner',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 14),

              // ── Amount field ─────────────────────────────────────────────
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'))
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (PKR) *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setState(() {}), // refresh share preview
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Paid By ──────────────────────────────────────────────────
              _SectionLabel(label: 'Paid By', colorScheme: colorScheme),
              const SizedBox(height: 10),
              _PaidByDropdown(
                members: _members,
                selectedId: _paidByMemberId,
                onChanged: (id) => setState(() => _paidByMemberId = id),
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 20),

              // ── Split Among ──────────────────────────────────────────────
              Row(
                children: [
                  _SectionLabel(
                      label: 'Split Among', colorScheme: colorScheme),
                  const Spacer(),
                  // Select all / clear shortcuts
                  TextButton(
                    onPressed: _selectAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('All',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.primary)),
                  ),
                  Text('·',
                      style:
                          TextStyle(color: colorScheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Clear',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.map((m) {
                  return MemberSelectChip(
                    name: m.name,
                    colorIndex: m.colorIndex,
                    isSelected: _splitAmongIds.contains(m.id),
                    onTap: () => _toggleSplitMember(m.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Optional Note ────────────────────────────────────────────
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Any extra details…',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.notes_outlined),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              // ── Submit ───────────────────────────────────────────────────
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
                          _isEditMode ? 'Save Changes' : 'Add Expense',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionLabel({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Custom "Paid By" selector — shows member avatar + name in a card-style row.
class _PaidByDropdown extends StatelessWidget {
  final List<Member> members;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final ColorScheme colorScheme;

  const _PaidByDropdown({
    required this.members,
    required this.selectedId,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          onChanged: onChanged,
          items: members.map((m) {
            return DropdownMenuItem<String>(
              value: m.id,
              child: Row(
                children: [
                  MemberAvatar(
                      name: m.name, colorIndex: m.colorIndex, size: 32),
                  const SizedBox(width: 10),
                  Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
