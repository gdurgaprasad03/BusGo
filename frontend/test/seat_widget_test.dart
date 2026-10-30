import 'package:busgo/widgets/seat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(SeatState state, VoidCallback onTap) => MaterialApp(
        home: Scaffold(body: Center(child: SeatWidget(label: '3B', state: state, onTap: onTap))),
      );

  testWidgets('available seat can be tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(SeatState.available, () => taps++));
    await tester.tap(find.text('3B'));
    expect(taps, 1);
  });

  testWidgets('booked seat can NOT be tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(SeatState.booked, () => taps++));
    await tester.tap(find.text('3B'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('legend explains the three seat colours', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SeatLegend())));
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
  });
}
