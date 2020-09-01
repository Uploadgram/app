import 'package:flutter/material.dart';
import 'package:uploadgram/main.dart';
import 'utils.dart';
import 'fileInfo.dart';

// ignore: must_be_immutable
class FileWidget extends StatefulWidget {
  String filename;
  double fileSize;
  String url;
  String delete;
  bool selected;
  bool uploading;
  bool selectOnPress;
  IconData icon;
  Function onPressed;
  Function onLongPress;
  Function(String, {Function onYes}) handleDelete;
  Function(String, {Function(String) onDone, String oldName}) handleRename;
  String error;
  double progress = 0;
  bool compact;

  FileWidget({
    Key key,
    this.selected = false,
    this.uploading = false,
    this.selectOnPress = false,
    @required this.delete,
    @required this.filename,
    @required this.fileSize,
    @required this.url,
    @required this.icon,
    this.progress = 0,
    this.error,
    this.onLongPress,
    this.handleDelete,
    this.handleRename,
    this.onPressed,
    this.compact = false,
  }) : super(key: key);

  static _FileWidgetState of(BuildContext c) =>
      c.findAncestorStateOfType<_FileWidgetState>();

  @override
  _FileWidgetState createState() => _FileWidgetState();
}

class _FileWidgetState extends State<FileWidget> {
  void setProperty({bool waiting, String filename}) => setState(() {
        if (waiting != null) {
          widget.uploading = waiting;
          if (waiting) widget.progress = null;
        }
        if (filename != null) {
          widget.filename = filename;
        }
      });

  @override
  Widget build(BuildContext context) {
    assert((widget.uploading == false && widget.onPressed != null ||
            (widget.handleDelete != null && widget.handleRename != null)) ||
        widget.uploading);
    if (!widget.uploading) {
      if (widget.onPressed == null) {
        widget.onPressed = widget.selectOnPress
            ? () => UploadgramRoute.of(context).selectWidget(widget.delete)
            : () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FileInfoRoute(
                              filename: widget.filename,
                              fileSize: widget.fileSize,
                              fileIcon: widget.icon,
                              delete: widget.delete,
                              handleDelete: widget.handleDelete,
                              handleRename: widget.handleRename,
                              url: widget.url,
                            )));
              };
      }
      if (widget.onLongPress == null) {
        widget.onLongPress =
            () => UploadgramRoute.of(context).selectWidget(widget.delete);
      }
    } else {
      widget.onPressed = widget.onLongPress = () => null;
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
                      child: AnimatedCrossFade(
                          firstChild: Icon(widget.icon,
                              size: 24, color: Colors.grey.shade700),
                          secondChild: Icon(Icons.check_circle,
                              size: 24, color: Colors.blue.shade600),
                          firstCurve: Curves.easeInOut,
                          secondCurve: Curves.easeInOut,
                          crossFadeState: widget.selected == true
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: Duration(milliseconds: 150)),
                      onTap: widget.onLongPress,
                      onLongPress: widget.onLongPress,
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
                                  child: Text(
                                widget.filename,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )),
                              Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5)),
                            ]),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(
                                humanSize(widget.fileSize),
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
    Widget container = AnimatedContainer(
      duration: Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        border: Border.all(
            color: widget.selected == true
                ? Colors.blue.shade700
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.grey.shade300),
            width: 2.0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: InkWell(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: columnChildren,
          )),
    );
    if (widget.uploading == true) {
      List<Widget> columnChildren = [
        LinearProgressIndicator(
          value: widget.progress,
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColorLight),
        )
      ];
      if (widget.progress != null)
        columnChildren.insert(
            0,
            Text(
              (widget.progress != null
                      ? (widget.progress * 100).ceil().toString()
                      : '0') +
                  '%',
              style: TextStyle(color: Colors.white),
            ));
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
            widget.error,
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
