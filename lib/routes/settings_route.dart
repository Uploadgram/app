import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/app_settings.dart';

class SettingsRoute extends StatefulWidget {
  @override
  _SettingsRouteState createState() => _SettingsRouteState();
}

class _SettingsRouteState extends State<SettingsRoute> {
  AppSettings settings = AppSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(15),
        children: [
          ListTile(
            title: Text('Upload button theme',
                style: Theme.of(context).textTheme.headline5),
            subtitle: DropdownButton<FabTheme>(
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : null,
                isExpanded: true,
                value: AppSettings.fabTheme,
                items: [
                  {
                    'value': FabTheme.centerExtended,
                    'text': 'Button in the middle with text',
                  },
                  {
                    'value': FabTheme.left,
                    'text': 'Button on the left side without text'
                  }
                ]
                    .map((e) => DropdownMenuItem<FabTheme>(
                          child: Text(e['text']!.toString()),
                          value: e['value'] as FabTheme,
                        ))
                    .toList(),
                onChanged: (FabTheme? newFabTheme) {
                  setState(() => AppSettings.fabTheme = newFabTheme);
                  AppSettings.saveSettings();
                }),
          ),
          ListTile(
            title: Text('Files Theme',
                style: Theme.of(context).textTheme.headline5),
            subtitle: DropdownButton<FilesTheme>(
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : null,
                isExpanded: true,
                value: AppSettings.filesTheme,
                items: [
                  {
                    'value': FilesTheme.grid,
                    'text': 'Grid (default)',
                  },
                  {
                    'value': FilesTheme.gridCompact,
                    'text': 'Compact Grid',
                  },
                  {
                    'value': FilesTheme.list,
                    'text': 'List',
                  }
                ]
                    .map((e) => DropdownMenuItem<FilesTheme>(
                          child: Text(e['text']!.toString()),
                          value: e['value'] as FilesTheme,
                        ))
                    .toList(),
                onChanged: (FilesTheme? newFilesTheme) {
                  if (newFilesTheme == AppSettings.filesTheme) return;
                  setState(() => AppSettings.filesTheme = newFilesTheme);
                  AppSettings.saveSettings();
                }),
          ),
          ListTile(
            title:
                Text('App Theme', style: Theme.of(context).textTheme.headline5),
            subtitle: DropdownButton<Themes>(
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : null,
                isExpanded: true,
                value: AppSettings.appTheme,
                items: [
                  {
                    'value': Themes.system,
                    'text': 'Use system theme',
                  },
                  {
                    'value': Themes.dark,
                    'text': 'Dark',
                  },
                  {
                    'value': Themes.white,
                    'text': 'White',
                  },
                ]
                    .map((e) => DropdownMenuItem<Themes>(
                          child: Text(e['text']!.toString()),
                          value: e['value'] as Themes,
                        ))
                    .toList(),
                onChanged: (Themes? newTheme) {
                  if (newTheme == AppSettings.appTheme) return;
                  AppSettings.appTheme = newTheme;
                  AppSettings.saveSettings();
                  AppRebuildNotification().dispatch(context);
                }),
          ),
        ],
      ),
    );
  }
}
