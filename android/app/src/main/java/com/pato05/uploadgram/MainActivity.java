package com.pato05.uploadgram;

import android.annotation.TargetApi;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import androidx.core.view.WindowCompat;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.provider.Settings;
import android.util.TypedValue;
import android.view.ContextThemeWrapper;
import android.window.SplashScreenView;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_NAME = "com.pato05.uploadgram";
    private MethodChannel.Result _pendingResult;
    private static final int REQUEST_CODE_SAVE_FROM_FILE = MainActivity.class.hashCode() + 30;
    private static final int REQUEST_CODE_UNKNOWN_SOURCES = MainActivity.class.hashCode() + 60;
    private String _lastUri;
    private String _data;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Aligns the Flutter view vertically with the window.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation to avoid
            // a flicker before the similar frame is drawn in Flutter.
            getSplashScreen().setOnExitAnimationListener((SplashScreenView splashScreenView) -> {
                splashScreenView.remove();
            });
        }

        super.onCreate(savedInstanceState);
    }

    @Override
    public void onNewIntent(Intent intent) {
        handleIntent(intent);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        handleIntent(getIntent());
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NAME)
                .setMethodCallHandler((call, result) -> {
                    String name;
                    switch (call.method) {
                    case "getLastUrl":
                        result.success(_lastUri);
                        break;
                    case "getString":
                        result.success(getApplicationContext().getSharedPreferences("UploadgramPreferences", 0)
                                .getString(call.argument("name"), call.argument("default")));
                        break;
                    case "getBool":
                        result.success(getApplicationContext().getSharedPreferences("UploadgramPreferences", 0)
                                .getBoolean(call.argument("name"), call.argument("default")));
                        break;
                    case "deletePreferences":
                        getApplicationContext().getSharedPreferences("UploadgramPreferences", 0).edit().clear().apply();
                        result.success(null);
                        break;
                    case "saveFileFromFile":
                        _pendingResult = result;
                        _data = call.argument("file");
                        saveFileFromFile(call.argument("filename"), call.argument("type"));
                        break;
                    case "getAccent":
                        result.success(getAccent());
                        break;
                    case "getDeviceAbiList":
                        result.success(getABIList());
                        break;
                    case "installAPK":
                        installAPK(call.argument("path"), result);
                        break;
                    default:
                        result.notImplemented();
                        break;
                    }
                });
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        if (_pendingResult != null) {
            if (resultCode == RESULT_CANCELED) {
                _pendingResult.success(null);
                return;
            }
            if (intent == null) {
                _pendingResult.success(null);
                return;
            }
            if (requestCode == REQUEST_CODE_SAVE_FROM_FILE) {
                Uri uri = intent.getData();
                // We wrote some data to a temporary file in the dart side, now we wanna copy
                // that to the target file.
                try {
                    InputStream is = new FileInputStream(new File(_data));
                    OutputStream os = getApplicationContext().getContentResolver().openOutputStream(uri);
                    byte[] buffer = new byte[1024];
                    while (is.read(buffer) > -1)
                        os.write(buffer);
                    is.close();
                    os.close();
                    _pendingResult.success(true);
                } catch (Exception e) {
                    e.printStackTrace();
                    _pendingResult.success(false);
                }
            } else if (requestCode == REQUEST_CODE_UNKNOWN_SOURCES) {
                if (resultCode == RESULT_OK) {
                    makeInstallAPK(_data, _pendingResult);
                }
                _data = null;
            }
        }

        super.onActivityResult(requestCode, resultCode, intent);
    }

    private void saveFileFromFile(String filename, String type) {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.setType(type);
        intent.putExtra(Intent.EXTRA_TITLE, filename);

        startActivityForResult(intent, REQUEST_CODE_SAVE_FROM_FILE);
    }

    private void handleIntent(Intent intent) {
        String action = intent.getAction();
        String dataString = intent.getDataString();
        if (Intent.ACTION_VIEW.equals(action) && dataString != null) {
            _lastUri = dataString;
        }
    }

    // copied straight from
    // https://stackoverflow.com/questions/58352718/get-android-system-accent-color-android-10-system-color-accent
    private Integer getAccent() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q)
            return null;
        TypedValue typedValue = new TypedValue();
        ContextThemeWrapper contextThemeWrapper = new ContextThemeWrapper(this, android.R.style.Theme_DeviceDefault);
        contextThemeWrapper.getTheme().resolveAttribute(android.R.attr.colorAccent, typedValue, true);
        return typedValue.data; // system's accent
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private List<String> getABIList21() {
        final List<String> abis = Arrays.asList(Build.SUPPORTED_ABIS);
        if (abis == null || abis.size() == 0)
            return getABIListDeprecated();
        return abis;
    }

    @SuppressWarnings("deprecation")
    private List<String> getABIListDeprecated() {
        final List<String> abis = new ArrayList<>();
        abis.add(Build.CPU_ABI);
        abis.add(Build.CPU_ABI2);
        if (abis.get(0) == null && abis.get(1) == null)
            return null;
        return abis;
    }

    private List<String> getABIList() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP)
            return getABIListDeprecated();
        return getABIList21();
    }

    @TargetApi(Build.VERSION_CODES.O)
    private void installAPKOreo(String path, MethodChannel.Result result) {
        if (!getContext().getPackageManager().canRequestPackageInstalls()) {
            _data = path;
            _pendingResult = result;
            Uri packageURI = Uri.parse("package:" + getContext().getPackageName());
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, packageURI);
            startActivityForResult(intent, REQUEST_CODE_UNKNOWN_SOURCES);
        } else
            makeInstallAPK(path, result);
    }

    private void makeInstallAPK(String path, MethodChannel.Result result) {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        Uri uri;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".provider", new File(path));
        } else {
            uri = Uri.fromFile(new File(path));
        }
        intent.setDataAndType(uri, "application/vnd.android.package-archive");
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(intent);
        result.success(true);
    }

    private void installAPK(String path, MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            installAPKOreo(path, result);
        else
            makeInstallAPK(path, result);
    }
}