import 'dart:async';
import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/selected_files_notifier.dart';
import 'package:uploadgram/widgets/files_grid.dart';
import 'package:uploadgram/widgets/files_list.dart';

class UploadgramRoute extends StatefulWidget {
  static _UploadgramRouteState? of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();
  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute> {
  static const int maxSize = 2 * 1000 * 1000 * 1000;
  final Connectivity _connectivity = Connectivity();
  int _checkSeconds = 0;
  Timer? _lastConnectivityTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final ValueNotifier<bool> _canUploadNotifier = ValueNotifier<bool>(false);
  final SelectedFilesNotifier selectedFiles = SelectedFilesNotifier();

  void selectWidget(String id) {
    selectedFiles.contains(id)
        ? selectedFiles.remove(id)
        : selectedFiles.add(id);
  }

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
                    selectedFiles.clear();
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
    print(result);
    if (result.ok) {
      onDone(result.newName!);
      AppLogic.files![delete]!['filename'] = result.newName!;
      AppLogic.saveFiles();
    } else if (result.statusCode == 403) {
      setState(() {
        AppLogic.files!.remove(delete);
        AppLogic.saveFiles();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('File not found.')));
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
        DeleteApiResponse result = await AppLogic.webApi.deleteFile(delete);
        if (result.statusCode == 403) {
          _message = 'File not found. It was probably deleted';
        } else if (!result.ok) {
          _message =
              'Some files have not been deleted (code: ${result.statusCode}).';
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
    if (_canUploadNotifier.value == false) return;
    if (await AppLogic.platformApi.getBool('tos_accepted', false) == false) {
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
    UploadgramFile file = await AppLogic.platformApi.askForFile();
    if (file.error == UploadgramFileError.abortedByUser) return;
    if (file.error == UploadgramFileError.permissionNotGranted) {
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
    return await uploadFile(file);
  }

  Future<void> uploadFile(UploadgramFile file) async {
    if (_canUploadNotifier.value == false) return;
    if (file.size == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a non-empty file.')));
      return;
    }
    if (AppLogic.files!.length >= 5 &&
        AppLogic.platformApi.isWebAndroid() &&
        await AppLogic.platformApi.getBool('has_asked_app', false) == false) {
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
    print('got file ${file.name}');
    if (file.size > maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'The file you selected is too large. The maximum allowed size is 2GB')));
      return;
    }
    setState(() => AppLogic.uploadingQueue
        .add(UploadingFile(uploadgramFile: file, fileKey: UniqueKey())));
  }

  @override
  void initState() {
    _initStateAsync();
    super.initState();
  }

  Future<void> _initStateAsync() async {
    if (AppLogic.files == null) await AppLogic.getFiles();
    // this function is used to refresh the state, so, refresh the files list
    setState(() => null);
    if (kIsWeb) {
      _connectivity.checkConnectivity().then(_checkConnection);
      InternalAPIWrapper.listenDropzone(context, uploadFile);
    }
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_checkConnection);
  }

  Future<void> _checkConnection(ConnectivityResult connectivityResult) async {
    _canUploadNotifier.value = false;
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
      _canUploadNotifier.value = true;
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

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];
    if (selectedFiles.length > 0) {
      actions = [
        if (selectedFiles.length < AppLogic.files!.length)
          IconButton(
            key: Key('select_all'),
            icon: Icon(Icons.select_all),
            onPressed: () => setState(() =>
                selectedFiles.value = List<String>.from(AppLogic.files!.keys)),
            tooltip: 'Select all the files',
          ),
        IconButton(
          key: Key('delete'),
          icon: Icon(Icons.delete),
          onPressed: () {
            handleFileDelete(List.from(selectedFiles.value),
                onYes: () => selectedFiles.clear());
          },
          tooltip: 'Delete selected file(s)',
        ),
        IconButton(
          key: Key('export'),
          icon: Icon(Icons.get_app),
          onPressed: () async {
            Map _exportFiles = {};
            selectedFiles.value
                .forEach((e) => _exportFiles[e] = AppLogic.files![e]);
            String _filename = 'uploadgram_files.json';
            if (selectedFiles.length == 1)
              _filename = _exportFiles[selectedFiles[0]]['filename'] + '.json';
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
                late Map? _importedFiles;
                try {
                  _importedFiles = await AppLogic.platformApi.importFiles();
                } on FormatException {
                  // ScaffoldMessenger.of(context)
                  //     .showSnackBar(SnackBar(content: Text(e.toString())));
                  _importedFiles = null;
                }
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
              case 'about':
                Navigator.of(context).pushNamed('/about');
                break;
            }
          },
          itemBuilder: (BuildContext context) {
            return [
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
                    SizedBox(width: 15),
                    Text('Export files list'),
                  ])),
              PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    SizedBox(width: 15),
                    Text('Settings'),
                  ])),
              if (AppLogic.platformApi.isWebAndroid() == true)
                PopupMenuItem(
                    value: 'dlapp',
                    child: Row(children: [
                      Icon(Icons.android,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black),
                      SizedBox(width: 15),
                      Text('Download the app!'),
                    ])),
              PopupMenuItem(
                  value: 'about',
                  child: Row(children: [
                    Icon(Icons.info,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                    SizedBox(width: 15),
                    Text('About'),
                  ])),
            ];
          },
        ),
      ];
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          child: ValueListenableBuilder(
              builder: (BuildContext context, List<String> selected, _) =>
                  AppBar(
                    title: selected.length > 0
                        ? Text(
                            selected.length.toString() +
                                ' file' +
                                (selected.length > 1 ? 's' : '') +
                                ' selected',
                          )
                        : Text('Uploadgram'),
                    leading: selected.length > 0
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () => selectedFiles.clear())
                        : null,
                    actions: _buildAppBarActions(),
                  ),
              valueListenable: selectedFiles),
          preferredSize: AppBar().preferredSize),
      // replace this with a future builder of _initStateAsync
      body: AppLogic.files == null
          ? Center(
              child: SizedBox(
              child: CircularProgressIndicator(),
              width: 100,
              height: 100,
            ))
          : (AppLogic.files!.length > 0 || AppLogic.uploadingQueue.length > 0)
              ? Scrollbar(
                  isAlwaysShown: MediaQuery.of(context).size.width > 950,
                  child: AppSettings.filesTheme == FilesTheme.list
                      ? FilesList(selectedFiles: selectedFiles)
                      : FilesGrid(selectedFiles: selectedFiles))
              : Center(
                  child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: 'There\'s nothing here\n',
                            style: TextStyle(fontSize: 32)),
                        TextSpan(
                            text: '...yet', style: TextStyle(fontSize: 18)),
                      ], style: Theme.of(context).textTheme.bodyText2),
                      textAlign: TextAlign.center)),
      floatingActionButton: ValueListenableBuilder(
          builder: (BuildContext context, bool _canUpload, _) => AppSettings
                      .fabTheme ==
                  FabTheme.centerExtended
              ? FloatingActionButton.extended(
                  onPressed: _uploadFile,
                  label: Text("UPLOAD"),
                  icon: _canUpload
                      ? const Icon(Icons.cloud_upload)
                      : CircularProgressIndicator())
              : AppSettings.fabTheme == FabTheme.left
                  ? FloatingActionButton(
                      onPressed: _uploadFile,
                      child: _canUpload
                          ? const Icon(Icons.cloud_upload)
                          : CircularProgressIndicator())
                  : Container(), // Temporarily, while settings are getting fetched
          valueListenable: _canUploadNotifier),
      floatingActionButtonLocation:
          AppSettings.fabTheme == FabTheme.centerExtended
              ? FloatingActionButtonLocation.centerFloat
              : AppSettings.fabTheme == FabTheme.left
                  ? FloatingActionButtonLocation.endFloat
                  : null,
    );
  }
}
