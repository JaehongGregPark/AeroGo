// Smoke test for AeroGo's root widget.
//
// The previous version of this file was the unmodified `flutter create`
// template: it built `MyApp` and looked for a counter ('0'/'1' text and an
// add icon). Neither `MyApp` nor a counter exist in this app (the root
// widget is `AeroGoApp`, defined in lib/app.dart), so the template test
// did not compile. This replaces it with a real smoke test for AeroGo.

import 'package:flutter_test/flutter_test.dart';

import 'package:aerogo/app.dart';
import 'package:aerogo/models/enums.dart';
import 'package:aerogo/models/user_environment_settings.dart';

void main() {
  testWidgets('AeroGoApp renders the home page without crashing',
      (WidgetTester tester) async {
    final initialEnvironmentSettings = {
      for (final role in UserRole.values) role: UserEnvironmentSettings.defaults(),
    };

    await tester.pumpWidget(
      AeroGoApp(initialEnvironmentSettings: initialEnvironmentSettings),
    );
    await tester.pumpAndSettle();

    // No uncaught exceptions during build/layout.
    expect(tester.takeException(), isNull);

    // The default screen starts on the '대국' (game) menu for a general user.
    expect(find.text('대국'), findsWidgets);

    // The role/board size/mode summary line should be present.
    expect(find.textContaining('일반사용자'), findsWidgets);
  });
}
