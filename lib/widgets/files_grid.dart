import 'package:flutter/material.dart';

import '../routes/uploadgram_route.dart';
import '../app_settings.dart';
import '../file_icons.dart';
import '../utils.dart';
import '../app_logic.dart';
import 'file_widget_grid.dart';

class FilesGrid extends StatefulWidget {
  @override
  _FilesGridState createState() => _FilesGridState();
}

class _FilesGridState extends State<FilesGrid> {
  List<Widget> _filesWidgets() {
    List<Widget> rows = [];
    var len = AppLogic.uploadingQueue.length;
    if (len > 0)
      for (int key = len - 1; key >= 0; key--) {
        var object = AppLogic.uploadingQueue[key];
        print(object);
        Map file = object['fileObject'];
        IconData fileIcon =
            fileIcons[file['name']?.split('.')?.last?.toLowerCase()] ??
                fileIcons['default']!;
        Stream? _uploadStream = object['stream'] ??
            (object['stream'] = AppLogic.uploadFileStream(object['key'], file));
        rows.add(StreamBuilder(
            stream: _uploadStream,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              double? _progress;
              String? _error;
              double _bytesPerSec = 0;
              bool _uploading = true;
              String _delete = object['key'].toString();
              Map? _file = {
                'filename': file['name'],
                'size': file['size'],
                'url': '',
              };
              if (snapshot.data != null)
                switch (snapshot.connectionState) {
                  case ConnectionState.active:
                    switch (snapshot.data['type']) {
                      case 'progress':
                        _progress = snapshot.data['value']['progress'];
                        _bytesPerSec = snapshot.data['value']['bytesPerSec'];
                        break;
                    }
                    break;
                  case ConnectionState.done:
                    switch (snapshot.data['type']) {
                      case 'end':
                        _uploading = false;
                        _delete = snapshot.data['value']['delete'];
                        _file = snapshot.data['value']['file'];
                        break;
                      case 'errorEnd':
                        _uploading = false;
                        _error = snapshot.data['value'];
                        break;
                      case 'error':
                        _uploading = false;
                        _error = 'An error occurred while uploading';
                        break;
                    }
                    break;
                  default:
                    break;
                }
              return FileWidgetGrid(
                selected: false,
                icon: fileIcon,
                delete: _delete,
                uploading: _uploading,
                progress: _progress,
                upperWidget: _progress == null
                    ? null
                    : Text(
                        '${(_progress * 100).round().toString()}% (${Utils.humanSize(_bytesPerSec)}/s)'),
                error: _error,
                filename: _file!['filename'],
                fileSize: _file['size'].toDouble(),
                url: _file['url'],
                handleDelete: _uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                handleRename: _uploading
                    ? null
                    : UploadgramRoute.of(context)?.handleFileRename,
                onPressed: _uploading ? () => null : null,
                onLongPress: _uploading ? () => null : null,
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
      bool isSelected = AppLogic.selected.contains(delete);
      rows.add(FileWidgetGrid(
        key: Key(delete),
        selected: isSelected,
        selectOnPress: AppLogic.selected.length > 0,
        icon: fileIcon,
        delete: delete,
        uploading: false,
        filename: fileObject['filename'],
        fileSize: fileObject['size'].toDouble(),
        url: fileObject['url'],
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
              ? GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      childAspectRatio: aspectRatio,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      crossAxisCount: gridSize > 0 ? gridSize : 1),
                  children: _filesWidgets(),
                  padding:
                      EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 78))
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
