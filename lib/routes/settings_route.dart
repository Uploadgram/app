import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/config.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';

class SettingsRoute extends StatefulWidget {
  const SettingsRoute({Key? key}) : super(key: key);

  @override
  _SettingsRouteState createState() => _SettingsRouteState();
}

class _SettingsRouteState extends State<SettingsRoute> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final uploadButtonThemes = <FabTheme, String>{
      FabTheme.centerExtended: localizations.uploadButtonThemesCenterExtended,
      FabTheme.left: localizations.uploadButtonThemesRight,
    };
    final filesListThemes = {
      FilesTheme.grid: localizations.filesListThemesGrid,
      FilesTheme.gridCompact: localizations.filesListThemesGridCompact,
      FilesTheme.list: localizations.filesListThemesList,
    };
    final appThemes = {
      Themes.system: localizations.appThemesSystem,
      Themes.dark: localizations.appThemesDark,
      Themes.light: localizations.appThemesLight,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settingsTitle),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16.0), children: [
          Text(localizations.sectionPersonalizationText,
              style: Theme.of(context).textTheme.overline),
          const Divider(),
          PopupMenuButton(
            child: ListTile(
              title: Text(localizations.uploadButtonTheme),
              subtitle: Text(uploadButtonThemes[settings.fabTheme]!),
              leading: const Icon(Icons.cloud_upload),
            ),
            itemBuilder: (BuildContext context) {
              return uploadButtonThemes.entries
                  .map((e) => PopupMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList();
            },
            initialValue: settings.fabTheme,
            onSelected: (FabTheme value) {
              if (settings.fabTheme == value) return;
              setState(() => settings.fabTheme = value);
            },
            tooltip: localizations.uploadButtonThemeTooltip,
          ),
          PopupMenuButton(
            child: ListTile(
              title: Text(localizations.filesListTheme),
              subtitle: Text(filesListThemes[settings.filesTheme]!),
              leading: const Icon(Icons.more_horiz),
            ),
            initialValue: settings.filesTheme,
            itemBuilder: (BuildContext context) => filesListThemes.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onSelected: (FilesTheme value) {
              if (settings.filesTheme == value) return;
              setState(() => settings.filesTheme = value);
            },
            tooltip: localizations.filesListThemeTooltip,
          ),
          PopupMenuButton(
            child: ListTile(
              title: Text(localizations.appThemeTileTitle),
              subtitle: Text(appThemes[settings.appTheme]!),
              leading: Icon(Theme.of(context).brightness == Brightness.dark
                  ? Icons.brightness_2
                  : Icons.brightness_7),
            ),
            itemBuilder: (BuildContext context) => appThemes.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            initialValue: settings.appTheme,
            onSelected: (Themes value) {
              if (settings.appTheme == value) return;
              settings.appTheme = value;
              AppRebuildNotification().dispatch(context);
            },
            tooltip: localizations.appThemeTileTooltip,
          ),
          if (InternalAPIWrapper.isAndroid)
            SwitchListTile(
              value: settings.syncAccentWithSystem,
              onChanged: (value) {
                settings.syncAccentWithSystem = value;
                AppLogic.updateAccent()
                    .then((_) => AppRebuildNotification().dispatch(context));
              },
              secondary: const Icon(Icons.sync),
              title: Text(localizations.syncAccentWithSystemTileTitle),
            ),
          ListTile(
            leading: const Icon(Icons.format_paint),
            title: Text(localizations.accentColorTileTitle),
            enabled: !settings.syncAccentWithSystem,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(backgroundColor: settings.accent),
              const SizedBox(width: 8.0)
            ]),
            onTap: () => showDialog(
                context: context,
                builder: (context) => ColorPickerDialog(
                    defaultColor: settings.accent,
                    onColorChosen: (color) {
                      AppLogic.setAccent(color).then(
                          (_) => AppRebuildNotification().dispatch(context));
                    })),
          ),

          ListTile(
              title: Text(localizations.languageTileTitle),
              subtitle: Text(
                  localizations.languageTileSubtitle(localizations.language)),
              leading: const Icon(Icons.language),
              onTap: () => showDialog(
                    context: context,
                    builder: (context) => const LanguageDialog(),
                  )),
          const SizedBox(height: 16.0),
          Text(localizations.sectionThumbnailsText,
              style: Theme.of(context).textTheme.overline),
          const Divider(),
          SwitchListTile(
              title: Text(localizations.toggleThumbnailGeneration),
              secondary: const Icon(Icons.crop_free),
              value: settings.shouldGenerateThumbnails,
              onChanged: (bool value) =>
                  setState(() => settings.shouldGenerateThumbnails = value)),
          SwitchListTile(
              title: Text(localizations.saveFullSizedPhotos),
              secondary: const Icon(Icons.image),
              value: settings.saveFullSizedImages,
              onChanged: (bool value) =>
                  setState(() => settings.saveFullSizedImages = value)),
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: Text(localizations.smallThumbnailSize),
            subtitle: Text(localizations.smallThumbnailSizeSubtitle(
                '${settings.smallThumbnailSize}x${settings.smallThumbnailSize}')),
            onTap: () => showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                      title: Text(localizations.smallThumbnailSize),
                      content: SizedBox(
                        child: Scrollbar(
                          child: ListView.builder(
                            itemBuilder: (context, index) => ListTile(
                              title: Text(
                                  '${index * 50 + 200}x${index * 50 + 200}'),
                              selected: settings.smallThumbnailSize ==
                                  index * 50 + 200,
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => settings.smallThumbnailSize =
                                    index * 50 + 200);
                              },
                            ),
                            itemCount: 21,
                          ),
                        ),
                        height:
                            MediaQuery.of(context).size.height > 21 * 40 + 100
                                ? MediaQuery.of(context).size.height - 100
                                : 21 * 40 + 100,
                        width: 150,
                      ),
                      actions: [
                        TextButton(
                            onPressed: Navigator.of(context).pop,
                            child: Text(localizations.dialogCancel))
                      ],
                    )),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(localizations.clearThumbnailsData),
            onTap: () => showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                      title: Text(localizations.clearThumbnailsData),
                      content: FutureBuilder<ThumbnailsStats>(
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                        title: Text(
                                            localizations.clearSmallThumbnails),
                                        subtitle: Text(
                                            '${Utils.humanSize(snapshot.data!.smallThumbsSize!)} (${snapshot.data!.smallThumbsCount})'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ThumbnailsUtils.deleteSmallThumbs();
                                        }),
                                    if (snapshot.data!.bigThumbsSize != null)
                                      ListTile(
                                        title: Text(
                                            localizations.clearBigThumbnails),
                                        subtitle: Text(
                                            '${Utils.humanSize(snapshot.data!.bigThumbsSize!)} (${snapshot.data!.bigThumbsCount})'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          ThumbnailsUtils.deleteBigThumbs();
                                        },
                                      ),
                                    ListTile(
                                      title: Text(
                                          localizations.clearAllThumbnails),
                                      subtitle: Text(Utils.humanSize(
                                          (snapshot.data!.bigThumbsSize ?? 0) +
                                              snapshot.data!.smallThumbsSize!)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        ThumbnailsUtils.deleteAllThumbs();
                                      },
                                    )
                                  ]);
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                  3,
                                  (i) => ListTile(
                                      title: Shimmer(
                                          duration: const Duration(seconds: 4),
                                          child: Container(
                                            height: 10.0,
                                            decoration: BoxDecoration(
                                                color: Colors.grey
                                                    .withOpacity(0.25),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        15.0)),
                                          )),
                                      subtitle: UnconstrainedBox(
                                        child: Shimmer(
                                            duration:
                                                const Duration(seconds: 4),
                                            child: Container(
                                                width: 10.0,
                                                height: 10.0,
                                                decoration: BoxDecoration(
                                                    color: Colors.grey
                                                        .withOpacity(0.25),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15.0)))),
                                      ))),
                            );
                          },
                          future: ThumbnailsUtils.getThumbnailsStats()),
                      actions: [
                        TextButton(
                            onPressed: Navigator.of(context).pop,
                            child: Text(localizations.dialogCancel))
                      ],
                    )),
          ),
          ListTile(
              title: Text(localizations.generateThumbnailsTileTitle),
              subtitle: Text(localizations.generateThumbnailsTileSubtitle),
              leading: const Icon(Icons.add_to_photos),
              onTap: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                          title:
                              Text(localizations.generateThumbnailsDialogTitle),
                          content: Text(
                              localizations.generateThumbnailsDialogSubtitle),
                          actions: [
                            TextButton(
                                child: Text(localizations.dialogNo),
                                onPressed: () => Navigator.pop(context)),
                            TextButton(
                                child: Text(localizations.dialogYes),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  for (final delete in UploadedFiles().keys) {
                                    final file =
                                        (await UploadedFiles()[delete])!;
                                    if (canGenerateThumbnail(
                                        file.size, file.name)) {
                                      await ThumbnailsMemoryCache.schedule(
                                          delete);
                                    }
                                  }
                                })
                          ]))),
          const Divider(),
          if (InternalAPIWrapper.isNative) ...[
            const _CheckForUpdatesTile(),
            ListTile(
              title: Text(localizations.appLogs),
              subtitle: Text(localizations.appLogsSubtitle),
              leading: const Icon(Icons.receipt),
              onTap: () => Navigator.pushNamed(context, '/logs'),
            ),
          ],
          // TODO: uncomment
          // ListTile(
          //   title: Text(localizations.changeEndpoints),
          //   subtitle: Text(localizations.changeEndpointsSubtitle),
          //   leading: Icon(Icons.dns),
          //   onTap: () => showDialog(
          //       context: context, builder: (context) => EndpointDialog()),
          // ),
          ListTile(
            title: Text(localizations.clearAppFilesCache),
            subtitle: Text(localizations.clearAppFilesCacheSubtitle),
            leading: const Icon(Icons.delete),
            onTap: () => InternalAPIWrapper().clearFilesCache(),
          )
        ]),
      ),
    );
  }
}

