import 'package:flutter/material.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';

class SettingsRoute extends StatefulWidget {
  @override
  _SettingsRouteState createState() => _SettingsRouteState();
}

class _SettingsRouteState extends State<SettingsRoute> {
  final uploadButtonThemes = <FabTheme, String>{
    FabTheme.centerExtended: 'In the middle, with text (default)',
    FabTheme.left: 'On the left side, without text',
  };
  final filesListThemes = {
    FilesTheme.grid: 'Grid (default)',
    FilesTheme.gridCompact: 'Compact Grid',
    FilesTheme.list: 'List',
  };
  final appThemes = {
    Themes.system: 'Use system theme',
    Themes.dark: 'Dark',
    Themes.white: 'White',
  };
  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    _textEditingController.text = AppSettings.smallThumbnailSize.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(padding: EdgeInsets.all(15), children: [
        PopupMenuButton(
          child: ListTile(
            title: Text('Upload button theme'),
            subtitle: Text(uploadButtonThemes[AppSettings.fabTheme]!),
            leading: Icon(Icons.cloud_upload),
          ),
          itemBuilder: (BuildContext context) {
            return uploadButtonThemes.entries
                .map((e) => PopupMenuItem(
                    value: e.key,
                    child: ListTile(
                      title: Text(e.value),
                    )))
                .toList();
          },
          initialValue: AppSettings.fabTheme,
          onSelected: (FabTheme value) {
            if (AppSettings.fabTheme == value) return;
            setState(() => AppSettings.fabTheme = value);
          },
          tooltip: 'Select the upload button theme',
        ),
        PopupMenuButton(
          child: ListTile(
            title: Text('Files list theme'),
            subtitle: Text(filesListThemes[AppSettings.filesTheme]!),
            leading: Icon(Icons.more_horiz),
          ),
          initialValue: AppSettings.filesTheme,
          itemBuilder: (BuildContext context) => filesListThemes.entries
              .map((e) => PopupMenuItem(
                  value: e.key,
                  child: ListTile(
                    title: Text(e.value),
                  )))
              .toList(),
          onSelected: (FilesTheme value) {
            if (AppSettings.filesTheme == value) return;
            setState(() => AppSettings.filesTheme = value);
          },
          tooltip: 'Change the files list\'s theme',
        ),
        PopupMenuButton(
          child: ListTile(
            title: Text('App theme'),
            subtitle: Text(appThemes[AppSettings.appTheme]!),
            leading: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.brightness_2
                : Icons.brightness_7),
          ),
          itemBuilder: (BuildContext context) => appThemes.entries
              .map((e) => PopupMenuItem(
                  value: e.key,
                  child: ListTile(
                    title: Text(e.value),
                  )))
              .toList(),
          initialValue: AppSettings.appTheme,
          onSelected: (Themes value) {
            if (AppSettings.appTheme == value) return;
            AppSettings.appTheme = value;
            AppRebuildNotification().dispatch(context);
          },
          tooltip: 'Change the app\'s theme',
        ),
        Divider(),
        SwitchListTile(
            title: Text('Activate thumbnail generation'),
            secondary: Icon(Icons.crop_free),
            value: AppSettings.shouldGenerateThumbnails,
            onChanged: (bool value) =>
                setState(() => AppSettings.shouldGenerateThumbnails = value)),
        SwitchListTile(
            title: Text('Save full sized photos'),
            secondary: Icon(Icons.image),
            value: AppSettings.saveFullSizedImages,
            onChanged: (bool value) =>
                setState(() => AppSettings.saveFullSizedImages = value)),
        ListTile(
          leading: Icon(Icons.aspect_ratio),
          title: Text('Small thumbnail size'),
          subtitle:
              Text('Current: ${AppSettings.smallThumbnailSize.toString()}'),
          onTap: () => showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: Text('Small thumbnail size'),
                    content: Container(
                      child: Scrollbar(
                        child: ListView.builder(
                          itemBuilder: (context, index) => ListTile(
                            title: Text((index * 50 + 200).toString()),
                            selected: AppSettings.smallThumbnailSize ==
                                index * 50 + 200,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => AppSettings.smallThumbnailSize =
                                  index * 50 + 200);
                            },
                          ),
                          itemCount: 21,
                        ),
                      ),
                      height: MediaQuery.of(context).size.height > 21 * 40 + 100
                          ? MediaQuery.of(context).size.height - 100
                          : 21 * 40 + 100,
                      width: 150,
                    ),
                    actions: [
                      TextButton(
                          onPressed: Navigator.of(context).pop,
                          child: Text('CANCEL'))
                    ],
                  )),
        ),
        ListTile(
          leading: Icon(Icons.delete),
          title: Text('Clear thumbnails data'),
          onTap: () => showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: Text('Clear thumbnails data'),
                    content: FutureBuilder<ThumbnailsStats>(
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                      title: Text('Clear small thumbnails'),
                                      subtitle: Text(
                                          '${Utils.humanSize(snapshot.data!.smallThumbsSize!)} (${snapshot.data!.smallThumbsCount})'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        ThumbnailsUtils.deleteSmallThumbs();
                                      }),
                                  if (snapshot.data!.bigThumbsSize != null)
                                    ListTile(
                                      title: Text('Clear big thumbnails'),
                                      subtitle: Text(
                                          '${Utils.humanSize(snapshot.data!.bigThumbsSize!)} (${snapshot.data!.bigThumbsCount})'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        ThumbnailsUtils.deleteBigThumbs();
                                      },
                                    ),
                                  ListTile(
                                    title: Text('Clear all thumbnails'),
                                    subtitle: Text(
                                        '${Utils.humanSize((snapshot.data!.bigThumbsSize ?? 0) + snapshot.data!.smallThumbsSize!)}'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      ThumbnailsUtils.deleteSmallThumbs();
                                      ThumbnailsUtils.deleteBigThumbs();
                                    },
                                  )
                                ]);
                          }
                          return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [CircularProgressIndicator()]);
                        },
                        future: ThumbnailsUtils.getThumbnailsStats()),
                    actions: [
                      TextButton(
                          onPressed: Navigator.of(context).pop,
                          child: Text('CANCEL'))
                    ],
                  )),
        ),
        Divider(),
        ListTile(
          title: Text('Clear app\'s files cache'),
          subtitle:
              Text('Used when you upload a file not from your internal memory'),
          leading: Icon(Icons.delete),
          onTap: () async {
            await AppLogic.platformApi.clearFilesCache();
          },
        )
      ]),
    );
  }
}
