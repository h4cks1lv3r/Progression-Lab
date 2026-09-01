from pathlib import Path


path = Path("test/persistence_onboarding_test.dart")
text = path.read_text()
old = """    await tester.tap(find.text('NOT NOW'));
    await tester.pump(const Duration(milliseconds: 250));
"""
new = """    final setupScrollable = find.descendant(
      of: find.byType(FirstLaunchDataSetupScreen),
      matching: find.byType(Scrollable),
    );
    expect(setupScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('NOT NOW'),
      420,
      scrollable: setupScrollable,
    );
    await tester.tap(find.text('NOT NOW'));
    await tester.pump(const Duration(milliseconds: 250));
"""
if new not in text:
    if old not in text:
        raise RuntimeError("The first-launch skip interaction was not found")
    path.write_text(text.replace(old, new, 1))
