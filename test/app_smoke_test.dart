import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up/app.dart';
import 'package:up/core/l10n/app_strings.dart';

/// Boots the real app and walks the first two screens.
///
/// Two things this file has to get right, and got wrong the first time:
///
/// 1. The surface is pinned to a phone size, so a genuine layout overflow
///    fails the test instead of passing on the default 800×600 canvas.
/// 2. `MaterialApp`'s localization delegates resolve asynchronously. Until
///    they do, `Localizations` renders nothing at all — so the frame that
///    `pumpWidget` produces is empty and no widget can be found in it. Every
///    test here pumps once more before asserting or advancing the clock;
///    without that, the splash timer has not even been scheduled yet and all
///    subsequent timing is off by a frame.
void main() {
  /// Boots the app and returns with the first real frame on screen.
  Future<void> bootApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const UpApp());
    await tester.pump(); // let the localization delegates resolve

    // And let the boot finish. Reading the stored session is asynchronous and
    // guarded by a real timer, so a test that stops before it lands leaves that
    // timer pending — which the framework, rightly, fails the test over.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Settles on the splash screen's entry point.
  ///
  /// `bootApp` has already waited out the hold and the session check, so this
  /// only has to let the button's fade finish.
  Future<void> reachSplashCta(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  testWidgets('the app boots into the splash and reaches the intro',
      (WidgetTester tester) async {
    await bootApp(tester);

    expect(find.text('UP'), findsOneWidget);
    expect(find.text(AppStrings.he.tagline), findsOneWidget);

    await reachSplashCta(tester);
    expect(find.text(AppStrings.he.start), findsOneWidget);

    await tester.tap(find.text(AppStrings.he.start));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.he.introTitle), findsOneWidget);
  });

  testWidgets('Hebrew lays out right to left', (WidgetTester tester) async {
    await bootApp(tester);

    final BuildContext context = tester.element(find.text('UP'));

    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the age gate blocks continuing until it is accepted',
      (WidgetTester tester) async {
    await bootApp(tester);
    await reachSplashCta(tester);

    await tester.tap(find.text(AppStrings.he.start));
    await tester.pumpAndSettle();

    // Continue is on screen but inert until the checkbox is ticked.
    await tester.tap(find.text(AppStrings.he.cont));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.he.introTitle),
      findsOneWidget,
      reason: 'the age gate must not be skippable',
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.he.cont));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.he.phoneTitle), findsOneWidget);
  });
}
