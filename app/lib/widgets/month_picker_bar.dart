import 'package:flutter/material.dart';

import '../config.dart';
import '../services/month_selection.dart';
import '../services/store_scope.dart';

/// Compact month navigator: `‹ Sep 2026 ›` plus a jump-to menu listing every
/// month that actually holds data, and a "This month" shortcut once the
/// selection has moved off the live month.
///
/// Renders nothing when no [MonthScope] is mounted, so screens can drop it in
/// unconditionally.
class MonthPickerBar extends StatelessWidget {
  const MonthPickerBar({super.key, this.showJumpMenu = true});

  final bool showJumpMenu;

  @override
  Widget build(BuildContext context) {
    final selection = MonthScope.maybeOf(context);
    if (selection == null) return const SizedBox.shrink();

    // The jump menu needs data; without a store we still let the arrows work.
    final store = StoreScope.maybeOf(context);
    final months = (showJumpMenu && store != null)
        ? MonthSelection.monthsWithData(store)
        : const <String>[];
    // Always offer the current month as a jump target, so the menu is never
    // empty just because no other month has data yet.
    final targets = <String>{
      monthKey(DateTime.now()),
      ...months,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final hasMenu = targets.length > 1;
    final selected = selection.month;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _StepButton(
            key: const Key('month_prev'),
            icon: Icons.chevron_left,
            tooltip: 'Previous month',
            onPressed: selection.previous,
          ),
          Expanded(
            child: Center(
              child: hasMenu
                  ? _JumpMenu(
                      months: targets,
                      selected: selected,
                      onSelected: selection.select,
                    )
                  : Text(
                      MonthSelection.label(selected),
                      key: const Key('month_picker_label'),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          _StepButton(
            key: const Key('month_next'),
            icon: Icons.chevron_right,
            tooltip: 'Next month',
            onPressed: selection.next,
          ),
          if (!selection.isCurrentMonth) ...[
            const SizedBox(width: 4),
            TextButton(
              key: const Key('month_today'),
              onPressed: selection.reset,
              child: const Text('This month'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class _JumpMenu extends StatelessWidget {
  const _JumpMenu({
    required this.months,
    required this.selected,
    required this.onSelected,
  });

  final List<String> months;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('month_jump_menu'),
      tooltip: 'Jump to month',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final month in months)
          PopupMenuItem<String>(
            key: ValueKey('month_option_$month'),
            value: month,
            child: Row(
              children: [
                Icon(
                  month == selected ? Icons.check : Icons.calendar_today_outlined,
                  size: 16,
                  color: month == selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: 8),
                Text(MonthSelection.label(month)),
              ],
            ),
          ),
      ],
      child: Chip(
        label: Text(
          MonthSelection.label(selected),
          key: const Key('month_picker_label'),
        ),
        avatar: const Icon(Icons.calendar_month_outlined, size: 18),
      ),
    );
  }
}
