import 'dart:async';
import 'dart:convert';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'utils.dart';
import 'appSettings.dart';
import 'settingsRoute.dart';
import 'fileWidget.dart';

void main() => runApp(UploadgramApp());

class UploadgramApp extends StatelessWidget {
  final defaultRoute = UploadgramRoute();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: kIsWeb ? 'Upload a file — Uploadgram' : 'Uploadgram',
      darkTheme: ThemeData(
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
      ),
      theme: ThemeData(
        appBarTheme: AppBarTheme(brightness: Brightness.dark),
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
      home: defaultRoute,
      routes: {
        '/settings': (BuildContext context) => SettingsRoute(),
      },
    );
  }
}

class UploadgramRoute extends StatefulWidget {
  static _UploadgramRouteState? of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();
  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute>
    with SingleTickerProviderStateMixin {
  final int maxSize = 2 * 1000 * 1000 * 1000;
  // TODO: for next version, maybe avoid using setState on the main route to have better performance
  // TODO: and split into several StatefulWidgets if needed.
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
    'docx': Icons.description,
    'doc': Icons.description,
    'odt': Icons.description,
    'md': Icons.font_download,
    'mp4': Icons.movie,
    'avi': Icons.movie,
    'mkv': Icons.movie,
    'webm': Icons.movie,
    'mpeg': Icons.movie,
    'ogv': Icons.movie,
    'ts': Icons.movie,
    'mp3': Icons.audiotrack,
    'aac': Icons.audiotrack,
    'mid': Icons.audiotrack,
    'midi': Icons.audiotrack,
    'oga': Icons.audiotrack,
    'wav': Icons.audiotrack,
    'weba': Icons.audiotrack,
    'opus': Icons.audiotrack,
    'gif': Icons.insert_photo,
    'bmp': Icons.insert_photo,
    'png': Icons.insert_photo,
    'jpg': Icons.insert_photo,
    'jpeg': Icons.insert_photo,
    'tiff': Icons.insert_photo,
    'tif': Icons.insert_photo,
    'ico': Icons.insert_photo,
    'webp': Icons.insert_photo,
    'html': Icons.code,
    'xml': Icons.code,
    'php': Icons.code,
    'py': Icons.code,
    'js': Icons.code,
    'dart': Icons.code,
    'css': Icons.code,
    'svg': Icons.code,
    'json': Icons.code,
    'java': Icons.code,
    'bash': Icons.code,
    'sh': Icons.code,
    'exe': Icons.settings_applications,
    'jar': Icons.settings_applications,
    'default': Icons.insert_drive_file
  };
  static const String appTitle =
      kIsWeb ? 'Upload a file — Uploadgram' : 'Uploadgram';
  final Connectivity _connectivity = Connectivity();
  bool _canUpload = false;
  int _checkSeconds = 0;
  Timer? _lastConnectivityTimer;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  List<String> _selected = [];
  List<Map> _uploadingQueue = [];

