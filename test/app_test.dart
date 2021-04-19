import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/file_icons.dart';
import 'package:uploadgram/main.dart';

Widget buildTestableWidget(Widget widget) {
  return MediaQuery(data: MediaQueryData(), child: MaterialApp(home: widget));
}

void main() {
  testWidgets('basic tests', (WidgetTester tester) async {
    AppLogic.files = {};
    AppSettings.filesTheme = FilesTheme.grid;
    AppSettings.fabTheme = FabTheme.centerExtended;

    await tester.pumpFrames(
        buildTestableWidget(UploadgramApp(shouldCheckNetwork: false)),
        Duration(seconds: 5));
    expect(find.text('Your uploaded files will appear here!'), findsOneWidget);
    AppLogic.files = {
      'delete1': {
        'filename': 'test_file',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 30
      },
      'delete2': {
        'filename': 'my file 123',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 742778
      },
      'delete3': {
        'filename': 'my other file 324',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 98538
      },
    };
    await tester.pumpFrames(
        buildTestableWidget(UploadgramApp()), Duration(seconds: 5));
    expect(find.text('test_file'), findsOneWidget);
    expect(find.text('my file 123'), findsOneWidget);
    expect(find.text('my other file 324'), findsOneWidget);
  });
  testWidgets('test if file selection works.', (WidgetTester tester) async {
    AppLogic.files = {
      'delete1': {
        'filename': 'test_file',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 30
      },
      'delete2': {
        'filename': 'my file 123',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 742778
      },
      'delete3': {
        'filename': 'my other file 324',
        'url': 'https://dl.uploadgram.me/testing123',
        'size': 98538
      },
    };
    final Widget testable =
        buildTestableWidget(UploadgramApp(shouldCheckNetwork: false));
    await tester.pumpFrames(testable, Duration(seconds: 5));
    int i = 1;
    for (Map file in AppLogic.files!.values) {
      print('Testing ${file['filename']}.. ($i)');
      await tester.longPress(find.text(file['filename']));
      await tester.pump();
      expect(find.byType(FadeTransition), findsWidgets);
      await tester.pumpFrames(testable, Duration(milliseconds: 200));
    }
  });
  testWidgets('test theme changing', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = Size(1080, 2340);
    AppLogic.files = {
      'test': {
        'filename': 'text.file',
        'size': 1,
        'url': 'https://dl.uploadgram.me/test'
      }
    };
    AppSettings.filesTheme = FilesTheme.grid;
    AppSettings.fabTheme = FabTheme.centerExtended;

    await tester.pumpFrames(
        buildTestableWidget(UploadgramApp(shouldCheckNetwork: false)),
        Duration(seconds: 5));

    goSettings() async {
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.settings), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
    }

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.text('UPLOAD')),
        findsOneWidget);

    await goSettings();

    await tester.pumpAndSettle();
    expect(find.text('Button with text'), findsOneWidget);
    await tester.tap(find.text('Button with text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Button on the left side without text').first);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.text('UPLOAD')),
        findsNothing);

    expect(find.byIcon(fileIcons['default']!), findsNWidgets(2));

    await goSettings();

    await tester.pumpAndSettle();
    expect(find.text('New theme (default)'), findsOneWidget);
    await tester.tap(find.text('New theme (default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New theme but compact').first);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byIcon(fileIcons['default']!), findsOneWidget);
  });
}