class _CheckForUpdatesTile extends StatefulWidget {
  const _CheckForUpdatesTile({Key? key}) : super(key: key);

  @override
  __CheckForUpdatesTileState createState() => __CheckForUpdatesTileState();
}

class __CheckForUpdatesTileState extends State<_CheckForUpdatesTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  late final Animation<double> _animation = ReverseAnimation(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkForUpdates() async {
    if (_controller.isAnimating) return;
    final localizations = AppLocalizations.of(context);
    _controller.repeat();
    checkForUpdates(context,
            force: true,
            countIgnoredUpdates: true,
            shouldShowNotification: false)
        .then((isUpdateAvailable) {
      _controller.forward();
      if (isUpdateAvailable != true) {
        ScaffoldMessenger.of(context)
            .snack(localizations.updaterNoUpdatesAvailable);
      }
    }).catchError((err, stacktrace) {
      _controller.reset();
      ScaffoldMessenger.of(context).snack(localizations.updaterError);
      Logger('Updater').severe(err.toString() + '\n\n' + stacktrace.toString());
      assert(() {
        throw err;
      }());
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return ListTile(
      title: Text(localizations.checkForUpdatesTile),
      subtitle: Text(localizations.checkForUpdatesTileSubtitle),
      leading:
          RotationTransition(turns: _animation, child: const Icon(Icons.sync)),
      onTap: _checkForUpdates,
    );
  }
}

class EndpointDialog extends StatefulWidget {
  const EndpointDialog({Key? key}) : super(key: key);

  @override
  _EndpointDialogState createState() => _EndpointDialogState();
}

class _EndpointDialogState extends State<EndpointDialog> {
  final TextEditingController _mainTextController = TextEditingController();
  final TextEditingController _downloadTextController = TextEditingController();
  final TextEditingController _apiTextController = TextEditingController();

  bool hasEdited = false;
  bool isEditing = false;

  @override
  void initState() {
    _mainTextController.value = TextEditingValue(text: settings.endpoint.main);
    _downloadTextController.value =
        TextEditingValue(text: settings.endpoint.download);
    _apiTextController.value = TextEditingValue(text: settings.endpoint.api);

    _mainTextController.addListener(() {
      if (!hasEdited && isEditing) {
        _downloadTextController.value =
            _apiTextController.value = _mainTextController.value;
      } else {
        isEditing = true;
      }
    });
    _downloadTextController.addListener(() {
      if (_downloadTextController.value != _mainTextController.value) {
        hasEdited = true;
      }
    });
    _apiTextController.addListener(() {
      if (_apiTextController.value != _mainTextController.value) {
        hasEdited = true;
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.endpointsText),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
            controller: _mainTextController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              hintText: defaultEndpoint.main,
              labelText: localizations.endpointsMain,
            )),
        const SizedBox(height: 15.0),
        TextFormField(
            controller: _downloadTextController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              hintText: defaultEndpoint.download,
              labelText: localizations.endpointsDownload,
            )),
        const SizedBox(height: 15.0),
        TextFormField(
            controller: _apiTextController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              hintText: defaultEndpoint.api,
              labelText: localizations.endpointsAPI,
            )),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.dialogCancel)),
        TextButton(
            onPressed: () {
              Navigator.pop(context);
              settings.endpoint = null;
            },
            child: Text(localizations.endpointsDialogActionDefault)),
        TextButton(
            onPressed: () {
              settings.endpoint = Endpoint(
                  main: _mainTextController.value.text,
                  download: _downloadTextController.value.text,
                  api: _apiTextController.value.text);
              Navigator.pop(context);
            },
            child: Text(localizations.endpointsDialogActionSave))
      ],
    );
  }
}

