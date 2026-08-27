import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up/app.dart';
import 'package:up/core/l10n/app_strings.dart';

/// Boots the real app and walks the first two screens.
///
/// The surface is pinned to a phone size so a genuine layout overflow fails
/// the test instead of passing on a 800×600 desktop canvas.
void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the app boots into the splash and reaches the intro',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const UpApp());

    expect(find.text('UP'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.he.start), findsOneWidget);

    await tester.tap(find.text(AppStrings.he.start));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.he.introTitle), findsOneWidget);
  });

  testWidgets('Hebrew lays out right to left', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const UpApp());
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('UP'));

    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the age gate blocks continuing until it is accepted',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const UpApp());
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.he.start));
    await tester.pumpAndSettle();

    // Continue is present but inert until the checkbox is ticked.
    await tester.tap(find.text(AppStrings.he.cont));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.he.introTitle), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.he.cont));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.he.phoneTitle), findsOneWidget);
  });
}
