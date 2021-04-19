import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_logic.dart';

enum FilesTheme { grid, gridCompact, list }
enum FabTheme { centerExtended, left }

abstract class FilesViewerTheme extends StatelessWidget {
  StreamBuilder buildUploadingWidget(
      Widget Function(bool uploading, double? progress, String? error,
              int bytesPerSec, String delete, Map file)
          builder,
      UploadingFile uploadingFile) {
    Stream<UploadingEvent>? _uploadStream = uploadingFile.stream ??
        (uploadingFile.stream = AppLogic.uploadFileStream(uploadingFile));
    return StreamBuilder<UploadingEvent>(
        stream: _uploadStream,
        builder:
            (BuildContext context, AsyncSnapshot<UploadingEvent> snapshot) {
          double? progress;
          String? error;
          int bytesPerSec = 0;
          bool uploading = true;
          String delete = uploadingFile.fileKey.toString();
          Map? file = {
            'filename': uploadingFile.uploadgramFile.name,
            'size': uploadingFile.uploadgramFile.size,
            'url': '',
          };
          if (snapshot.hasData)
            switch (snapshot.connectionState) {
              case ConnectionState.active:
                if (snapshot.data is UploadingEventProgress) {
                  progress = (snapshot.data as UploadingEventProgress).progress;
                  bytesPerSec =
                      (snapshot.data as UploadingEventProgress).bytesPerSec;
                }
                break;
              case ConnectionState.done:
                if (snapshot.data is UploadingEventEnd) {
                  uploading = false;
                  delete = (snapshot.data as UploadingEventEnd).delete;
                  file = (snapshot.data as UploadingEventEnd).file;
                  break;
                }
                break;
              default:
                break;
            }
          else if (snapshot.hasError) {
            uploading = false;
            error = snapshot.error!.toString();
          }
          return builder.call(
              uploading, progress, error, bytesPerSec, delete, file);
        });
  }
}

class FileRightClickListener extends StatelessWidget {
  final String delete;
  final Function(String, {Function? onYes})? handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})?
      handleRename;
  final ValueNotifier<String> filenameNotifier;
  final int size;
  final String url;
  final Widget child;

  FileRightClickListener({
    required this.delete,
    required this.filenameNotifier,
    required this.handleDelete,
    required this.handleRename,
    required this.size,
    required this.url,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons != kSecondaryMouseButton) return;
        final overlay =
            Overlay?.of(context)?.context.findRenderObject() as RenderBox;
        showMenu(
            context: context,
            position:
                RelativeRect.fromSize(event.position & Size.zero, overlay.size),
            items: [
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete),
                    SizedBox(width: 15),
                    Text('Delete'),
                  ])),
              PopupMenuItem(
                  value: 'rename',
                  child: Row(children: [
                    Icon(Icons.edit),
                    SizedBox(width: 15),
                    Text('Rename'),
                  ])),
              PopupMenuItem(
                  value: 'copy',
                  child: Row(children: [
                    Icon(Icons.copy),
                    SizedBox(width: 15),
                    Text('Copy link'),
                  ])),
              PopupMenuItem(
                  value: 'export',
                  child: Row(children: [
                    Icon(Icons.get_app),
                    SizedBox(width: 15),
                    Text('Export'),
                  ])),
            ]).then((value) {
          switch (value) {
            case 'delete':
              handleDelete?.call(delete);
              break;
            case 'rename':
              handleRename?.call(delete,
                  oldName: filenameNotifier.value,
                  onDone: (String newName) => filenameNotifier.value = newName);
              break;
            case 'copy':
              AppLogic.copy(url).then((didCopy) => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(
                      content: Text(didCopy
                          ? 'Link copied to clipboard successfully!'
                          : 'Unable to copy file link. Please copy it manually.'))));
              break;
            case 'export':
              AppLogic.platformApi.saveFile(
                  filenameNotifier.value + '.json',
                  json.encode({
                    delete: {
                      'filename': filenameNotifier.value,
                      'size': size,
                      'url': url
                    }
                  }));
              break;
          }
        });
      },
      child: child,
    );
  }
}

enum Themes { system, dark, white }

Map<Themes, ThemeData> get themes => {
      Themes.dark: ThemeData(
        appBarTheme: AppBarTheme(color: Color(0xFF222222)),
        floatingActionButtonTheme:
            FloatingActionButtonThemeData(backgroundColor: Color(0xFF222222)),
        primarySwatch: Colors.blue,
        accentColor: Colors.blue,
        primaryColorDark: Colors.grey[900],
        primaryColorLight: Colors.blue,
        primaryIconTheme: IconThemeData(color: Colors.white),
        primaryColor: Colors.blue,
        primaryColorBrightness: Brightness.dark,
        brightness: Brightness.dark,
        canvasColor: Colors.black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      Themes.white: ThemeData(
        appBarTheme: AppBarTheme(brightness: Brightness.dark),
        primarySwatch: Colors.blue,
        primaryColorDark: Colors.grey[300],
        accentColor: Colors.blue,
        primaryColorLight: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    };

class AppRebuildNotification extends Notification {}
