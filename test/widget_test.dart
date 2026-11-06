import 'package:flutter_test/flutter_test.dart';
import 'package:zembo_browser/app.dart';
import 'package:zembo_browser/state/app_settings.dart';

void main() {
  testWidgets('start page shows Zembo Browser', (WidgetTester tester) async {
    await tester.pumpWidget(ZemboBrowserApp(settings: AppSettings()));
    expect(find.text('Zembo Browser'), findsWidgets);
  });
}
