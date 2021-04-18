import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/selected_files_notifier.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/routes/file_info.dart';

// ignore: must_be_immutable
class FileWidgetGrid extends StatefulWidget {
  String filename;
  double fileSize;
  String url = '';
  String delete = '';
  bool uploading;
  IconData icon;
  Function(String, {Function? onYes})? handleDelete;
  Function(String, {Function(String)? onDone, String? oldName})? handleRename;
  String? error;
  double? progress = 0;
  bool compact;
  Widget? upperWidget;
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

  static _FileWidgetGridState? of(BuildContext c) =>
      c.findAncestorStateOfType<_FileWidgetGridState>();

  @override
  _FileWidgetGridState createState() => _FileWidgetGridState();
}

class _FileWidgetGridState extends State<FileWidgetGrid> {
  late ValueNotifier<String> _filenameNotifier;

  @override
  void initState() {
    _filenameNotifier = ValueNotifier<String>(widget.filename);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Function() openFileInfo = () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => FileInfoRoute(
                  filename: _filenameNotifier,
                  fileSize: widget.fileSize,
                  fileIcon: widget.icon,
                  delete: widget.delete,
                  handleDelete: widget.handleDelete!,
                  handleRename: widget.handleRename!,
                  url: widget.url,
                )));
    Function() selectFile =
        () => UploadgramRoute.of(context)!.selectWidget(widget.delete);
    if (!widget.uploading) {
    } else {
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
                        builder: (BuildContext context, List<String> value,
                                _) =>
                            AnimatedCrossFade(
                                firstChild: Icon(widget.icon,
                                    size: 24, color: Colors.grey.shade700),
                                secondChild: Icon(Icons.check_circle,
                                    size: 24, color: Colors.blue.shade600),
                                firstCurve: Curves.easeInOut,
                                secondCurve: Curves.easeInOut,
                                crossFadeState: value.contains(widget.delete)
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: Duration(milliseconds: 200)),
                        valueListenable: widget.selectedFilesNotifier,
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
                                Utils.humanSize(widget.fileSize),
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
    if (!widget.compact)
      columnChildren.insert(
          0,
          Expanded(
            child: Icon(widget.icon, size: 37, color: Colors.grey.shade700),
          ));
    Widget container = ValueListenableBuilder(
      valueListenable: widget.selectedFilesNotifier,
      builder: (BuildContext context, List<String> value, Widget? child) =>
          AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                border: Border.all(
                    color: value.contains(widget.delete)
                        ? Colors.blue.shade700
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade900
                            : Colors.grey.shade300),
                    width: 2.0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Listener(
                  onPointerDown: (PointerDownEvent event) {
                    if (event.buttons != kSecondaryMouseButton) return;
                    final overlay = Overlay?.of(context)
                        ?.context
                        .findRenderObject() as RenderBox;
                    showMenu(
                        context: context,
                        position: RelativeRect.fromSize(
                            event.position & Size.zero, overlay.size),
                        items: [
                          PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete),
                                SizedBox(width: 15),
                                Text('Delete'),
                              ])),
                          PopupMenuItem(
                              value: 'rename',
                              child: Row(children: [
                                Icon(Icons.edit),
                                SizedBox(width: 15),
                                Text('Rename'),
                              ])),
                          PopupMenuItem(
                              value: 'copy',
                              child: Row(children: [
                                Icon(Icons.copy),
                                SizedBox(width: 15),
                                Text('Copy link'),
                              ])),
                          PopupMenuItem(
                              value: 'export',
                              child: Row(children: [
                                Icon(Icons.get_app),
                                SizedBox(width: 15),
                                Text('Export'),
                              ])),
                        ]).then((value) {
                      switch (value) {
                        case 'delete':
                          widget.handleDelete?.call(widget.delete);
                          break;
                        case 'rename':
                          widget.handleRename?.call(widget.delete,
                              oldName: widget.filename,
                              onDone: (String newName) =>
                                  _filenameNotifier.value = newName);
                          break;
                        case 'copy':
                          AppLogic.copy(widget.url).then((didCopy) =>
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(didCopy
                                      ? 'Link copied to clipboard successfully!'
                                      : 'Unable to copy file link. Please copy it manually.'))));
                          break;
                        case 'export':
                          AppLogic.platformApi.saveFile(
                              _filenameNotifier.value + '.json',
                              json.encode({
                                widget.delete: {
                                  'filename': _filenameNotifier.value,
                                  'size': widget.fileSize,
                                  'url': widget.url
                                }
                              }));
                          break;
                      }
                    });
                  },
                  child: InkWell(
                    onTap: value.length > 0 ? selectFile : openFileInfo,
                    onLongPress: () => UploadgramRoute.of(context)!
                        .selectWidget(widget.delete),
                    child: child,
                  ))),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: columnChildren,
      ),
    );
    if (widget.uploading == true) {
      List<Widget> columnChildren = [
        LinearProgressIndicator(
          value: widget.progress,
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColorLight),
        )
      ];
      if (widget.upperWidget != null)
        columnChildren.insert(0, widget.upperWidget!);
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
    if (widget.error != null)
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
            widget.error!,
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
