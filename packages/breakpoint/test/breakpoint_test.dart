import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoint', () {
    test('xsmall / smallHandset (0-359)', () {
      final b = Breakpoint(
        columns: 4,
        device: LayoutClass.smallHandset,
        gutters: 16,
        margin: 16,
        window: WindowSize.xsmall,
      );
      _testBreakpoint(300, b);
      _testBreakpoint(359, b);
    });

    test('xsmall / mediumHandset (360-399)', () {
      final b = Breakpoint(
        columns: 4,
        device: LayoutClass.mediumHandset,
        gutters: 16,
        margin: 16,
        window: WindowSize.xsmall,
      );
      _testBreakpoint(360, b);
      _testBreakpoint(399, b);
    });

    test('xsmall / largeHandset (400-479)', () {
      final b = Breakpoint(
        columns: 4,
        device: LayoutClass.largeHandset,
        gutters: 16,
        margin: 16,
        window: WindowSize.xsmall,
      );
      _testBreakpoint(400, b);
      _testBreakpoint(479, b);
    });

    test('xsmall / largeHandset (480-599)', () {
      final b = Breakpoint(
        columns: 4,
        device: LayoutClass.largeHandset,
        gutters: 16,
        margin: 16,
        window: WindowSize.xsmall,
      );
      _testBreakpoint(480, b);
      _testBreakpoint(599, b);
    });

    test('small / smallTablet (600-719)', () {
      final b = Breakpoint(
        columns: 8,
        device: LayoutClass.smallTablet,
        gutters: 16,
        margin: 16,
        window: WindowSize.small,
      );
      _testBreakpoint(600, b);
      _testBreakpoint(719, b);
    });

    test('small / largeTablet (720-839)', () {
      final b = Breakpoint(
        columns: 8,
        device: LayoutClass.largeTablet,
        gutters: 24,
        margin: 24,
        window: WindowSize.small,
      );
      _testBreakpoint(720, b);
      _testBreakpoint(839, b);
    });

    test('small / largeTablet (840-959)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.largeTablet,
        gutters: 24,
        margin: 24,
        window: WindowSize.small,
      );
      _testBreakpoint(840, b);
      _testBreakpoint(959, b);
    });

    test('small / largeTablet (960-1023)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.largeTablet,
        gutters: 24,
        margin: 24,
        window: WindowSize.small,
      );
      _testBreakpoint(960, b);
      _testBreakpoint(1023, b);
    });

    test('medium / desktop (1024-1279)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.desktop,
        gutters: 24,
        margin: 24,
        window: WindowSize.medium,
      );
      _testBreakpoint(1024, b);
      _testBreakpoint(1279, b);
    });

    test('medium / desktop (1280-1439)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.desktop,
        gutters: 24,
        margin: 24,
        window: WindowSize.medium,
      );
      _testBreakpoint(1280, b);
      _testBreakpoint(1439, b);
    });

    test('large / desktop (1440-1599)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.desktop,
        gutters: 24,
        margin: 24,
        window: WindowSize.large,
      );
      _testBreakpoint(1440, b);
      _testBreakpoint(1599, b);
    });

    test('large / desktop (1600-1919)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.desktop,
        gutters: 24,
        margin: 24,
        window: WindowSize.large,
      );
      _testBreakpoint(1600, b);
      _testBreakpoint(1919, b);
    });

    test('xlarge / desktop (1920+)', () {
      final b = Breakpoint(
        columns: 12,
        device: LayoutClass.desktop,
        gutters: 24,
        margin: 24,
        window: WindowSize.xlarge,
      );
      _testBreakpoint(1920, b);
      _testBreakpoint(3000, b);
    });

    test('Orientation Landscape (+120 width behavior)', () {
      // 300 base width + 120 buffer = 420 effective width
      // 420 falls into largeHandset (400-479)
      final constraints = BoxConstraints(maxWidth: 300, maxHeight: 200);
      final breakpoint = Breakpoint.fromConstraints(constraints);
      expect(breakpoint.device, LayoutClass.largeHandset);
    });
  });

  group('Comparators', () {
    test('WindowSize', () {
      expect(WindowSize.xsmall < WindowSize.small, true);
      expect(WindowSize.small < WindowSize.medium, true);
      expect(WindowSize.medium < WindowSize.large, true);
      expect(WindowSize.large < WindowSize.xlarge, true);

      expect(WindowSize.xlarge > WindowSize.large, true);
      expect(WindowSize.small <= WindowSize.small, true);
      expect(WindowSize.small >= WindowSize.small, true);
    });
    test('LayoutClass', () {
      expect(LayoutClass.smallHandset < LayoutClass.mediumHandset, true);
      expect(LayoutClass.mediumHandset < LayoutClass.largeHandset, true);
      expect(LayoutClass.largeHandset < LayoutClass.smallTablet, true);
      expect(LayoutClass.smallTablet < LayoutClass.largeTablet, true);
      expect(LayoutClass.largeTablet < LayoutClass.desktop, true);

      expect(LayoutClass.desktop > LayoutClass.largeTablet, true);
      expect(LayoutClass.desktop >= LayoutClass.desktop, true);
      expect(LayoutClass.desktop <= LayoutClass.desktop, true);
    });
  });

  group('BreakpointBuilder', () {
    testWidgets('Builds with correct breakpoint', (tester) async {
      Breakpoint? capturedBreakpoint;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 800,
              height: 600,
              child: BreakpointBuilder(
                builder: (context, breakpoint) {
                  capturedBreakpoint = breakpoint;
                  return Container();
                },
              ),
            ),
          ),
        ),
      );

      // Width 800(landscape +120 -> 920) falls into largeTablet (840-959), columns 12, gutter 24, margin 24
      expect(capturedBreakpoint, isNotNull);
      expect(capturedBreakpoint!.columns, 12);
      expect(capturedBreakpoint!.gutters, 24);
      expect(capturedBreakpoint!.margin, 24);
      expect(capturedBreakpoint!.device, LayoutClass.largeTablet);
    });
  });
}

void _testBreakpoint(double width, Breakpoint expected) {
  final constraints =
      BoxConstraints(maxWidth: width, maxHeight: double.infinity);
  final breakpoint = Breakpoint.fromConstraints(constraints);

  expect(breakpoint.columns, expected.columns,
      reason: 'Columns mismatch at width $width');
  expect(breakpoint.gutters, expected.gutters,
      reason: 'Gutters mismatch at width $width');
  expect(breakpoint.margin, expected.margin,
      reason: 'Margin mismatch at width $width');
  expect(breakpoint.device, expected.device,
      reason: 'Device mismatch at width $width');
  expect(breakpoint.window, expected.window,
      reason: 'Window mismatch at width $width');
}
