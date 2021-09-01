[![license](https://img.shields.io/github/license/pato05/uploadgram-app)](https://github.com/Pato05/uploadgram-app/blob/master/LICENSE)
[![repo lines](https://img.shields.io/tokei/lines/github/pato05/uploadgram-app)](https://github.com/Pato05/uploadgram-app)
[![framework: flutter](https://img.shields.io/badge/framework-flutter-blue)](https://flutter.io)
[![Codemagic build status](https://api.codemagic.io/apps/604564acbe2f9fb72766d730/604564acbe2f9fb72766d72f/status_badge.svg)](https://codemagic.io/apps/604564acbe2f9fb72766d730/604564acbe2f9fb72766d72f/latest_build)

[![fdroid release](https://img.shields.io/f-droid/v/com.pato05.uploadgram)](https://f-droid.org/packages/com.pato05.uploadgram)
[![github release](https://img.shields.io/github/v/release/pato05/uploadgram-app)](https://github.com/pato05/uploadgram-app/releases/latest)

[![downloads](https://img.shields.io/github/downloads/pato05/uploadgram-app/total)](https://github.com/pato05/uploadgram-app/releases)
[![downloads@latest](https://img.shields.io/github/downloads/pato05/uploadgram-app/latest/total)](https://github.com/pato05/uploadgram-app/releases/latest)

# Uploadgram App
Uploadgram frontend for Android (and web)

## Where can I download the app?
Just go to the [latest release](https://github.com/Pato05/uploadgram-app/releases/latest) and click one of the packages or you can download it on F-Droid, by clicking the button below.

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="80">](https://f-droid.org/packages/com.pato05.uploadgram)

## Files descriptions
- `app-release.apk` is compatible with both ARM and ARM64 (if you are unsure if your device is ARM or ARM64)
- `app-arm64-v8a-release.apk` is the ARM64 release (compatible with most new devices)
- `app-armeabi-v7a-release.apk` is the ARM release

## Before building
You should run the build_runner to generate all the needed files, in short, run the commands below
```bash
flutter pub get
flutter pub run build_runner build
```

## How can I build the app for Web?
You just need to run `flutter build web`

## How can I build the app for Android?
To build the app for Android, simply clone this repository and run `flutter build apk --split-per-abi`
In the releases there are only APK files which support ARM and ARM64

## How can I build the app for iOS?
In this case, it is harder. Indeed, you need to know either Swift or Objective-C, because there are some native implementations that the app uses (file saving, file opening, saving preferences and getting preferences). But either way, I won't support iOS because it is much harder to install IPA files than APK and I can't cover the cost to publish the app to the App Store.

## Will this app support desktop?
When the flutter support for desktop will be stable enough, sure, for now you can use the webapp, which is the almost same of the native app.

## Credits
- [Material.io icons](https://material.io/resources/icons) for the `cloud` icon used in the logo
- [FontAwesome](https://fontawesome.com/) for the `telegram-plane` icon used in the logo
