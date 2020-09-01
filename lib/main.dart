import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uploadgram/settingsRoute.dart';
import 'fileWidget.dart';
import 'appSettings.dart';

void main() => runApp(UploadgramApp());

class UploadgramApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kIsWeb ? 'Upload a file — Uploadgram' : 'Uploadgram',
      darkTheme: ThemeData(
        primarySwatch: Colors.grey,
        accentColor: Color(0xFF222222),
        primaryColorDark: Colors.grey[900],
        primaryColorLight: Colors.blue,
        primaryIconTheme: IconThemeData(color: Colors.white),
        primaryColor: Colors.black,
        primaryColorBrightness: Brightness.dark,
        brightness: Brightness.dark,
        canvasColor: Colors.black,
      ),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColorDark: Colors.grey[300],
        accentColor: Colors.blue,
        primaryColorLight: Colors.blue,
        brightness: Brightness.light,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: UploadgramRoute(),
    );
  }
}

class UploadgramRoute extends StatefulWidget {
  static _UploadgramRouteState of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();
  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute> {
  // TODO: for next version, maybe avoid using setState on the Route to have better performance
  // TODO: and split into several StatefulWidgets.
  static const Map<String, IconData> fileIcons = {
    'apk': Icons.android,
    'zip': Icons.archive,
    '7z': Icons.archive,
    'rar': Icons.archive,
    'tar': Icons.archive,
    'gz': Icons.archive,
    'xz': Icons.archive,
    'bz2': Icons.archive,
    'log': Icons.description,
    'txt': Icons.description,
    'sh': Icons.description,
    'docx': Icons.description,
    'doc': Icons.description,
    'odt': Icons.description,
    'bash': Icons.description,
    'mp4': Icons.movie,
    'avi': Icons.movie,
    'html': Icons.code,
    'xml': Icons.code,
    'php': Icons.code,
    'py': Icons.code,
    'js': Icons.code,
    'dart': Icons.code,
    'css': Icons.code,
    'svg': Icons.code,
    'json': Icons.code,
    'exe': Icons.settings_applications,
    'jar': Icons.settings_applications,
    'png': Icons.insert_photo,
    'jpg': Icons.insert_photo,
    'jpeg': Icons.insert_photo,
    'md': Icons.font_download,
    'default': Icons.insert_drive_file
  };
  static const String appTitle =
      kIsWeb ? 'Upload a file — Uploadgram' : 'Uploadgram';

  List<String> _selected = [];
  List<Map> _uploadingQueue = [];
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void selectWidget(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  Future<void> _handleFileRename(String delete,
      {Function(String) onDone, String newName, String oldName = ''}) async {
    if (onDone == null) onDone = (_) => null;
    if (newName == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            String _text = '';
            return AlertDialog(
              title: Text('Rename file'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a new name for this file',
                  ),
                  TextFormField(
                    initialValue: oldName,
                    maxLength: 255,
                    showCursor: true,
                    onChanged: (newText) => _text = newText,
                    decoration: InputDecoration(filled: true),
                  ),
                ],
              ),
              // content: TextField(
              //   maxLength: 255,
              //   showCursor: true,
              //   controller: _controller,
              //   decoration: InputDecoration(),
              // ),
              actions: [
                FlatButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('CANCEL'),
                  textColor: Theme.of(context).primaryColorLight,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                ),
                FlatButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _selected.clear());
                    _handleFileRename(delete, onDone: onDone, newName: _text);
                  },
                  child: Text('OK'),
                  textColor: Theme.of(context).primaryColorLight,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                )
              ],
            );
          });
      return;
    }
    Map result = await AppSettings.api.renameFile(delete, newName);
    if (result['ok']) {
      onDone(result['new_filename']);
      setState(
          () => AppSettings.files[delete]['filename'] = result['new_filename']);
      AppSettings.saveFiles();
    } else
      _scaffoldKey.currentState
          .showSnackBar(SnackBar(content: Text(result['message'])));
  }

  Future<void> _handleFileDelete(List<String> deleteList,
      {noDialog = false, Function onYes}) async {
    if (deleteList.length == 0) return;
    if (onYes == null) onYes = () => null;
    int listLength = deleteList.length;
    print('called  _handleFileDelete');
    if (!noDialog) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete file'),
              content: Text('Are you sure you want to delete ' +
                  (listLength == 1
                      ? 'this file'
                      : listLength.toString() + ' files') +
                  '?'),
              actions: [
                FlatButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('NO'),
                  textColor: Theme.of(context).primaryColorLight,
                ),
                FlatButton(
                  onPressed: () {
                    print(deleteList);
                    _handleFileDelete(deleteList, noDialog: true);
                    Navigator.pop(context);
                    onYes();
                  },
                  child: Text('YES'),
                  textColor: Theme.of(context).primaryColorLight,
                ),
              ],
            );
          });
    } else {
      String _message;
      deleteList.forEach((delete) async {
        print('deleting $delete');
        Map result = await AppSettings.api.deleteFile(delete);
        if (result['ok']) {
          return;
        }
        if (result['statusCode'] == 403) {
          _message = 'File not found. It was probably deleted';
        }
      });
      if (_message != null)
        _scaffoldKey.currentState
            .showSnackBar(SnackBar(content: Text(_message)));
      setState(
          () => deleteList.forEach((key) => AppSettings.files.remove(key)));
      AppSettings.saveFiles();
    }
  }

  Stream _uploadFileStream(UniqueKey key, Map file) {
    if (file['locked'] == true) return null;
    file['locked'] = true;
    // ignore: close_sinks
    var controller = new StreamController();
    var uploadWorker = () async {
      while (_uploadingQueue[0]['key'] != key) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await AppSettings.api.uploadFile(file,
          onProgress: (int loaded, int total) {
            print('loaded: $loaded, total: $total');
            controller.add({'type': 'progress', 'value': loaded / total});
          },
          onError: () {
            controller.add({'type': 'error', 'value': null});
          },
          onEnd: () => null,
          onStart: () => null);
      print(result);
      if (result['ok']) {
        var fileObj = {
          'filename': file['name'],
          'size': file['size'],
          'url': result['url'],
        };
        AppSettings.files[result['delete']] = fileObj;
        controller.add({
          'type': 'end',
          'value': {'file': fileObj, 'delete': result['delete']},
        });
        AppSettings.saveFiles();
      } else {
        controller.add({'type': 'errorEnd', 'value': null});
      }
      await controller.close();
      _uploadingQueue.removeAt(0);
    };
    uploadWorker();
    return controller.stream;
  }

  Future<void> _uploadFile() async {
    print('asking for file');
    Map file = await AppSettings.api.getFile();
    if (file == null) return;
    if (file['error'] == 'PERMISSION_NOT_GRANTED') {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                  title: Text('Error'),
                  content: Text(
                      'Permissions not granted. Click the button to try again, or grant them in the settings.'),
                  actions: [
                    FlatButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                        textColor: Theme.of(context).primaryColorLight),
                  ]));
      return;
    }
    print('got file ${file["name"]}');
    setState(() {
      _uploadingQueue.add({
        'key': UniqueKey(),
        'fileObject': file,
        'locked': false,
        'stream': null
      });
      return true;
    });
  }

  List<Widget> _filesWidgets() {
    List<Widget> rows = [];
    AppSettings.files.forEach((delete, fileObject) {
      IconData fileIcon = fileIcons[fileObject['filename'].split('.').last] ??
          fileIcons['default'];
      rows.add(FileWidget(
        selected: _selected.contains(delete),
        selectOnPress: _selected.length > 0,
        icon: fileIcon,
        delete: delete,
        uploading: false,
        filename: fileObject['filename'],
        fileSize: fileObject['size'].toDouble(),
        url: fileObject['url'],
        handleDelete: (String delete, {Function onYes}) =>
            _handleFileDelete([delete], onYes: onYes),
        handleRename: _handleFileRename,
        compact: AppSettings.filesTheme == 'new_compact',
      ));
    });
    var len = _uploadingQueue.length;
    for (int key = 0; key < len; key++) {
      var object = _uploadingQueue[key];
      print(object);
      Map file = object['fileObject'];
      IconData fileIcon =
          fileIcons[file['name'].split('.').last] ?? fileIcons['default'];
      Stream _uploadStream = object['stream'] ??
          (object['stream'] = _uploadFileStream(object['key'], file));
      rows.add(StreamBuilder(
          stream: _uploadStream,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            double _progress;
            String _error;
            bool _uploading = true;
            String _delete = object['key'].toString();
            Map _file = {
              'filename': file['name'],
              'size': file['size'],
              'url': '',
            };
            switch (snapshot.connectionState) {
              case ConnectionState.active:
                print(snapshot.data);
                switch (snapshot.data['type']) {
                  case 'progress':
                    _progress = snapshot.data['value'];
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
                    _error = 'An error occurred while obtaining the response';
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
            return FileWidget(
              selected: false,
              icon: fileIcon,
              delete: _delete,
              uploading: _uploading,
              progress: _progress,
              error: _error,
              filename: _file['filename'],
              fileSize: _file['size'].toDouble(),
              url: _file['url'],
              handleDelete: _uploading
                  ? null
                  : (String delete, {Function onYes}) =>
                      _handleFileDelete([delete], onYes: onYes),
              handleRename: _uploading ? null : _handleFileRename,
              onPressed: _uploading ? () => null : null,
              onLongPress: _uploading ? () => null : null,
              compact: AppSettings.filesTheme == 'new_compact',
            );
          }));
    }
    return rows;
  }

  @override
  void initState() {
    _initStateAsync();
    super.initState();
  }

  Future<void> _initStateAsync() async {
    Map files = await AppSettings.getFiles();
    await AppSettings.getSettings();
    setState(() => null);
  }

  @override
  void dispose() {
    AppSettings.saveFiles();
    AppSettings.saveSettings();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    int gridSize = (size.width / 170).floor();
    double aspectRatio = AppSettings.filesTheme == 'new' ? 1 / 1 : 17 / 6;
    List<Widget> actions = [];
    print('Reloaded state!');
    if (_selected.length > 0) {
      actions = [
        IconButton(
          icon: Icon(Icons.select_all),
          onPressed: () => setState(
              () => _selected = List<String>.from(AppSettings.files.keys)),
        ),
        IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _handleFileDelete(List.from(_selected),
                  onYes: () => setState(() => _selected.clear()));
            }),
        IconButton(
            icon: Icon(Icons.get_app),
            onPressed: () {
              // we need to export ONLY _selected here
              // _selected is a list of _files keys, so it should be easy to export.
              Map _exportFiles = {};
              _selected.forEach((e) => _exportFiles[e] = AppSettings.files[e]);
              String _filename = 'uploadgram_files.json';
              if (_selected.length == 1)
                _filename = _exportFiles[_selected[0]]['filename'] + '.json';
              AppSettings.api.saveFile(_filename, json.encode(_exportFiles));
            })
      ];
      if (_selected.length == 1) {
        actions.insert(
            1,
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _handleFileRename(_selected[0],
                  oldName: AppSettings.files[_selected[0]]['filename']),
            ));
      }
    } else {
      actions = [
        PopupMenuButton(
          icon: Icon(Icons.more_vert),
          onSelected: (selected) async {
            switch (selected) {
              case 'settings':
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) => SettingsRoute()));
                AppSettings.saveSettings();
                setState(() => null);
                break;
              case 'export':
                if (AppSettings.files.isEmpty) {
                  _scaffoldKey.currentState.showSnackBar(SnackBar(
                    content: Text(
                        'Your files list is empty. Upload some files before exporting them.'),
                  ));
                  break;
                }
                AppSettings.api.saveFile(
                    'uploadgram_files.json', json.encode(AppSettings.files));
                break;
              case 'import':
                Map _importedFiles = await AppSettings.api.importFiles();
                print('_importedFiles = ${_importedFiles.toString()}');
                if (_importedFiles == null) {
                  _scaffoldKey.currentState.showSnackBar(SnackBar(
                      content: Text('The selected file is not valid')));
                  break;
                }
                AppSettings.files.addAll(_importedFiles);
                AppSettings.saveFiles();
                setState(() => null);
                break;
              case 'dlapp':
                AppSettings.api.downloadApp();
                break;
            }
          },
          itemBuilder: (context) {
            List<PopupMenuEntry<dynamic>> items = [
              PopupMenuItem(
                  value: 'import',
                  child: Row(children: [
                    Icon(Icons.publish,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    SizedBox(width: 5),
                    Text('Import files list'),
                  ])),
              PopupMenuItem(
                  value: 'export',
                  child: Row(children: [
                    Icon(Icons.get_app,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    Container(width: 5),
                    Text('Export files list'),
                  ])),
              PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    Container(width: 5),
                    Text('Settings'),
                  ])),
            ];
            if (AppSettings.api.isWebAndroid() == true)
              items.add(PopupMenuItem(
                  value: 'dlapp',
                  child: Row(children: [
                    Icon(Icons.android,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    Container(width: 5),
                    Text('Download the app!'),
                  ])));
            return items;
          },
        ),
      ];
    }
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).accentColor,
        title: _selected.length > 0
            ? Text(
                'Selected ' +
                    _selected.length.toString() +
                    ' file' +
                    (_selected.length > 1 ? 's' : ''),
              )
            : Text(appTitle),
        leading: _selected.length > 0
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () => setState(() {
                      _selected.clear();
                    }))
            : null,
        actions: actions,
      ),
      body: AppSettings.files == null
          ? Center(
              child: SizedBox(
              child: CircularProgressIndicator(),
              width: 100,
              height: 100,
            ))
          : ((AppSettings.files.length > 0 || _uploadingQueue.length > 0)
              ? GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      childAspectRatio: aspectRatio,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      crossAxisCount: gridSize > 0 ? gridSize : 1),
                  children: _filesWidgets(),
                  padding: EdgeInsets.only(
                      left: 15,
                      right: 15,
                      top: 15,
                      bottom: 78)) // bottom: 78, normal padding + fab
              : Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.all(15),
                  child: Text(
                    'Your uploaded files will appear here!',
                    style: Theme.of(context).textTheme.headline5,
                    textAlign: TextAlign.center,
                  ),
                )),
      floatingActionButton: AppSettings.fabTheme == 'extended'
          ? FloatingActionButton.extended(
              onPressed: _uploadFile,
              label: Text("UPLOAD"),
              icon: const Icon(Icons.cloud_upload))
          : FloatingActionButton(
              onPressed: _uploadFile, child: const Icon(Icons.cloud_upload)),
      floatingActionButtonLocation: AppSettings.fabTheme == 'extended'
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }
}
