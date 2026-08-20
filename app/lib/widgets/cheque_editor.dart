import 'package:flutter/material.dart';

import '../config.dart';
import '../models/lease_cheque_setting.dart';

/// Opens a bottom-sheet editor for a flat's [LeaseChequeSetting].
/// Returns the updated setting, or null if cancelled.
Future<LeaseChequeSetting?> showChequeEditor(
  BuildContext context,
  LeaseChequeSetting setting,
) {
  return showModalBottomSheet<LeaseChequeSetting>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChequeEditor(setting: setting),
  );
}

class _ChequeEditor extends StatefulWidget {
  const _ChequeEditor({required this.setting});

  final LeaseChequeSetting setting;

  @override
  State<_ChequeEditor> createState() => _ChequeEditorState();
}

class _ChequeEditorState extends State<_ChequeEditor> {
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