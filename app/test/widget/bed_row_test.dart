import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/theme/app_theme.dart';
import 'package:renttrack/widgets/bed_row.dart';
import 'package:renttrack/widgets/status_badge.dart';

Widget _host(Widget child) => MaterialApp(
      theme: appLightTheme,
      home: Scaffold(body: ListView(children: [child])),
    );

void main() {
  const occupied = Bed(
    id: 'b1',
    flatId: 'f1',
    label: 'Bed 1',
    defaultMonthlyRent: 4000,
    tenantId: 'p1',
  );
  const vacant = Bed(
    id: 'b2',
    flatId: 'f1',
    label: 'Bed 2',
    defaultMonthlyRent: 4000,
  );

  testWidgets('occupied row shows occupant name + rent, correct border color',
      (tester) async {
    await tester.pumpWidget(_host(BedRow(
      bed: occupied,
      occupantName: 'Alice',
      isOverdue: false,
    )));

    expect(find.text('Bed 1'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('AED 4000'), findsOneWidget);
    expect(find.text('Vacant'), findsNothing);

    final colors = appLightTheme.extension<AppStatusColors>()!;
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Bed 1'), matching: find.byType(Container)),
    );
    final border =
        (container.decoration as BoxDecoration).border as Border;
    expect(border.left.color, colors.neutral);
  });

  testWidgets('overdue occupied row uses the danger color', (tester) async {
    await tester.pumpWidget(_host(BedRow(
      bed: occupied,
      occupantName: 'Alice',
      isOverdue: true,
    )));

    final colors = appLightTheme.extension<AppStatusColors>()!;
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Bed 1'), matching: find.byType(Container)),
    );
    final border =
        (container.decoration as BoxDecoration).border as Border;
    expect(border.left.color, colors.danger);
  });

  testWidgets('vacant row shows "Vacant" + dashed border, tap target present',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(BedRow(
      bed: vacant,
      occupantName: null,
      isOverdue: false,
      onTap: () => tapped = true,
    )));

    expect(find.text('Vacant'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    // No rent shown for a vacant bed.
    expect(find.textContaining('AED'), findsNothing);
    // Dashed border painter is attached.
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.foregroundPainter is DashedBorderPainter),
      findsOneWidget,
    );
    // Tap target present and wired up.
    await tester.tap(find.text('Vacant'));
    expect(tapped, isTrue);
  });
}
