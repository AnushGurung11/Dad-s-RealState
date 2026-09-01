import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/absconded_service.dart';
import '../services/renewal_service.dart';
import '../services/store_scope.dart';
import '../services/tenant_deletion_service.dart';
import '../services/tenure_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';
import '../widgets/status_badge.dart';

/// Tenant detail: tenure fields, current balance and payment history, plus
/// the lifecycle actions — Edit, Renew stay, Mark as absconded and Delete
/// (only when there is no financial history to preserve).
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  void _refresh() => setState(() {});

  Future<void> _openRenewDialog() async {
    final months = await showDialog<int>(
      context: context,
      builder: (dialogContext) => const _RenewDialog(),
    );
    if (months == null || !mounted) return;
    try {
      RenewalService(StoreScope.of(context)).renew(
        personId: widget.personId,
        additionalMonths: months,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Stay extended by $months month(s)')));
    } on RenewalException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
    _refresh();
  }

  Future<void> _openEdit() async {
    await Navigator.pushNamed(
      context,
      Routes.tenantsEdit,
      arguments: widget.personId,
    );
    if (mounted) _refresh();
  }

  Future<void> _openTermination() async {
    await Navigator.pushNamed(
      context,
      Routes.tenantsTerminate,
      arguments: widget.personId,
    );
    if (mounted) _refresh();
  }

  /// Absconding requires a short note ("why/what happened"); it frees the
  /// bed immediately while keeping every payment record.
  Future<void> _markAbsconded() async {
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AbscondedDialog(),
    );
    if (note == null || !mounted) return;
    try {
      AbscondedService(StoreScope.of(context))
          .markAbsconded(personId: widget.personId, statusNote: note);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Marked as absconded. Their bed is free again.')));
    } on AbscondedException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
    _refresh();
  }

  Future<void> _delete() async {
    final store = StoreScope.of(context);
    final person =
        store.people.where((p) => p.id == widget.personId).firstOrNull;
    if (person == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${person.name}?'),
        content: const Text(
            'They have no payment records. This creation mistake will be '
            'removed entirely — there is nothing to preserve.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_delete_person'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    store.runBatched(() {
      store.deletePerson(widget.personId);
      // Free their bed too — a creation mistake leaves nothing behind.
      final bed =
          store.beds.where((b) => b.tenantId == widget.personId).firstOrNull;
      if (bed != null) {
        store.upsertBed(bed.copyWith(clearTenantId: true));
      }
    });
    Navigator.pop(context);
  }

  String? _dateText(DateTime? date) => date == null
      ? null
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person =
        store.people.where((p) => p.id == widget.personId).firstOrNull;
    if (person == null) {
      return const Scaffold(body: Center(child: Text('Tenant not found.')));
    }

    final rent = person.monthlyRent ?? 0;
    final balance = TenureService.remainingBalance(person, rent, store.payments);
    final payments = store.payments
        .where((p) => p.personId == person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    final active = person.status == PersonStatus.active;
    final absconded = person.isAbsconded;
    // Hard delete is only for payment-free people — a creation mistake with
    // nothing worth preserving.
    final canHardDelete =
        TenantDeletionService.canHardDelete(person, store.payments);

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            key: const Key('edit_tenant_action'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit details',
            onPressed: _openEdit,
          ),
          if (active || !canHardDelete)
            PopupMenuButton<String>(
              key: const Key('person_actions_menu'),
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case 'renew':
                    _openRenewDialog();
                    break;
                  case 'absconded':
                    _markAbsconded();
                    break;
                  case 'terminate':
                    _openTermination();
                    break;
                  case 'delete':
                    _delete();
                    break;
                }
              },
              itemBuilder: (_) => [
                if (active && person.isActiveTenant)
                  const PopupMenuItem(
                    value: 'renew',
                    child: ListTile(
                      leading: Icon(Icons.update),
                      title: Text('Renew stay'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (active)
                  const PopupMenuItem(
                    value: 'absconded',
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_outlined),
                      title: Text('Mark as absconded'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (active && person.isActiveTenant)
                  const PopupMenuItem(
                    value: 'terminate',
                    child: ListTile(
                      leading: Icon(Icons.logout_outlined),
                      title: Text('End tenure early'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (canHardDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Theme.of(context).extension<AppStatusColors>()!.danger),
                      title: Text('Delete tenant',
                          style: TextStyle(
                              color: Theme.of(context).extension<AppStatusColors>()!.danger)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!active)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  absconded ? Icons.warning_amber_outlined : Icons.archive_outlined,
                  color: absconded
                      ? Theme.of(context).extension<AppStatusColors>()!.danger
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(absconded ? 'Absconded tenant' : 'Left')),
                    StatusBadge(
                      kind: absconded ? StatusKind.danger : StatusKind.neutral,
                      label: absconded ? 'Absconded' : 'Left',
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${absconded ? 'Flagged' : 'Left'} on '
                      '${_dateText(person.statusDate) ?? '—'}. '
                      'Their history is kept.',
                    ),
                    if (absconded &&
                        (person.statusNote?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Note: ${person.statusNote}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .extension<AppStatusColors>()!
                                .danger,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: PersonAvatar(
                      photoPath: person.photoPath,
                      name: person.name,
                      radius: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(person.name,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 16),
                  _Field(label: 'Contact', value: person.contact),
                  _Field(label: 'Workplace / info', value: person.workplaceOrInfo),
                  _Field(label: 'Monthly rent', value: formatMoneyShort(rent)),
                  _Field(
                      label: 'Deposit',
                      value: formatMoneyShort(person.depositAmount ?? 0)),
                  _Field(label: 'Join date', value: _dateText(person.joinDate)),
                  _Field(
                      label: 'Vacated date',
                      value: _dateText(person.vacatedDate)),
                  _Field(label: 'Notes', value: person.others),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Remaining balance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          formatMoneySigned(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!active && absconded && (person.statusNote?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'This tenant has payment history — delete is unavailable. '
                'Use "Mark as absconded" or let their stay end instead.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Small form asking how many months to add to the planned stay.
class _RenewDialog extends StatefulWidget {
  const _RenewDialog();

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  final _controller = TextEditingController(text: '6');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _months {
    final value = int.tryParse(_controller.text.trim());
    return (value == null || value < 1) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renew stay'),
      content: TextFormField(
        key: const Key('renew_months_field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Additional months',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _months == null ? null : () => Navigator.pop(context, _months),
          child: const Text('Extend'),
        ),
      ],
    );
  }
}

/// Requires a short note explaining the absconding before it will submit.
class _AbscondedDialog extends StatefulWidget {
  const _AbscondedDialog();

  @override
  State<_AbscondedDialog> createState() => _AbscondedDialogState();
}

class _AbscondedDialogState extends State<_AbscondedDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _hasNote => _noteController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark as absconded'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Their bed frees up immediately and all records are kept. '
              'Briefly note why / what happened:'),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('absconded_note_field'),
            controller: _noteController,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              hintText: 'e.g. left owing 1.5 months rent',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_absconded'),
          onPressed:
              _hasNote ? () => Navigator.pop(context, _noteController.text.trim()) : null,
          child: const Text('Mark absconded'),
        ),
      ],
    );
  }
}
