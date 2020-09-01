import 'package:flutter/material.dart';
import 'package:uploadgram/appSettings.dart';

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
      body: Container(
        padding: EdgeInsets.all(15),
        child: ListView(
          children: [
            ListTile(
              title: Text('Upload button theme',
                  style: Theme.of(context).textTheme.headline5),
              subtitle: DropdownButton(
                  value: AppSettings.fabTheme,
                  items: [
                    {
                      'value': 'extended',
                      'text': 'Button with text',
                    },
                    {
                      'value': 'compact',
                      'text': 'Button on the left side without text'
                    }
                  ]
                      .map((e) => DropdownMenuItem(
                            child: Text(e['text']),
                            value: e['value'],
                          ))
                      .toList(),
                  onChanged: (a) => setState(() => AppSettings.fabTheme = a)),
            ),
            ListTile(
              title:
                  Text('Theme', style: Theme.of(context).textTheme.headline5),
              subtitle: DropdownButton(
                  value: AppSettings.filesTheme,
                  items: [
                    {
                      'value': 'new',
                      'text': 'New theme (default)',
                    },
                    {'value': 'new_compact', 'text': 'New theme but compact'}
                  ]
                      .map((e) => DropdownMenuItem(
                            child: Text(e['text']),
                            value: e['value'],
                          ))
                      .toList(),
                  onChanged: (a) {
                    setState(() => AppSettings.filesTheme = a);
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