  void selectWidget(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  Future<void> _handleFileRename(String delete,
      {Function(String)? onDone, String? newName, String? oldName = ''}) async {
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
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: this setState can be turned into an internal setState
                    setState(() => _selected.clear());
                    _handleFileRename(delete, onDone: onDone, newName: _text);
                  },
                  child: Text('OK'),
                )
              ],
            );
          });
      return;
    }
    Map result = await AppSettings.api.renameFile(delete, newName);
    if (result['ok']) {
      onDone(result['new_filename']);
      // TODO: set internal widget state instead of reloading the whole tree
      setState(() =>
          AppSettings.files![delete]!['filename'] = result['new_filename']);
      AppSettings.saveFiles();
    } else
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result['message'])));
  }

  Future<void> _handleFileDelete(List<String> deleteList,
      {noDialog = false, Function? onYes}) async {
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('NO'),
                ),
                TextButton(
                  onPressed: () {
                    print(deleteList);
                    _handleFileDelete(deleteList, noDialog: true);
                    Navigator.pop(context);
                    onYes!();
                  },
                  child: Text('YES'),
                ),
              ],
            );
          });
    } else {
      String? _message;
      for (String delete in deleteList) {
        print('deleting $delete');
        Map result = await AppSettings.api.deleteFile(delete);
        if (result['statusCode'] == 403) {
          _message = 'File not found. It was probably deleted';
        }
      }
      if (_message != null)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message)));
      setState(
          () => deleteList.forEach((key) => AppSettings.files!.remove(key)));
      AppSettings.saveFiles();
    }
  }

  Stream? _uploadFileStream(UniqueKey? key, Map file) {
    if (file['locked'] == true) return null;
    file['locked'] = true;
    var controller = StreamController.broadcast();
    () async {
      // this while loop could be probably improved or removed
      while (_uploadingQueue[0]['key'] != key) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await AppSettings.api.uploadFile(
        file,
        onProgress: (double progress, double bytesPerSec, String remaining) {
          controller.add({
            'type': 'progress',
            'value': {'progress': progress, 'bytesPerSec': bytesPerSec}
          });
        },
      );
      if (result['ok']) {
        var fileObj = {
          'filename': file['name'],
          'size': file['size'],
          'url': result['url'],
        };
        AppSettings.files![result['delete']] = fileObj;
        controller.add({
          'type': 'end',
          'value': {'file': fileObj, 'delete': result['delete']},
        });
        AppSettings.saveFiles();
      } else {
        String? _error = 'An error occurred while obtaining the response';
        if (result['statusCode'] > 500)
          _error = 'We are having server problems. Try again later.';
        if (result.containsKey('message')) _error = result['message'];
        controller.add({
          'type': 'errorEnd',
          'value': _error,
        });
      }
      controller.close();
      _uploadingQueue.removeAt(0);
      if (_uploadingQueue.length == 0) AppSettings.api.clearFilesCache();
    }();
    return controller.stream;
  }

  Future<void> _uploadFile() async {
    if (_canUpload == false) return;
    if (await AppSettings.api.getBool('tos_accepted') == false) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: Text('Before proceeding...'),
                content: Text(
                    'Uploadgram uses the Telegram network to store its files, therefore you must accept Telegram\'s Terms of Service before continuing (https://telegram.org/tos).'
                    '\nBy continuing, you accept NOT to:'
                    '\n  - Use Uploadgram to scam users'
                    '\n  - upload pornographic content or content that promotes violence.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('You must accept the TOS to upload files.'),
                      ));
                    },
                    child: Text('I DISAGREE'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      AppSettings.api.setBool('tos_accepted', true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('You can now start uploading files!'),
                      ));
                      _uploadFile();
                    },
                    child: Text('GOT IT!'),
                  ),
                ],
              ));
      return;
    }
    print('asking for file');
    Map? file = await AppSettings.api.askForFile();
    if (file == null) return;
    if (file['error'] == 'PERMISSION_NOT_GRANTED') {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                  title: Text('Error'),
                  content: Text(
                      'Permissions not granted. Click the button to try again, or grant them in the settings.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK'),
                    )
                  ]));
      return;
    }
    if (file['size'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a non-null file.')));
      return;
    }
    if (AppSettings.files!.length >= 5 &&
        AppSettings.api.isWebAndroid() &&
        await AppSettings.api.getBool('has_asked_app') == false) {
      AppSettings.api.setBool('has_asked_app', true);
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: Text('Hi!'),
                content: Text(
                    'Seems like you are enjoying Uploadgram! Did you know that Uploadgram has an Android app too?'
                    '\nYou can download the app by clicking the button below or by clicking on the three-dots!'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('NO, THANKS'),
                  ),
                  TextButton(
                    onPressed: AppSettings.api.downloadApp,
                    child: Text('DOWNLOAD THE APP!'),
                  ),
                ],
              ));
    }
    print('got file ${file["name"]}');
    if (file['size'] > maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'The file you selected is too large. The maximum allowed size is 2GB')));
      return;
    }
    setState(() => _uploadingQueue.add({
          'key': UniqueKey(),
          'fileObject': file,
          'locked': false,
          'stream': null
        }));
  }

  List<Widget> _filesWidgets() {
    List<Widget> rows = [];
    var len = _uploadingQueue.length;
    if (len > 0)
      for (int key = len - 1; key >= 0; key--) {
        var object = _uploadingQueue[key];
        print(object);
        Map file = object['fileObject'];
        IconData? fileIcon =
            fileIcons[file['name'].split('.').last.toLowerCase()] ??
                fileIcons['default'];
        Stream? _uploadStream = object['stream'] ??
            (object['stream'] = _uploadFileStream(object['key'], file));
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
              return FileWidget(
                selected: false,
                icon: fileIcon,
                delete: _delete,
                uploading: _uploading,
                progress: _progress,
                upperWidget: _progress == null
                    ? null
                    : Text(
                        '${(_progress * 100).round().toString()}% (${humanSize(_bytesPerSec)}/s)'),
                error: _error,
                filename: _file!['filename'],
                fileSize: _file['size'].toDouble(),
                url: _file['url'],
                handleDelete: _uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        _handleFileDelete([delete], onYes: onYes),
                handleRename: _uploading ? null : _handleFileRename,
                onPressed: _uploading ? () => null : null,
                onLongPress: _uploading ? () => null : null,
                compact: AppSettings.filesTheme == 'new_compact',
              );
            }));
      }
    AppSettings.files!.entries.toList().reversed.forEach((MapEntry entry) {
      String delete = entry.key;
      Map fileObject = entry.value;
      IconData? fileIcon =
          fileIcons[fileObject['filename'].split('.').last.toLowerCase()] ??
              fileIcons['default'];
      bool isSelected = _selected.contains(delete);
      rows.add(FileWidget(
        key: Key(delete),
        selected: isSelected,
        selectOnPress: _selected.length > 0,
        icon: fileIcon,
        delete: delete,
        uploading: false,
        filename: fileObject['filename'],
        fileSize: fileObject['size'].toDouble(),
        url: fileObject['url'],
        handleDelete: (String delete, {Function? onYes}) =>
            _handleFileDelete([delete], onYes: onYes),
        handleRename: _handleFileRename,
        compact: AppSettings.filesTheme == 'new_compact',
      ));
    });
    return rows;
  }

  @override
  void initState() {
    _initStateAsync();
    super.initState();
  }

  Future<void> _initStateAsync() async {
    await AppSettings.getFiles();
    await AppSettings.getSettings();
    // this function is used to refresh the state, so, refresh the files list
    setState(() => null);
    if (kIsWeb) {
      ConnectivityResult? _lastConnectivityResult;
      _connectivity
          .checkConnectivity()
          .then((ConnectivityResult connecitityResult) {
        _lastConnectivityResult = connecitityResult;
        _checkConnection(connecitityResult);
      });
      Timer.periodic(Duration(seconds: 30), (timer) {
        _connectivity
            .checkConnectivity()
            .then((ConnectivityResult connectivityResult) {
          if (_lastConnectivityResult !=
              connectivityResult) // only call if connectivity changed
            _checkConnection(connectivityResult);
        });
      });
    }
    // subscribe to connectivity event stream
    else
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_checkConnection);
  }

  Future<void> _checkConnection(ConnectivityResult connectivityResult) async {
    setState(() => _canUpload = false);
    print('Check connection called.');
    if (connectivityResult != ConnectivityResult.none) {
      if (connectivityResult == ConnectivityResult.mobile)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WARNING: You are using Mobile Data!')));
      return _checkUploadgramConnection();
    }
  }

  Future<void> _checkUploadgramConnection() async {
    if (_lastConnectivityTimer != null) _lastConnectivityTimer!.cancel();
    if (await AppSettings.api.checkNetwork()) {
      setState(() => _canUpload = true);
    } else {
      if (_checkSeconds < 90) _checkSeconds += 15;
      _lastConnectivityTimer =
          Timer(Duration(seconds: _checkSeconds), _checkUploadgramConnection);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Uploadgram is down. Checking again in $_checkSeconds seconds.'),
          action: SnackBarAction(
              label: 'Try now',
              textColor: Theme.of(context).accentColor,
              onPressed: () {
                _checkUploadgramConnection();
              })));
    }
  }

  @override
  void dispose() {
    AppSettings.saveFiles();
    AppSettings.saveSettings();
    _connectivitySubscription.cancel();
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
          icon: Icon(Icons.delete),
          onPressed: () {
            _handleFileDelete(List.from(_selected),
                onYes: () => setState(() => _selected.clear()));
          },
          tooltip: 'Delete selected file(s)',
        ),
        IconButton(
          icon: Icon(Icons.get_app),
          onPressed: () async {
            // we need to export ONLY _selected here
            // _selected is a list of _files keys, so it should be easy to export.
            Map _exportFiles = {};
            _selected.forEach((e) => _exportFiles[e] = AppSettings.files![e]);
            String _filename = 'uploadgram_files.json';
            if (_selected.length == 1)
              _filename = _exportFiles[_selected[0]]['filename'] + '.json';
            if (await AppSettings.api
                    .saveFile(_filename, json.encode(_exportFiles)) !=
                true) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Couldn\'t export files.'),
              ));
            }
          },
          tooltip: 'Export selected file(s)',
        )
      ];
      if (_selected.length == 1) {
        actions.insert(
            1,
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _handleFileRename(_selected[0],
                  oldName: AppSettings.files![_selected[0]]!['filename']),
              tooltip: 'Rename this file',
            ));
      }
      if (_selected.length < AppSettings.files!.length)
        actions.insert(
            0,
            IconButton(
              icon: Icon(Icons.select_all),
              onPressed: () => setState(
                  () => _selected = List<String>.from(AppSettings.files!.keys)),
              tooltip: 'Select all the files',
            ));
    } else {
      actions = [
        PopupMenuButton(
          icon: Icon(Icons.more_vert),
          onSelected: (dynamic selected) async {
            switch (selected) {
              case 'settings':
                List previousSettings = [
                  AppSettings.fabTheme,
                  AppSettings.filesTheme
                ];
                await Navigator.pushNamed(context, '/settings');
                if (previousSettings !=
                    [AppSettings.fabTheme, AppSettings.filesTheme]) {
                  AppSettings.saveSettings();
                  setState(() => null);
                }
                break;
              case 'export':
                if (AppSettings.files!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Your files list is empty. Upload some files before exporting them.'),
                  ));
                  break;
                }
                if (await AppSettings.api.saveFile('uploadgram_files.json',
                        json.encode(AppSettings.files)) !=
                    true) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Couldn\'t export files.'),
                  ));
                }
                break;
              case 'import':
                Map? _importedFiles = await AppSettings.api.importFiles();
                print('_importedFiles = ${_importedFiles.toString()}');
                if (_importedFiles == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('The selected file is not valid')));
                  break;
                }
                AppSettings.files!.addAll(
                    _importedFiles.cast<String, Map<dynamic, dynamic>>());
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
      appBar: AppBar(
        title: _selected.length > 0
            ? Text(
                _selected.length.toString() +
                    ' file' +
                    (_selected.length > 1 ? 's' : '') +
                    ' selected',
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
      // replace this with a future builder of _initStateAsync
      body: Column(children: [
        Expanded(
            child: AppSettings.files == null
                ? Center(
                    child: SizedBox(
                    child: CircularProgressIndicator(),
                    width: 100,
                    height: 100,
                  ))
                : ((AppSettings.files!.length > 0 || _uploadingQueue.length > 0)
                    ? GridView(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            childAspectRatio: aspectRatio,
                            mainAxisSpacing: 5,
                            crossAxisSpacing: 5,
                            crossAxisCount: gridSize > 0 ? gridSize : 1),
                        children: _filesWidgets(),
                        padding: EdgeInsets.only(
                            left: 15, right: 15, top: 15, bottom: 78))
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
      ]),
      floatingActionButton: AppSettings.fabTheme == 'extended'
          ? FloatingActionButton.extended(
              onPressed: _uploadFile,
              label: Text("UPLOAD"),
              icon: _canUpload
                  ? const Icon(Icons.cloud_upload)
                  : CircularProgressIndicator())
          : AppSettings.fabTheme == 'compact'
              ? FloatingActionButton(
                  onPressed: _uploadFile,
                  child: _canUpload
                      ? const Icon(Icons.cloud_upload)
                      : CircularProgressIndicator())
              : null,
      floatingActionButtonLocation: AppSettings.fabTheme == 'extended'
          ? FloatingActionButtonLocation.centerFloat
          : AppSettings.fabTheme == 'compact'
              ? FloatingActionButtonLocation.endFloat
              : null,
    );
  }
}
