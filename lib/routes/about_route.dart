import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/widgets/uploadgram_logo.dart';

class AboutRoute extends StatefulWidget {
  const AboutRoute({Key? key}) : super(key: key);

  @override
  _AboutRouteState createState() => _AboutRouteState();
}

class _AboutRouteState extends State<AboutRoute> {
  static const _uploadgramEnglishGroup = 'https://t.me/uploadgrammegroup';
  static const _uploadgramRussianGroup =
      'https://t.me/joinchat/KYwmw4LndLo1NWY0';
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final List<MapEntry> _authors = {
      'Pato05': {
        'subtitle': localizations.aboutPato05Subtitle,
        'contacts': {
          'Telegram': 'https://t.me/Pato05',
          'Github': 'https://github.com/Pato05',
          localizations.aboutWebsiteText: 'https://pato05mc.tk',
        }
      },
      'ShiSHcat': {
        'subtitle': localizations.aboutShishcatSubtitle,
        'contacts': {
          'Telegram': 'https://t.me/shishcat',
          'Github': 'https://github.com/shishcat',
          localizations.aboutWebsiteText: 'https://shish.cat',
          'Uploadgram v1': 'https://github.com/shishcat/uploadgram-v1',
        }
      },
    }.entries.toList();

    final List<MapEntry> _backendLibs = {
      'MadelineProto': {
        'subtitle': localizations.aboutMadelineprotoSubtitle,
        'link': 'https://github.com/danog/madelineproto'
      },
      'Amphp': {
        'subtitle': localizations.aboutAmphpSubtitle,
        'link': 'https://amphp.org'
      },
      'Composer': {
        'subtitle': localizations.aboutComposerSubtitle,
        'link': 'https://getcomposer.org'
      }
    }.entries.toList();

    final List<MapEntry> _alsoCheckOut = {
      'Snapdrop': {
        'subtitle': localizations.aboutSnapdropSubtitle,
        'link': 'https://snapdrop.net'
      },
      'Telegram': {
        'subtitle': localizations.aboutTelegramSubtitle,
        'link': 'https://telegram.org'
      }
    }.entries.toList();
    final double screenWidth = MediaQuery.of(context).size.width;
    final double widgetSize =
        screenWidth >= 550 ? 128 : (128 * screenWidth / 550);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.aboutTitle)),
      body: SafeArea(
          child: Scrollbar(
              isAlwaysShown: screenWidth > 950,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  UploadgramTitle(
                      size: widgetSize,
                      mainAxisAlignment: MainAxisAlignment.center),
                  ListTile(
                    leading: const Icon(Icons.dns),
                    title: const Text('Spacecore'),
                    subtitle: Text(localizations.aboutSponsorTileSubtitle),
                    onTap: () => launch('https://spacecore.pro'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.campaign),
                    title: Text(localizations.aboutTelegramChannelTileTitle),
                    subtitle:
                        Text(localizations.aboutTelegramChannelTileSubtitle),
                    onTap: () => launch('https://t.me/uploadgramme'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(localizations.aboutTelegramGroupTileTitle),
                    subtitle:
                        Text(localizations.aboutTelegramGroupTileSubtitle),
                    onTap: () {
                      final locale = Localizations.localeOf(context);
                      if (locale.languageCode == 'ru') {
                        launch(_uploadgramRussianGroup);
                      } else {
                        launch(_uploadgramEnglishGroup);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: Text(localizations.aboutAppRepositoryTileTitle),
                    subtitle: Text(localizations.aboutAppRepositoryTileSubitle),
                    onTap: () =>
                        launch('https://github.com/pato05/uploadgram-app'),
                  ),
                  const Divider(height: 25),
                  Text(localizations.aboutAuthorsTitle,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
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
                  const Divider(height: 25),
                  Text(localizations.aboutLibrariesUsedInBackendTitle,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  ...List.generate(
                      _backendLibs.length,
                      (index) => ListTile(
                            title: Text(_backendLibs[index].key),
                            subtitle:
                                Text(_backendLibs[index].value['subtitle']),
                            onTap: () =>
                                launch(_backendLibs[index].value['link']),
                          )),
                  const Divider(height: 25),
                  Text(localizations.aboutAlsoCheckOutTitle,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  ...List.generate(
                      _alsoCheckOut.length,
                      (index) => ListTile(
                            title: Text(_alsoCheckOut[index].key),
                            subtitle:
                                Text(_alsoCheckOut[index].value['subtitle']),
                            onTap: () =>
                                launch(_alsoCheckOut[index].value['link']),
                          )),
                  const Divider(height: 25),
                  ListTile(
                      leading: const Icon(Icons.copyright),
                      title: Text(localizations.aboutLicensesTileTitle),
                      subtitle: Text(localizations.aboutLicensesTileSubtitle),
                      onTap: () => showLicensePage(
                          context: context,
                          applicationIcon: const UploadgramLogo(),
                          applicationLegalese:
                              '2020-${DateTime.now().year} \u00a9 Pato05')),
                ],
              ))),
    );
  }
}
