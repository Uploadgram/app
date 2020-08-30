import 'package:flutter/material.dart';
import 'package:uploadgram/main.dart';
import 'utils.dart';
import 'fileInfo.dart';

// ignore: must_be_immutable
class FileWidget extends StatefulWidget {
  Map fileObject;
  String delete;
  bool selected;
  bool uploading;
  bool selectOnPress;
  IconData icon;
  Function onPressed;
  Function onLongPress;
  Function(String, {Function onYes}) handleDelete;
  Function(String) handleRename;
  String error;
  double progress = 0;

  FileWidget({
    Key key,
    this.selected = false,
    this.uploading = false,
    this.selectOnPress = false,
    @required this.delete,
    @required this.fileObject,
    @required this.icon,
    this.progress,
    this.error,
    this.onLongPress,
    this.handleDelete,
    this.handleRename,
    this.onPressed,
  }) : super(key: key);
  @override
  FileWidgetState createState() => FileWidgetState();
}

class FileWidgetState extends State<FileWidget> {
  void setUploadProgress(double value) =>
      setState(() => widget.progress = value);
  //void finishUpload(String url, String delete) => setState(() {
  //      widget.uploading = false;
  //      widget.fileObject['url'] = url;
  //      widget.delete = delete;
  //    });
  //void uploadError(String error) => setState(() {
  //      widget.uploading = false;
  //      _error = error;
  //      widget.onPressed = widget.onLongPress = () => null;
  //    });

  @override
  Widget build(BuildContext context) {
    print(widget.fileObject);
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
                              filename: widget.fileObject['filename'],
                              fileSize: widget.fileObject['size'].toDouble(),
                              fileIcon: widget.icon,
                              delete: widget.delete,
                              handleDelete: widget.handleDelete,
                              handleRename: widget.handleRename,
                              url: widget.fileObject['url'],
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
            width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: InkWell(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Icon(widget.icon, size: 37, color: Colors.grey.shade700),
              ),
              Container(
                margin: EdgeInsets.only(left: 5, right: 5, bottom: 10),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(left: 5, right: 10),
                            //child: Icon(
                            //    widget.selected == true
                            //        ? Icons.check_circle
                            //        : widget.icon,
                            //    size: 24,
                            //    color: widget.selected == true
                            //        ? Colors.blue.shade600
                            //        : Colors.grey.shade700
                            child: InkWell(
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
                              hoverColor: Colors.transparent,
                              splashColor: Colors.transparent,
                            )),
                      ],
                    ),
                    Flexible(
                        child: Column(
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(
                                widget.fileObject['filename'],
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )),
                              Padding(padding: EdgeInsets.only(bottom: 5)),
                            ]),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(
                                humanSize(widget.fileObject['size'].toDouble()),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )),
                            ]),
                      ],
                    )),
                  ],
                ),
              )
            ],
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
