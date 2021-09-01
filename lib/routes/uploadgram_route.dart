import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/config.dart';
import 'package:uploadgram/fading_page_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/main.dart';
import 'package:uploadgram/routes/file_info.dart';
import 'package:uploadgram/list_notifier.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';
import 'package:uploadgram/widgets/files_grid.dart';
import 'package:uploadgram/widgets/files_list.dart';
import 'package:uploadgram/widgets/popup_menu_item_icon.dart';
import 'package:uploadgram/widgets/selected_files_builder.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';

class SelectedFilesProvider extends ListNotifier<String> {
  SelectedFilesProvider() : super();
}

class UploadgramRoute extends StatefulWidget {
  const UploadgramRoute({Key? key}) : super(key: key);

  static _UploadgramRouteState? of(BuildContext context) =>
      context.findAncestorStateOfType<_UploadgramRouteState>();

  @override
  _UploadgramRouteState createState() => _UploadgramRouteState();
}

class _UploadgramRouteState extends State<UploadgramRoute>
    with WidgetsBindingObserver {
  int _checkSeconds = 0;
  Timer? _lastConnectivityTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final ValueNotifier<bool> _canUploadNotifier = ValueNotifier<bool>(false);
  final _selectedFiles = SelectedFilesProvider();

  late Future _future;
  final _key = GlobalKey<State<FilesViewerTheme>>();

  static final _logger = Logger('_UploadgramRouteState');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _lastConnectivityTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        checkConnection();
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  void selectWidget(String id) => _selectedFiles.contains(id)
      ? _selectedFiles.remove(id)
      : _selectedFiles.add(id);

  Future<T?> openFileInfo<T>({
    required UploadedFile file,
    required ValueNotifier<String> filenameNotifier,
    required IconData icon,
    Object? tag,
  }) =>
      Navigator.of(context).push<T>(FadingPageRoute(FileInfoRoute(
        file: file,
        filename: filenameNotifier,
        fileIcon: icon,
        tag: tag,
        handleRename: handleFileRename,
        handleDelete: (delete, {Function? onYes}) =>
            handleFileDelete([delete], onYes: onYes),
      )));

  Future<void> handleFileRename(
    String delete, {
    Function(String)? onDone,
    String? newName,
    String? oldName = '',
  }) async {
    onDone ??= (_) => null;
    final localizations = AppLocalizations.of(context);
    if (newName == null) {
      return showDialog(
          context: context,
          builder: (BuildContext context) {
            String _text = '';
            return AlertDialog(
              title: Text(localizations.dialogRenameTitle),
              content: TextFormField(
                initialValue: oldName,
                maxLength: 255,
                showCursor: true,
                onChanged: (newText) => _text = newText,
                decoration: const InputDecoration(filled: true),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(localizations.dialogCancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    handleFileRename(delete, onDone: onDone, newName: _text);
                    _selectedFiles.clear();
                  },
                  child: Text(localizations.dialogOK),
                )
              ],
            );
          });
    }
    AppLogic.showFullscreenLoader(context);
    RenameApiResponse result =
        await WebAPIWrapper().renameFile(delete, newName);
    if (result.ok) {
      onDone(result.newName!);
      (await UploadedFiles()[delete])!.name = result.newName!;
    } else if (result.statusCode == 403) {
      await UploadedFiles().remove(delete);
      Navigator.pop(context);
      refreshList();
      ScaffoldMessenger.of(context).snack(localizations.errorFileNotFound);
    } else {
      ScaffoldMessenger.of(context).snack(result.errorMessage!);
    }
  }

  Future<void> handleFileDelete(List<String> deleteList,
      {noDialog = false, Function? onYes}) async {
    if (deleteList.isEmpty) return;
    onYes ??= () => null;
    final localizations = AppLocalizations.of(context);
    int listLength = deleteList.length;

    if (!noDialog) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(localizations.dialogDeleteTitle),
              content: Text(localizations.dialogDeleteDescription(listLength)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.dialogNo),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    handleFileDelete(deleteList, noDialog: true);
                    onYes?.call();
                  },
                  child: Text(localizations.dialogYes),
                ),
              ],
            );
          });
    } else {
      String? _message;
      List<String> deletedFiles = [];
      final progressNotifier = ValueNotifier<double?>(null);
      AppLogic.showFullscreenLoader(context, progressNotifier);
      int i = 0;
      for (String delete in deleteList) {
        _logger.info('deleting $delete');
        try {
          DeleteApiResponse result = await WebAPIWrapper().deleteFile(delete);
          if (result.statusCode == 403) {
            _message = localizations.errorFileNotFound;
          } else if (!result.ok) {
            _message = localizations
                .errorSomeFilesHaveNotBeenDeleted(result.statusCode);
            continue;
          }

          deletedFiles.add(delete);
        } on DioError catch (e) {
          _message = localizations.errorUnknown(e.message);
        } finally {
          progressNotifier.value = ++i / deleteList.length;
        }
      }
      if (_message != null) ScaffoldMessenger.of(context).snack(_message);
      for (String delete in deletedFiles) {
        await UploadedFiles().remove(delete);
        await ThumbnailsUtils.deleteThumbsForFile(delete);
      }
      Navigator.pop(context);

      refreshList();
    }
  }

  Future<void> _uploadFile() async {
    if (_canUploadNotifier.value == false) _checkUploadgramConnection();
    if (_canUploadNotifier.value == false) return;
    final localizations = AppLocalizations.of(context);
    if (settings.tosAccepted == false) {
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: Text(localizations.tosDialogTitle),
                content: SingleChildScrollView(
                    child: Text(localizations.tosDialogContent)),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .snack(localizations.tosErrorDisagree);
                    },
                    child: Text(localizations.tosDialogDisagree),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      settings.tosAccepted = true;
                      ScaffoldMessenger.of(context)
                          .snack(localizations.tosDialogOK);
                      _uploadFile();
                    },
                    child: Text(localizations.tosDialogAgree),
                  ),
                ],
              ));
      return;
    }
    _logger.info('asking for file');
    UploadgramFile? file = await InternalAPIWrapper().askForFile();
    if (file == null) return;

    return await uploadFile(file);
  }

  Future<void> uploadFile(UploadgramFile file) async {
    final localizations = AppLocalizations.of(context);
    if (file.size == 0) {
      ScaffoldMessenger.of(context).snack(localizations.errorFileEmpty);
      return;
    }
    if (UploadedFiles().length >= 5 &&
        InternalAPIWrapper().isWebAndroid() &&
        settings.hasAskedApp) {
      settings.hasAskedApp = true;
      showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
                title: Text(localizations.dialogDownloadAppTitle),
                content: Text(localizations.dialogDownloadAppSubtitle),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(localizations.dialogDownloadAppNo),
                  ),
                  TextButton(
                    onPressed: WebAPIWrapper().downloadApp,
                    child: Text(localizations.dialogDownloadAppYes),
                  ),
                ],
              ));
    }
    _logger.info('got file ${file.name}');
    if (file.size > maxUploadSize) {
      ScaffoldMessenger.of(context).snack(
          localizations.errorFileTooLarge(Utils.humanSize(maxUploadSize)));
      return;
    }
    WebAPIWrapper().enqueueUpload(file).then((value) => refreshList());
  }

  void refreshList() {
    if (_key.currentState == null ||
        !_key.currentState!.mounted ||
        UploadedFiles().length == 0) {
      setState(() {});
      return;
    }
    _key.currentState!.setState(() {});
  }

  void onOnlineChanged() {
    if (_canUploadNotifier.value) {
      checkForUpdates(context);
    }
  }

  @override
  void initState() {
    SchedulerBinding.instance!.addPostFrameCallback((timeStamp) {
      initializeOrRefreshNotifications(AppLocalizations.of(context));
    });
    _future = _initStateAsync();
    _canUploadNotifier.addListener(onOnlineChanged);
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }

  Future<void> _initStateAsync() async {
    await AppLogic.getFiles();
    await WebAPIWrapper().ensureInitialized();
    await ThumbnailsMemoryCache.init();
    if (kIsWeb) {
      checkConnection();
      InternalAPIWrapper.listenDropzone(context, uploadFile);
    }
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_checkConnection);
  }

  Future<void> checkConnection() =>
      Connectivity().checkConnectivity().then(_checkConnection);

  Future<void> _checkConnection(ConnectivityResult connectivityResult) async {
    _canUploadNotifier.value = false;
    _logger.info('Check connection called.');
    if (connectivityResult != ConnectivityResult.none) {
      // if (connectivityResult == ConnectivityResult.mobile)
      //   ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text('WARNING: You are using Mobile Data!')));
      return _checkUploadgramConnection();
    }
  }

  Future<void> _checkUploadgramConnection() async {
    _lastConnectivityTimer?.cancel();
    if (await WebAPIWrapper().checkNetwork()) {
      _canUploadNotifier.value = true;
    } else {
      if (_checkSeconds < 90) _checkSeconds += 15;
      final localizations = AppLocalizations.of(context);
      _lastConnectivityTimer =
          Timer(Duration(seconds: _checkSeconds), _checkUploadgramConnection);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).snack(
          localizations.errorUploadgramDown(_checkSeconds),
          action: SnackBarAction(
              label: localizations.actionSnackbarTryNow,
              onPressed: _checkUploadgramConnection),
          duration: Duration(seconds: _checkSeconds));
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _lastConnectivityTimer?.cancel();
    WidgetsBinding.instance?.removeObserver(this);
    _selectedFiles.dispose();

    _canUploadNotifier.removeListener(onOnlineChanged);
    _canUploadNotifier.dispose();
    super.dispose();
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];
    final localizations = AppLocalizations.of(context);
    if (_selectedFiles.length > 0) {
      actions = [
        if (_selectedFiles.length < UploadedFiles().length)
          IconButton(
            key: const Key('select_all'),
            icon: const Icon(Icons.select_all),
            onPressed: () =>
                _selectedFiles.value = List<String>.from(UploadedFiles().keys),
            tooltip: localizations.selectAllTooltip,
          ),
        IconButton(
          key: const Key('delete'),
          icon: const Icon(Icons.delete),
          onPressed: () {
            handleFileDelete(List.from(_selectedFiles.value),
                onYes: () => _selectedFiles.clear());
          },
          tooltip: localizations.deleteAppbarTooltip,
        ),
        IconButton(
          key: const Key('export'),
          icon: const Icon(Icons.get_app),
          onPressed: () async {
            final Map<String, UploadedFile> _exportFiles = await Future.wait(
                    _selectedFiles.value.map((e) => UploadedFiles()[e]
                        .then((value) => MapEntry(e, value!))))
                .then((value) => Map.fromEntries(value));
            final _result =
                await InternalAPIWrapper().exportFiles(_exportFiles);
            if (_result == false || _result == null) {
              ScaffoldMessenger.of(context).snack(localizations.exportingError);
            }
          },
          tooltip: localizations.exportListTooltip,
        )
      ];
    } else {
      sortButtonBuilder(context) => ValueListenableBuilder(
            valueListenable: UploadedFiles().listenable,
            builder: (context, _, __) {
              if (UploadedFiles().length > 1) {
                return IconButton(
                    tooltip: localizations.sortTooltip,
                    icon: const Icon(Icons.sort),
                    onPressed: () => showDialog<SortOptions>(
                                context: context,
                                builder: (BuildContext context) => SortByDialog(
                                    sortOptions: settings.preferredSortOptions))
                            .then((SortOptions? sortOptions) async {
                          if (sortOptions != null) {
                            AppLogic.showFullscreenLoader(context);
                            if (await UploadedFiles().sort(sortOptions)) {
                              refreshList();
                            }
                            settings.preferredSortOptions = sortOptions;
                            Navigator.pop(context);
                          }
                        }));
              }
              return const SizedBox();
            },
          );
      final Widget sortButton;
      if (!UploadedFiles().isInitialized) {
        sortButton = FutureBuilder(
          builder: (context, snapshot) =>
              snapshot.connectionState == ConnectionState.done
                  ? sortButtonBuilder(context)
                  : const SizedBox(),
          future: _future,
        );
      } else {
        sortButton = sortButtonBuilder(context);
      }
      actions = [
        sortButton,
        PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (UploadgramMoreSettingsAction selected) async {
              switch (selected) {
                case UploadgramMoreSettingsAction.exportFiles:
                  if (UploadedFiles().isEmpty) {
                    ScaffoldMessenger.of(context)
                        .snack(localizations.exportingErrorEmpty);
                    break;
                  }
                  if (await InternalAPIWrapper()
                          .exportFiles(await UploadedFiles().toJson()) !=
                      true) {
                    ScaffoldMessenger.of(context)
                        .snack(localizations.exportingError);
                  }
                  break;
                case UploadgramMoreSettingsAction.importFiles:
                  Map? _importedFiles;
                  try {
                    _importedFiles = await InternalAPIWrapper().importFiles();
                  } catch (e) {
                    _logger.finest(e);
                    _importedFiles = null;
                  }
                  if (_importedFiles == null) {
                    ScaffoldMessenger.of(context)
                        .snack(localizations.importingErrorInvalid);
                    break;
                  }
                  UploadedFiles()
                      .addAll(
                          _importedFiles.cast<String, Map<dynamic, dynamic>>())
                      .then((value) => refreshList());
                  break;
                case UploadgramMoreSettingsAction.settingsTile:
                  List previousSettings = [
                    settings.fabTheme,
                    settings.filesTheme
                  ];
                  Endpoint previousEndpoints = settings.endpoint;
                  Navigator.pushNamed(context, '/settings').then((value) {
                    if (previousEndpoints != settings.endpoint) {
                      checkConnection();
                    }
                    if (!listEquals(previousSettings, [
                      settings.fabTheme,
                      settings.filesTheme
                    ])) setState(() {});
                  });
                  break;
                case UploadgramMoreSettingsAction.downloadApp:
                  WebAPIWrapper().downloadApp();
                  break;
                case UploadgramMoreSettingsAction.aboutTile:
                  Navigator.of(context).pushNamed('/about');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
                  PopupMenuItemIcon(
                    value: UploadgramMoreSettingsAction.importFiles,
                    child: Text(localizations.importTileTitle),
                    icon: const Icon(Icons.publish),
                  ),
                  PopupMenuItemIcon(
                    value: UploadgramMoreSettingsAction.exportFiles,
                    child: Text(localizations.exportTileTitle),
                    icon: const Icon(Icons.get_app),
                  ),
                  PopupMenuItemIcon(
                    value: UploadgramMoreSettingsAction.settingsTile,
                    child: Text(localizations.settingsTitle),
                    icon: const Icon(Icons.settings),
                  ),
                  if (InternalAPIWrapper().isWebAndroid() == true)
                    PopupMenuItemIcon(
                      value: UploadgramMoreSettingsAction.downloadApp,
                      child: Text(localizations.downloadAppTileTitle),
                      icon: const Icon(Icons.android),
                    ),
                  PopupMenuItemIcon(
                    value: UploadgramMoreSettingsAction.aboutTile,
                    child: Text(localizations.aboutTitle),
                    icon: const Icon(Icons.info),
                  ),
                ]),
      ];
    }
    return actions;
  }

  /// Before actually exiting the app, it will first check
  /// if [_selectedFiles] has elements, if there are, it will clear
  /// the list instead of exiting, if there aren't it will just exit.
  Future<bool> onWillPop() async {
    if (_selectedFiles.isEmpty) return true;
    _selectedFiles.clear();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final currentLocale = Localizations.localeOf(context);

    final isLargeScreen = MediaQuery.of(context).size.width > 905;
    // ignore: unused_local_variable, will be used later on
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    if (AppLogic.currentLocale.value != currentLocale) {
      AppLogic.currentLocale.value = currentLocale;
    }
    return FutureBuilder(
        // This will show a blank screen while the app is doing its work
        builder: (context, snapshot) => WillPopScope(
            onWillPop: onWillPop,
            child: ChangeNotifierProvider.value(
              value: _selectedFiles,
              child: Scaffold(
                appBar: PreferredSize(
                    child: FilesSelectedBuilder(
                        builder: (BuildContext context, int selected, _) =>
                            AppBar(
                              backgroundColor:
                                  selected > 0 ? Colors.black87 : null,
                              foregroundColor:
                                  selected > 0 ? Colors.white : null,
                              title: selected > 0
                                  ? Text(
                                      localizations
                                          .titleFilesSelected(selected),
                                    )
                                  : const Text('Uploadgram'),
                              leading: selected > 0
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => _selectedFiles.clear())
                                  : null,
                              actions: _buildAppBarActions(),
                            )),
                    preferredSize: AppBar().preferredSize),
                body: SafeArea(
                  child: snapshot.connectionState == ConnectionState.done
                      ? UploadedFiles().length > 0 || AppLogic.queue.isNotEmpty
                          ? Scrollbar(
                              isAlwaysShown: isLargeScreen,
                              child: settings.filesTheme == FilesTheme.list
                                  ? FilesList(key: _key)
                                  : FilesGrid(key: _key))
                          : Center(
                              child: RichText(
                                  text: TextSpan(
                                      children: [
                                        TextSpan(
                                            text: localizations.noFilesTitle,
                                            style:
                                                const TextStyle(fontSize: 32)),
                                        const TextSpan(text: '\n'),
                                        TextSpan(
                                            text: localizations.noFilesSubtitle,
                                            style:
                                                const TextStyle(fontSize: 18)),
                                      ],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2),
                                  textAlign: TextAlign.center))
                      : const Center(child: CircularProgressIndicator()),
                ),
                floatingActionButton: snapshot.connectionState ==
                        ConnectionState.done
                    ? ValueListenableBuilder(
                        builder: (BuildContext context, bool _canUpload, _) =>
                            settings.fabTheme == FabTheme.centerExtended
                                ? FloatingActionButton.extended(
                                    onPressed: _uploadFile,
                                    label:
                                        Text(localizations.uploadExtendedFAB),
                                    icon: _canUpload
                                        ? const Icon(Icons.cloud_upload)
                                        : const CircularProgressIndicator(
                                            color: Colors.white))
                                : FloatingActionButton(
                                    onPressed: _uploadFile,
                                    child: _canUpload
                                        ? const Icon(Icons.cloud_upload)
                                        : const CircularProgressIndicator(
                                            color: Colors.white)),
                        valueListenable: _canUploadNotifier)
                    : null,
                floatingActionButtonLocation:
                    snapshot.connectionState == ConnectionState.done
                        ? (settings.fabTheme == FabTheme.centerExtended
                            ? FloatingActionButtonLocation.centerFloat
                            : FloatingActionButtonLocation.endFloat)
                        : null,
              ),
            )),
        future: _future);
  }
}

