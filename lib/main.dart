import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'fileWidget.dart';
import 'apiWrapperStub.dart'
    if (dart.library.io) 'androidApiWrapper.dart'
    if (dart.library.html) 'webApiWrapper.dart';

const uploadgramAccent = Color(0x3498db);
void main() => runApp(UploadgramApp());

class UploadgramApp extends StatelessWidget {
  // This widget is the root of your application.
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
          // This makes the visual density adapt to the platform that you run
          // the app on. For desktop platforms, the controls will be smaller and
          // closer together (more dense) than on mobile platforms.
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: UploadgramRoute());
  }
}

class UploadgramRoute extends StatefulWidget {
  static _UploadgramRouteState of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();
  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute> {
  static const Map<String, IconData> fileIcons = {
    'apk': Icons.android_sharp,
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
  Map _files = {};
  SharedPreferences _sharedPreferences;
  APIWrapper api = APIWrapper();

  void selectWidget(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  Future<void> _handleFileRename(String delete, {Function onRename}) async {
    // TODO: implement this
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
                  child: Text('No'),
                  textColor: Theme.of(context).primaryColorLight,
                ),
                FlatButton(
                  onPressed: () {
                    print(deleteList);
                    _handleFileDelete(deleteList, noDialog: true);
                    print('calling onYES');
                    Navigator.pop(context);
                    onYes();
                  },
                  child: Text('Yes'),
                  textColor: Theme.of(context).primaryColorLight,
                ),
              ],
            );
          });
    } else {
      deleteList.forEach((delete) async {
        print('deleting $delete');
        Map result = await api.deleteFile(delete);
        setState(() => _files.remove(delete));
        if (result['ok']) {
          return;
        }
        if (result['statusCode'] == 403) {
          _scaffoldKey.currentState.showSnackBar(SnackBar(
              content:
                  Text('File not found. It was probably already deleted')));
        }
      });
      saveFiles();
    }
  }

  Stream _uploadFileStream(GlobalKey<FileWidgetState> key, Map file) {
    if (file['locked'] == true) return null;
    file['locked'] = true;
    // ignore: close_sinks
    var controller = new StreamController();
    var uploadWorker = () async {
      while (_uploadingQueue[0]['key'] != key) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await api.uploadFile(file,
          onProgress: (int loaded, int total) {
            print('loaded: $loaded, total: $total');
            controller.add({'type': 'progress', 'value': loaded / total});
          },
          onError: () {
            controller.add({'type': 'error', 'value': null});
          },
          onEnd: () => null,
          onStart: () => null);
      if (result['ok']) {
        var fileObj = {
          'filename': file['name'],
          'size': file['size'],
          'url': result['url'],
        };
        _files[result['delete']] = fileObj;
        controller.add({
          'type': 'end',
          'value': {'file': fileObj, 'delete': result['delete']},
        });
        saveFiles();
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
    Map file = await api.getFile();
    if (file == null) return;
    print('got file ${file["name"]}');
    setState(() {
      _uploadingQueue.add({
        "key": GlobalKey<FileWidgetState>(),
        "fileObject": file,
        'locked': false
      });
      return true;
    });
  }

  List<Widget> _filesWidgets(Map files, List uploadingQueue) {
    print('a');
    List<Widget> rows = [];
    files.forEach((delete, fileObject) {
      IconData fileIcon = fileIcons[fileObject['filename'].split('.').last] ??
          fileIcons['default'];
      rows.add(FileWidget(
        selected: _selected.contains(delete),
        selectOnPress: _selected.length > 0,
        icon: fileIcon,
        delete: delete,
        uploading: false,
        fileObject: fileObject,
        handleDelete: (String delete, {Function onYes}) =>
            _handleFileDelete([delete], onYes: onYes),
        handleRename: _handleFileRename,
      ));
    });
    print(uploadingQueue);
    var len = uploadingQueue.length;
    for (int key = 0; key < len; key++) {
      var object = uploadingQueue[key];
      print(object);
      Map file = object['fileObject'];
      IconData fileIcon =
          fileIcons[file['name'].split('.').last] ?? fileIcons['default'];
      rows.add(StreamBuilder(
          stream: _uploadFileStream(object['key'], file),
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
              fileObject: _file,
              handleDelete: _uploading
                  ? null
                  : (String delete, {Function onYes}) =>
                      _handleFileDelete([delete], onYes: onYes),
              handleRename: _uploading ? null : _handleFileRename,
              onPressed: _uploading ? () => null : null,
              onLongPress: _uploading ? () => null : null,
            );
          }));
    }
    return rows;
  }

  @override
  void initState() {
    api.migrateFiles(); // this method will be transferring files from the uploaded_files name to flutter.uploaded_files
    // TODO: reimplement shared_preferences but with jsons
    _initStateAsync();
    super.initState();
  }

  Future<void> _initStateAsync() async {
    // TODO: setState here might be removed
    _sharedPreferences = await SharedPreferences.getInstance();
    print(_sharedPreferences.getString('uploaded_files'));
    setState(() {
      _files = _sharedPreferences.containsKey('uploaded_files')
          ? Map.from(
              json.decode(_sharedPreferences.getString('uploaded_files')))
          : {};
    });
  }

  void saveFiles() {
    _sharedPreferences.setString('uploaded_files', json.encode(_files));
  }

  @override
  Widget build(BuildContext context) {
    int gridSize = (MediaQuery.of(context).size.width / 170).floor();
    // TODO: add circularprogressindicator while waiting for files.
    List<Widget> actions = [];
    print('Reloaded state!');
    if (_selected.length > 0) {
      actions = [
        IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _handleFileDelete(List.from(_selected),
                  onYes: () => setState(() => _selected.clear()));
            }),
        IconButton(icon: Icon(Icons.get_app), onPressed: () => print('get'))
      ];
      if (_selected.length == 1) {
        actions.insert(
            1,
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => print('not implemented yet'),
            ));
      }
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
      body: _files == null
          ? Center(
              child: SizedBox(
              child: CircularProgressIndicator(),
              width: 100,
              height: 100,
            ))
          : ((_files.length > 0 || _uploadingQueue.length > 0)
              ? GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      crossAxisCount: gridSize > 0 ? gridSize : 1),
                  children: _filesWidgets(_files, _uploadingQueue),
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
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _uploadFile,
          label: Text("UPLOAD"),
          icon: const Icon(Icons.cloud_upload)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
