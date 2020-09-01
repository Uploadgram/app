# Uploadgram-app
Uploadgram frontend for Android (and web)

## Where can I download the app?
Just go to the [latest release](https://github.com/Pato05/uploadgram-app/releases/latest) and click one of the packages.
`app-release.apk` is compatible with both ARM and ARM64 (if you are unsure if your device is ARM or ARM64)
`app-arm64-v8a-release.apk` is the ARM64 release (compatible with most new devices)
`app-armeabi-v7a-release.apk` is the ARM release

## How can I build the app for Android?
To build the app for Android, simply clone this repository and run `flutter build apk --split-per-abi`
In the releases there are only APK files which support ARM and ARM64

## How can I build the app for iOS?
In this case, it is harder. Indeed, you need to know either Swift or Objective-C, because there are some native implementations that the app uses (file saving, file opening, saving preferences and getting preferences). But either way, I won't support iOS because it is much harder to install IPA files than APK and I can't cover the cost to publish the app to the App Store.

## Will this app support desktop?
When the flutter support for desktop will be stable enough, sure, for now you can use the webapp, which is the almost same of the native app.