class SortByDialog extends StatefulWidget {
  final SortOptions? sortOptions;
  const SortByDialog({Key? key, this.sortOptions}) : super(key: key);

  @override
  _SortByDialogState createState() => _SortByDialogState();
}

class _SortByDialogState extends State<SortByDialog> {
  SortType _sortType = SortType.descending;
  SortBy _sortBy = SortBy.name;

  @override
  void initState() {
    if (widget.sortOptions != null) {
      _sortBy = widget.sortOptions!.sortBy;
      _sortType = widget.sortOptions!.sortType;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
        title: Text(localizations.sortByDialogTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile(
            value: SortBy.name,
            groupValue: _sortBy,
            onChanged: (SortBy? value) => setState(() => _sortBy = value!),
            title: Text(localizations.nameText),
          ),
          RadioListTile(
            value: SortBy.size,
            groupValue: _sortBy,
            onChanged: (SortBy? value) => setState(() => _sortBy = value!),
            title: Text(localizations.sizeText),
          ),
          RadioListTile(
            value: SortBy.uploadDate,
            groupValue: _sortBy,
            onChanged: (SortBy? value) => setState(() => _sortBy = value!),
            title: Text(localizations.uploadDateText),
          ),
          const Divider(),
          CheckboxListTile(
              title: Text(localizations.sortByDialogAscending),
              value: _sortType == SortType.ascending,
              onChanged: (bool? value) {
                if (value == null) return;
                setState(() => _sortType =
                    value ? SortType.ascending : SortType.descending);
              }),
        ]),
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop,
              child: Text(localizations.dialogCancel)),
          TextButton(
              onPressed: () => Navigator.pop(
                  context, SortOptions(sortBy: _sortBy, sortType: _sortType)),
              child: Text(localizations.dialogOK))
        ]);
  }
}
