import 'dart:async';
import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uploadgram/web_api_wrapper/api_definitions.dart';

import '../widgets/files_grid.dart';
import '../app_settings.dart';
import '../app_logic.dart';

class UploadgramRoute extends StatefulWidget {
  static _UploadgramRouteState? of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();
  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute> {
  static const int maxSize = 2 * 1000 * 1000 * 1000;
  final Connectivity _connectivity = Connectivity();
  bool _canUpload = false;
  int _checkSeconds = 0;
  Timer? _lastConnectivityTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  void selectWidget(String id) => setState(() {
        AppLogic.selected.contains(id)
            ? AppLogic.selected.remove(id)
            : AppLogic.selected.add(id);
      });

  Future<void> handleFileRename(String delete,
      {Function(String)? onDone, String? newName, String? oldName = ''}) async {
    if (onDone == null) onDone = (_) => null;
    if (newName == null) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            late String _text;
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
                    setState(() => AppLogic.selected.clear());
                    handleFileRename(delete, onDone: onDone, newName: _text);
                  },
                  child: Text('OK'),
                )
              ],
            );
          });
      return;
    }
    RenameApiResponse result =
        await AppLogic.webApi.renameFile(delete, newName);
    if (result.ok) {
      onDone(result.newName!);
      AppLogic.files![delete]!['filename'] = result.newName!;
      AppLogic.saveFiles();
    } else
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorMessage!)));
  }

  Future<void> handleFileDelete(List<String> deleteList,
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
                    handleFileDelete(deleteList, noDialog: true);
                    Navigator.pop(context);
                    onYes?.call();
                  },
                  child: Text('YES'),
                ),
              ],
            );
          });
    } else {
      String? _message;
      List<String> deletedFiles = [];
      for (String delete in deleteList) {
        print('deleting $delete');
        Map result = await AppLogic.webApi.deleteFile(delete);
        if (result['statusCode'] == 403) {
          _message = 'File not found. It was probably deleted';
        } else if (!result['ok']) {
          _message =
              'Some files have not been deleted (code: ${result['statusCode']}).';
          continue;
        }
        deletedFiles.add(delete);
      }
      if (_message != null)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message)));
      setState(() => deleteList.forEach((key) => AppLogic.files!.remove(key)));
      AppLogic.saveFiles();
    }
  }

  Future<void> _uploadFile() async {
    if (_canUpload == false) return;
    if (await AppLogic.platformApi.getBool('tos_accepted') == false) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                // fetch tos instead of having them hardcoded
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
                      AppLogic.platformApi.setBool('tos_accepted', true);
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
    Map? file = await AppLogic.platformApi.askForFile();
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
          SnackBar(content: Text('Please select a non-empty file.')));
      return;
    }
    if (AppLogic.files!.length >= 5 &&
        AppLogic.platformApi.isWebAndroid() &&
        await AppLogic.platformApi.getBool('has_asked_app') == false) {
      AppLogic.platformApi.setBool('has_asked_app', true);
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
                    onPressed: AppLogic.webApi.downloadApp,
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
    setState(() => AppLogic.uploadingQueue.add({
          'key': UniqueKey(),
          'fileObject': file,
          'locked': false,
          'stream': null
        }));
  }

  @override
  void initState() {
    _initStateAsync();
    super.initState();
  }

  Future<void> _initStateAsync() async {
    await AppLogic.getFiles();
    await AppSettings.getSettings();
    // this function is used to refresh the state, so, refresh the files list
    setState(() => null);
    if (kIsWeb) {
      _connectivity.checkConnectivity().then(_checkConnection);
    }
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
    _lastConnectivityTimer?.cancel();
    if (await AppLogic.webApi.checkNetwork()) {
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
    AppLogic.saveFiles();
    AppSettings.saveSettings();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [];
    if (AppLogic.selected.length > 0) {
      actions = [
        if (AppLogic.selected.length < AppLogic.files!.length)
          IconButton(
            icon: Icon(Icons.select_all),
            onPressed: () => setState(() =>
                AppLogic.selected = List<String>.from(AppLogic.files!.keys)),
            tooltip: 'Select all the files',
          ),
        if (AppLogic.selected.length == 1)
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => handleFileRename(AppLogic.selected[0],
                oldName: AppLogic.files![AppLogic.selected[0]]!['filename']),
            tooltip: 'Rename this file',
          ),
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            handleFileDelete(List.from(AppLogic.selected),
                onYes: () => setState(() => AppLogic.selected.clear()));
          },
          tooltip: 'Delete selected file(s)',
        ),
        IconButton(
          icon: Icon(Icons.get_app),
          onPressed: () async {
            // we need to export ONLY AppLogic.selected here
            // AppLogic.selected is a list of _files keys, so it should be easy to export.
            Map _exportFiles = {};
            AppLogic.selected
                .forEach((e) => _exportFiles[e] = AppLogic.files![e]);
            String _filename = 'uploadgram_files.json';
            if (AppLogic.selected.length == 1)
              _filename =
                  _exportFiles[AppLogic.selected[0]]['filename'] + '.json';
            if (await AppLogic.platformApi
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
                if (AppLogic.files!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Your files list is empty. Upload some files before exporting them.'),
                  ));
                  break;
                }
                if (await AppLogic.platformApi.saveFile(
                        'uploadgram_files.json', json.encode(AppLogic.files)) !=
                    true) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Couldn\'t export files.'),
                  ));
                }
                break;
              case 'import':
                Map? _importedFiles = await AppLogic.platformApi.importFiles();
                print('_importedFiles = ${_importedFiles.toString()}');
                if (_importedFiles == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('The selected file is not valid')));
                  break;
                }
                AppLogic.files!.addAll(
                    _importedFiles.cast<String, Map<dynamic, dynamic>>());
                AppLogic.saveFiles();
                setState(() => null);
                break;
              case 'dlapp':
                AppLogic.webApi.downloadApp();
                break;
            }
          },
          itemBuilder: (context) {
            List<PopupMenuEntry<String>> items = [
              PopupMenuItem(
                  value: 'import',
                  child: Row(children: [
                    Icon(Icons.publish,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    SizedBox(width: 15),
                    Text('Import files list'),
                  ])),
              PopupMenuItem(
                  value: 'export',
                  child: Row(children: [
                    Icon(Icons.get_app,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    Container(width: 15),
                    Text('Export files list'),
                  ])),
              PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    Container(width: 15),
                    Text('Settings'),
                  ])),
            ];
            if (AppLogic.platformApi.isWebAndroid() == true)
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
        title: AppLogic.selected.length > 0
            ? Text(
                AppLogic.selected.length.toString() +
                    ' file' +
                    (AppLogic.selected.length > 1 ? 's' : '') +
                    ' selected',
              )
            : Text('Uploadgram'),
        leading: AppLogic.selected.length > 0
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () => setState(() {
                      AppLogic.selected.clear();
                    }))
            : null,
        actions: actions,
      ),
      // replace this with a future builder of _initStateAsync
      body: AppLogic.files == null
          ? Center(
              child: SizedBox(
              child: CircularProgressIndicator(),
              width: 100,
              height: 100,
            ))
          : FilesGrid(),
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
