import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/selected_files_notifier.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/routes/file_info.dart';

class FileWidgetGrid extends StatelessWidget {
  final String filename;
  final int fileSize;
  final String url;
  final String delete;
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

  FileWidgetGrid({
    Key? key,
    required this.delete,
    required this.filename,
    required this.fileSize,
    required this.url,
    required this.icon,
    required this.selectedFilesNotifier,
    this.uploading = false,
    this.progress = 0,
    this.error,
    this.handleDelete,
    this.handleRename,
    this.compact = false,
    this.upperWidget,
  })  : assert((handleDelete != null && handleRename != null) || uploading),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    ValueNotifier<String> _filenameNotifier = ValueNotifier<String>(filename);
    Function() openFileInfo = () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => FileInfoRoute(
                  filename: _filenameNotifier,
                  fileSize: fileSize,
                  fileIcon: icon,
                  delete: delete,
                  handleDelete: handleDelete!,
                  handleRename: handleRename!,
                  url: url,
                )));
    Function() selectFile =
        () => UploadgramRoute.of(context)!.selectWidget(delete);
    if (uploading) {
      openFileInfo = selectFile = () => null;
    }
    List<Widget> columnChildren = [
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
                        builder:
                            (BuildContext context, List<String> value, _) =>
                                AnimatedCrossFade(
                                    firstChild: Icon(icon,
                                        size: 24, color: Colors.grey.shade700),
                                    secondChild: Icon(Icons.check_circle,
                                        size: 24, color: Colors.blue.shade600),
                                    firstCurve: Curves.easeInOut,
                                    secondCurve: Curves.easeInOut,
                                    crossFadeState: value.contains(delete)
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
                                builder: (BuildContext context, String filename,
                                        _) =>
                                    Text(
                                  filename,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                valueListenable: _filenameNotifier,
                              )),
                              Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5)),
                            ]),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(
                                Utils.humanSize(fileSize),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )),
                            ]),
                      ],
                    ))),
          ],
        ),
      )
    ];
    if (!compact)
      columnChildren.insert(
          0,
          Expanded(
            child: Icon(icon, size: 37, color: Colors.grey.shade700),
          ));
    Widget container = ValueListenableBuilder(
      valueListenable: selectedFilesNotifier,
      builder: (BuildContext context, List<String> value, Widget? child) =>
          AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                border: Border.all(
                    color: value.contains(delete)
                        ? Colors.blue.shade700
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade900
                            : Colors.grey.shade300),
                    width: 2.0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FileRightClickListener(
                  delete: delete,
                  filenameNotifier: _filenameNotifier,
                  url: url,
                  handleDelete: handleDelete,
                  handleRename: handleRename,
                  size: fileSize,
                  child: InkWell(
                    onTap: value.length > 0 ? selectFile : openFileInfo,
                    onLongPress: () =>
                        UploadgramRoute.of(context)!.selectWidget(delete),
                    child: child,
                  ))),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: columnChildren,
      ),
    );
    if (uploading == true) {
      List<Widget> columnChildren = [
        LinearProgressIndicator(
          value: progress,
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColorLight),
        )
      ];
      if (upperWidget != null) columnChildren.insert(0, upperWidget!);
      return Stack(children: [
        container,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x88000000)),
          ),
        ),
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: columnChildren,
          ),
        ),
      ]);
    }
    if (error != null)
      return Stack(children: [
        container,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x66000000)),
          ),
        ),
        Positioned.fill(
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
      ]);
    return container;
  }
}