class LanguageDialog extends StatefulWidget {
  const LanguageDialog({Key? key}) : super(key: key);

  @override
  _LanguageDialogState createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<LanguageDialog> {
  late Locale? _selectedLocale = settings.locale;
  late Iterable<Widget> localeTiles = AppLocalizations.supportedLocales
      .map((locale) => FutureBuilder<AppLocalizations>(
            builder: (context, snapshot) => snapshot.hasData
                ? RadioListTile<Locale>(
                    title: Text(snapshot.data!.language),
                    subtitle: Text(locale.toLanguageTag()),
                    value: locale,
                    groupValue: _selectedLocale,
                    onChanged: (locale) =>
                        setState(() => _selectedLocale = locale))
                : ListTile(
                    title: Shimmer(
                        child: UnconstrainedBox(
                      child: Container(
                        width: 30.0,
                        height: 10.0,
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(15.0)),
                      ),
                    )),
                    subtitle: Shimmer(child: const SizedBox())),
            future: AppLocalizations.delegate
                .load(locale), // Maybe there is a better way to handle this.
          ));

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.selectLanguageDialogTitle),
      content: Scrollbar(
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            RadioListTile<Locale?>(
                title: Text(localizations.languageSystemText),
                value: null,
                groupValue: _selectedLocale,
                onChanged: (locale) =>
                    setState(() => _selectedLocale = locale)),
            ...localeTiles
          ]))),
      actions: [
        TextButton(
            child: Text(localizations.dialogCancel),
            onPressed: () => Navigator.pop(context)),
        TextButton(
            child: Text(localizations.dialogOK),
            onPressed: () {
              settings.locale = _selectedLocale;
              Navigator.pop(context);
              AppRebuildNotification().dispatch(context);
            }),
      ],
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  final colors = Colors.primaries;
  final Color? defaultColor;
  final Function(Color) onColorChosen;

  const ColorPickerDialog({
    Key? key,
    required this.onColorChosen,
    this.defaultColor,
  }) : super(key: key);

  @override
  _ColorPickerDialogState createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color? selectedColor = widget.defaultColor;

  @override
  void initState() {
    selectedColor = widget.defaultColor ?? Colors.blue;
    super.initState();
  }

  bool isBright(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.light;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
        title: Text(localizations.pickAccentColor),
        content: SizedBox(
          width: 300.0,
          child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 56.0,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 16.0),
              shrinkWrap: true,
              itemCount: widget.colors.length,
              itemBuilder: (context, index) => Material(
                    type: MaterialType.circle,
                    borderOnForeground: true,
                    color: widget.colors[index],
                    elevation: 2.0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      child: selectedColor?.value == widget.colors[index].value
                          ? Icon(Icons.done,
                              color: isBright(widget.colors[index])
                                  ? Colors.black
                                  : Colors.white)
                          : null,
                      onTap: () =>
                          setState(() => selectedColor = widget.colors[index]),
                    ),
                  )),
        ),
        actions: [
          TextButton(
              child: Text(localizations.dialogCancel),
              onPressed: () => Navigator.pop(context)),
          TextButton(
              child: Text(localizations.dialogOK),
              onPressed: () {
                if (selectedColor == null) return;
                widget.onColorChosen.call(selectedColor!);
                Navigator.pop(context);
              }),
        ]);
  }
}
