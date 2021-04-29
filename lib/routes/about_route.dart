// write about shit bla bla
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:uploadgram/widgets/uploadgram_logo.dart';

class AboutRoute extends StatefulWidget {
  @override
  _AboutRouteState createState() => _AboutRouteState();
}

class _AboutRouteState extends State<AboutRoute> {
  final List<MapEntry> _authors = {
    'Pato05': {
      'subtitle': 'Current Uploadgram owner, wrote backend and frontend',
      'contacts': {
        'Telegram': 'https://t.me/Pato05',
        'Github': 'https://github.com/Pato05',
        'Website': 'https://pato05mc.tk',
      }
    },
    'ShiSHcat': {
      'subtitle':
          'Created and ideated Uploadgram originally. Helps in Uploadgram\'s development.',
      'contacts': {
        'Telegram': 'https://t.me/shishcat',
        'Github': 'https://github.com/shishcat',
        'Website': 'https://shish.cat',
        'Uploadgram v1': 'https://github.com/shishcat/uploadgram-v1',
      }
    },
  }.entries.toList();

  final List<MapEntry> _backendLibs = {
    'MadelineProto': {
      'subtitle':
          'Amazing MTProto client fully asynchronous using Amphp, Uploadgram\'s core. By @danogentili.',
      'link': 'https://github.com/danog/madelineproto'
    },
    'Amphp': {
      'subtitle':
          'Collection of blazingly fast PHP Libraries for Asynchronous PHP.',
      'link': 'https://amphp.org'
    },
    'Composer': {
      'subtitle': 'A PHP Dependency manager.',
      'link': 'https://getcomposer.org'
    }
  }.entries.toList();

  final List<MapEntry> _alsoCheckOut = {
    'Snapdrop': {
      'subtitle':
          'A website to share files between devices on your local network',
      'link': 'https://snapdrop.net'
    },
    'Telegram': {
      'subtitle': 'Great messaging app, Uploadgram\'s storage for files.',
      'link': 'https://telegram.org'
    }
  }.entries.toList();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double widgetSize =
        screenWidth >= 550 ? 128 : (128 * screenWidth / 550);
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: SafeArea(
          child: Scrollbar(
              isAlwaysShown: screenWidth > 950,
              child: ListView(
                padding: EdgeInsets.all(15),
                children: [
                  UploadgramTitle(
                      size: widgetSize,
                      mainAxisAlignment: MainAxisAlignment.center),
                  ListTile(
                    leading: Icon(Icons.dns),
                    title: Text('Spacecore'),
                    subtitle: Text('Check out our sponsor!'),
                    onTap: () => launch('https://spacecore.pro'),
                  ),
                  ListTile(
                    leading: Icon(Icons.campaign),
                    title: Text('Telegram Channel'),
                    subtitle:
                        Text('Stay updated in Uploadgram\'s development!'),
                    onTap: () => launch('https://t.me/uploadgramme'),
                  ),
                  ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Telegram Group'),
                    subtitle:
                        Text('Discuss with other people about Uploadgram!'),
                    onTap: () => launch('https://t.me/uploadgrammegroup'),
                  ),
                  ListTile(
                    leading: Icon(Icons.code),
                    title: Text('Repository'),
                    subtitle: Text('Check out the app\'s code!'),
                    onTap: () =>
                        launch('https://github.com/pato05/uploadgram-app'),
                  ),
                  Divider(height: 25),
                  Text('Authors',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ...List.generate(
                    _authors.length,
                    (index) {
                      final List<MapEntry> contacts =
                          _authors[index].value['contacts'].entries.toList();
                      return ExpansionTile(
                          title: Text(_authors[index].key),
                          subtitle: Text(_authors[index].value['subtitle']),
                          children: List.generate(
                              contacts.length,
                              (index) => ListTile(
                                    title: Text(contacts[index].key),
                                    onTap: () => launch(contacts[index].value),
                                  )));
                    },
                  ),
                  Divider(height: 25),
                  Text('Libraries used in the backend',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ...List.generate(
                      _backendLibs.length,
                      (index) => ListTile(
                            title: Text(_backendLibs[index].key),
                            subtitle:
                                Text(_backendLibs[index].value['subtitle']),
                            isThreeLine:
                                _backendLibs[index].value['subtitle'].length *
                                        6.5 >
                                    screenWidth,
                            onTap: () =>
                                launch(_backendLibs[index].value['link']),
                          )),
                  Divider(height: 25),
                  Text('Also check out',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ...List.generate(
                      _alsoCheckOut.length,
                      (index) => ListTile(
                            title: Text(_alsoCheckOut[index].key),
                            subtitle:
                                Text(_alsoCheckOut[index].value['subtitle']),
                            isThreeLine: ((_alsoCheckOut[index]
                                            .value['subtitle']
                                            .length *
                                        6.5) as double)
                                    .toInt() >
                                screenWidth,
                            onTap: () =>
                                launch(_alsoCheckOut[index].value['link']),
                          )),
                  Divider(height: 25),
                  ListTile(
                      leading: Icon(Icons.copyright),
                      title: Text('Licenses and libraries used within the app'),
                      subtitle: Text(
                          'Click here to see the libraries used within this app and their licenses.'),
                      onTap: () => showLicensePage(
                          context: context,
                          applicationIcon: UploadgramLogo(),
                          applicationLegalese:
                              '${DateTime.now().year} \u00a9 Pato05')),
                ],
              ))),
    );
  }
}
