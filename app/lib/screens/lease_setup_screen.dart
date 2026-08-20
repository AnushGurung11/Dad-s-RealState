import 'package:flutter/material.dart';

import '../config.dart';
import '../models/lease_cheque_setting.dart';
import '../services/json_store.dart';
import '../services/notification_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/empty_state.dart';

/// Settings page: one row per flat, showing its lease cheque configuration.
/// Tapping a row opens a form to edit amount, owner name, due date and the
/// notify toggle. Every flat automatically has exactly one
/// [LeaseChequeSetting] (created when the flat is created); this page is where
/// the user fills it in.
class LeaseSetupScreen extends StatefulWidget {
  const LeaseSetupScreen({
    super.key,
    required this.store,
    required this.notifications,
  });

  final JsonStore store;
  final NotificationService notifications;

  @override
  State<LeaseSetupScreen> createState() => _LeaseSetupScreenState();
}

class _LeaseSetupScreenState extends State<LeaseSetupScreen> {
  LeaseChequeSetting _settingFor(String flatId) {
    final existing = widget.store.leaseChequeSettings
        .where((s) => s.flatId == flatId)
        .firstOrNull;
    if (existing != null) return existing;
    // Defensive: flats created before this feature shipped have no setting.
    // Create the default one so every flat always has exactly one.
    final now = DateTime.now();
    final created = LeaseChequeSetting(
      id: newId(),
      flatId: flatId,
      ownerName: '',
      amount: 0,
      nextDueDate: DateTime(now.year, now.month + 2, now.day),
    );
    widget.store.upsertChequeSetting(created);
    return created;
  }

  Future<void> _openEditor(LeaseChequeSetting setting) async {
    final updated = await showModalBottomSheet<LeaseChequeSetting>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChequeForm(setting: setting),
    );
    if (updated == null) return;
    setState(() {
      widget.store.upsertChequeSetting(updated);
    });
    await widget.notifications.syncFor(updated);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final flats = widget.store.flats;
    return Scaffold(
      appBar: AppBar(title: const Text('Lease Setup')),
      body: flats.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Add a flat to set up its recurring lease cheque.',
              actionLabel: 'Add flat',
              onAction: _noop,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: flats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final flat = flats[index];
                final setting = _settingFor(flat.id);
                final owner = setting.ownerName.trim().isEmpty
                    ? 'No owner set'
                    : setting.ownerName;
                return Card(
                  child: ListTile(
                    title: Text(flat.name),
                    subtitle: Text(
                      '$owner\n'
                      '${formatMoneyShort(setting.amount)} · '
                      'due ${_formatDate(setting.nextDueDate)}',
                    ),
                    trailing: Switch(
                      value: setting.notifyEnabled,
                      onChanged: (value) async {
                        final updated =
                            setting.copyWith(notifyEnabled: value);
                        setState(() {
                          widget.store.upsertChequeSetting(updated);
                        });
                        await widget.notifications.syncFor(updated);
                      },
                    ),
                    onTap: () => _openEditor(setting),
                  ),
                );
              },
            ),
    );
  }

  static void _noop() {}
}

class _ChequeForm extends StatefulWidget {
  const _ChequeForm({required this.setting});

  final LeaseChequeSetting setting;

  @override
  State<_ChequeForm> createState() => _ChequeFormState();
}

class _ChequeFormState extends State<_ChequeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ownerName;
  late final TextEditingController _amount;
  late DateTime _nextDueDate;
  late bool _notifyEnabled;

  @override
  void initState() {
    super.initState();
    _ownerName = TextEditingController(text: widget.setting.ownerName);
    _amount = TextEditingController(
      text: widget.setting.amount == 0
          ? ''
          : widget.setting.amount.toStringAsFixed(0),
    );
    _nextDueDate = widget.setting.nextDueDate;
    _notifyEnabled = widget.setting.notifyEnabled;
  }

  @override
  void dispose() {
    _ownerName.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked == null) return;
    setState(() => _nextDueDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      widget.setting.copyWith(
        ownerName: _ownerName.text.trim(),
        amount: double.tryParse(_amount.text.trim()) ?? 0,
        nextDueDate: _nextDueDate,
        notifyEnabled: _notifyEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Lease cheque',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ownerName,
              decoration: const InputDecoration(
                labelText: 'Owner name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${AppConfig.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                'Next due: ${_nextDueDate.day}/${_nextDueDate.month}/${_nextDueDate.year}',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Notify 3 days before'),
              value: _notifyEnabled,
              onChanged: (value) => setState(() => _notifyEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}