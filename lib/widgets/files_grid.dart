import 'package:flutter/material.dart';
import 'package:uploadgram/api_definitions.dart';

import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/file_icons.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/widgets/file_widget_grid.dart';

class FilesGrid extends StatefulWidget {
  @override
  _FilesGridState createState() => _FilesGridState();
}

class _FilesGridState extends State<FilesGrid> {
  List<Widget> _filesWidgets() {
    // turn this into a on-demand builder (GridView.builder)
    List<Widget> rows = [];
    var len = AppLogic.uploadingQueue.length;
    if (len > 0)
      for (int key = len - 1; key >= 0; key--) {
        var object = AppLogic.uploadingQueue[key];
        print(object);
        UploadgramFile file = object.uploadgramFile;
        IconData fileIcon =
            fileIcons[file.name.split('.').last.toLowerCase()] ??
                fileIcons['default']!;
        Stream<UploadingEvent>? _uploadStream = object.stream ??
            (object.stream = AppLogic.uploadFileStream(object));
        rows.add(StreamBuilder(
            stream: _uploadStream,
            builder:
                (BuildContext context, AsyncSnapshot<UploadingEvent> snapshot) {
              double? _progress;
              String? _error;
              double _bytesPerSec = 0;
              bool _uploading = true;
              String _delete = object.fileKey.toString();
              Map? _file = {
                'filename': file.name,
                'size': file.size,
                'url': '',
              };
              if (snapshot.hasData)
                switch (snapshot.connectionState) {
                  case ConnectionState.active:
                    if (snapshot.data is UploadingEventProgress) {
                      _progress =
                          (snapshot.data as UploadingEventProgress).progress;
                      _bytesPerSec =
                          (snapshot.data as UploadingEventProgress).bytesPerSec;
                    }
                    break;
                  case ConnectionState.done:
                    if (snapshot.data is UploadingEventEnd) {
                      _uploading = false;
                      _delete = (snapshot.data as UploadingEventEnd).delete;
                      _file = (snapshot.data as UploadingEventEnd).file;
                      break;
                    }
                    break;
                  default:
                    break;
                }
              else if (snapshot.hasError) {
                _uploading = false;
                _error = snapshot.error!.toString();
              }
              return FileWidgetGrid(
                icon: fileIcon,
                delete: _delete,
                uploading: _uploading,
                progress: _progress,
                upperWidget: _progress == null
                    ? null
                    : Text(
                        '${(_progress * 100).round().toString()}% (${Utils.humanSize(_bytesPerSec)}/s)'),
                error: _error,
                filename: _file['filename'],
                fileSize: _file['size'].toDouble(),
                url: _file['url'],
                selectedFilesNotifier:
                    UploadgramRoute.of(context)!.selectedFiles,
                handleDelete: _uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                handleRename: _uploading
                    ? null
                    : UploadgramRoute.of(context)?.handleFileRename,
                compact: AppSettings.filesTheme == 'new_compact',
              );
            }));
      }
    AppLogic.files!.entries.toList().reversed.forEach((MapEntry entry) {
      String delete = entry.key;
      Map fileObject = entry.value;
      IconData fileIcon =
          fileIcons[fileObject['filename']?.split('.')?.last?.toLowerCase()] ??
              fileIcons['default']!;
      rows.add(FileWidgetGrid(
        key: Key(delete),
        icon: fileIcon,
        delete: delete,
        uploading: false,
        filename: fileObject['filename'],
        fileSize: fileObject['size'].toDouble(),
        url: fileObject['url'],
        selectedFilesNotifier: UploadgramRoute.of(context)!.selectedFiles,
        handleDelete: (String delete, {Function? onYes}) =>
            UploadgramRoute.of(context)
                ?.handleFileDelete([delete], onYes: onYes),
        handleRename: UploadgramRoute.of(context)?.handleFileRename,
        compact: AppSettings.filesTheme == 'new_compact',
      ));
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    int gridSize = (size.width / 170).floor();
    double aspectRatio = AppSettings.filesTheme == 'new' ? 1 / 1 : 17 / 6;
    print('Reloaded state!');
    return Column(children: [
      Expanded(
          child: ((AppLogic.files!.length > 0 ||
                  AppLogic.uploadingQueue.length > 0)
              ? Scrollbar(
                  isAlwaysShown: MediaQuery.of(context).size.width > 950,
                  child: GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          childAspectRatio: aspectRatio,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                          crossAxisCount: gridSize > 0 ? gridSize : 1),
                      children: _filesWidgets(),
                      padding: EdgeInsets.only(
                          left: 15, right: 15, top: 15, bottom: 78)))
              // bottom: 78, normal padding + fab
              : Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.all(15),
                  child: Text(
                    'Your uploaded files will appear here!',
                    style: Theme.of(context).textTheme.headline5,
                    textAlign: TextAlign.center,
                  ),
                )))
    ]);
  }
}
