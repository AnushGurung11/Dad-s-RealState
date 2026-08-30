import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/widgets/bed_row.dart';
import 'package:lucky/widgets/status_badge.dart';

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

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Bed 1'), matching: find.byType(Container)),
    );
    final decoration = container.decoration as BoxDecoration;
    // Spec: dark surface with subtle border, no left accent
    expect(decoration.color, appSurface1);
    expect(decoration.border, isA<Border>());
  });

  testWidgets('overdue occupied row uses the danger color', (tester) async {
    await tester.pumpWidget(_host(BedRow(
      bed: occupied,
      occupantName: 'Alice',
      isOverdue: true,
    )));

    // Overdue now shows a badge instead of left border
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('AED 4000'), findsOneWidget);
  });

  testWidgets('vacant row shows "Vacant" + Assign affordance, tap target present',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(BedRow(
      bed: vacant,
      occupantName: null,
      isOverdue: false,
      onTap: () => tapped = true,
    )));

    expect(find.text('Vacant'), findsOneWidget);
    expect(find.text('Assign →'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    // No rent shown for a vacant bed.
    expect(find.textContaining('AED'), findsNothing);
    // Tap target present and wired up.
    await tester.tap(find.text('Vacant'));
    expect(tapped, isTrue);
  });
}
