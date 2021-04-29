import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/fading_page_route.dart';

import 'package:uploadgram/selected_files_notifier.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/routes/file_info.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';
import 'package:uploadgram/api_definitions.dart';

class FileWidgetGrid extends StatelessWidget {
  final bool uploading;
  final IconData icon;
  final Function(String, {Function? onYes})? handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})?
      handleRename;
  final String? error;
  final double? progress;
  final bool compact;
  final Widget? upperWidget;
  final SelectedFilesNotifier selectedFilesNotifier;
  final UploadgramFile? uploadgramFile;
  final UniqueKey tag = UniqueKey();
  final UploadedFile file;

  FileWidgetGrid({
    Key? key,
    required this.file,
    required this.icon,
    required this.selectedFilesNotifier,
    this.uploading = false,
    this.progress = 0,
    this.error,
    this.handleDelete,
    this.handleRename,
    this.compact = false,
    this.upperWidget,
    this.uploadgramFile,
  })  : assert((handleDelete != null && handleRename != null) || uploading),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    ValueNotifier<String> _filenameNotifier = ValueNotifier<String>(file.name);

    Function() openFileInfo = () => Navigator.push(
        context,
        FadingPageRoute(FileInfoRoute(
          file: file,
          filename: _filenameNotifier,
          fileIcon: icon,
          handleDelete: handleDelete!,
          handleRename: handleRename!,
          tag: tag,
        )));
    Function() selectFile =
        () => UploadgramRoute.of(context)!.selectWidget(file.delete!);
    if (uploading || file.delete == null) {
      openFileInfo = selectFile = () => null;
    }
    return ValueListenableBuilder(
        valueListenable: selectedFilesNotifier,
        builder: (BuildContext context, List<String> value, Widget? child) =>
            AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: value.contains(file.delete)
                          ? Colors.blue.shade700
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade900
                              : Colors.grey.shade300),
                      width: 2.0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: child),
        child: Stack(children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!compact)
                Expanded(
                    child: uploading && file.delete == null
                        ? Icon(icon, size: 37, color: Colors.grey[700])
                        : UploadedFileThumbnail(
                            uploadedFile: file,
                            fullImageSize: false,
                            defaultIcon: icon,
                            defaultIconSize: 37,
                            defaultIconColor: Colors.grey[700],
                            file: uploadgramFile?.realFile,
                            heroTag: tag,
                          )),
              Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.symmetric(horizontal: 10),
                            child: GestureDetector(
                              child: ValueListenableBuilder(
                                builder: (BuildContext context,
                                        List<String> value, _) =>
                                    AnimatedCrossFade(
                                        firstChild: Icon(icon,
                                            size: 24,
                                            color: Colors.grey.shade700),
                                        secondChild: Icon(Icons.check_circle,
                                            size: 24,
                                            color: Colors.blue.shade600),
                                        firstCurve: Curves.easeInOut,
                                        secondCurve: Curves.easeInOut,
                                        crossFadeState:
                                            value.contains(file.delete)
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                        duration: Duration(milliseconds: 200)),
                                valueListenable: selectedFilesNotifier,
                              ),
                              onTap: selectFile,
                              onLongPress: selectFile,
                            )),
                      ],
                    ),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: ValueListenableBuilder(
                                        builder: (BuildContext context,
                                                String filename, _) =>
                                            Text(
                                          filename,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        valueListenable: _filenameNotifier,
                                      )),
                                      Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 5)),
                                    ]),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Text(
                                        Utils.humanSize(file.size),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      )),
                                    ]),
                              ],
                            ))),
                  ],
                ),
              )
            ],
          ),
          Positioned.fill(
              child: Material(
                  color: Colors.transparent,
                  child: FileRightClickListener(
                    delete: file.delete,
                    filenameNotifier: _filenameNotifier,
                    url: file.url,
                    handleDelete: handleDelete,
                    handleRename: handleRename,
                    size: file.size,
                    child: ValueListenableBuilder(
                        valueListenable: selectedFilesNotifier,
                        builder: (BuildContext context, List<String> value,
                                _) =>
                            InkWell(
                              onTap:
                                  value.length > 0 ? selectFile : openFileInfo,
                              onLongPress: file.delete != null
                                  ? () => UploadgramRoute.of(context)!
                                      .selectWidget(file.delete!)
                                  : null,
                            )),
                  ))),
          if (uploading == true)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0x88000000)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (upperWidget != null) upperWidget!,
                    LinearProgressIndicator(
                      value: progress,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColorLight),
                    )
                  ],
                ),
              ),
            ),
          if (error != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0x66000000)),
                child: Center(
                    child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 16,
                  ),
                )),
              ),
            ),
        ]));
  }
}
