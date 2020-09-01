import 'package:flutter/material.dart';
import 'package:uploadgram/fileWidget.dart';
import 'package:intl/intl.dart';
import 'utils.dart';

// ignore: must_be_immutable
class FileInfoRoute extends StatefulWidget {
  String filename;
  double fileSize;
  String url;
  IconData fileIcon;
  Function(String, {Function onYes}) handleDelete;
  Function(String, {Function(String) onDone, String oldName}) handleRename;
  Function(String, {Function onSuccess, Function onError}) handleCopy;
  String delete;

  FileInfoRoute({
    @required this.filename,
    @required this.fileSize,
    @required this.fileIcon,
    @required this.delete,
    @required this.handleDelete,
    @required this.handleRename,
    @required this.handleCopy,
    @required this.url,
  });
  _FileInfoRouteState createState() => _FileInfoRouteState();
}

class _FileInfoRouteState extends State<FileInfoRoute> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static const int urlLength = 24;
  static const int idIndex = urlLength + 8;
  @override
  Widget build(BuildContext context) {
    double fontSize = 20;
    DateTime uploadDate = new DateTime.fromMillisecondsSinceEpoch(
            int.parse(widget.url.substring(urlLength, idIndex), radix: 16) *
                1000)
        .toLocal();
    String uploadDateFormatted =
        DateFormat("E', 'dd MMMM yyyy' at 'HH:mm:ss").format(uploadDate);
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Theme.of(context).accentColor,
          title: Text('File info'),
          actions: [
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () => widget.handleCopy(
                widget.url,
                onSuccess: () => _scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                        content:
                            Text('Link copied to clipboard successfully!'))),
                onError: () => _scaffoldKey.currentState.showSnackBar(SnackBar(
                    content: Text(
                        'Unable to copy file link. Please copy it manually.'))),
              ),
              tooltip: 'Copy this file\'s link',
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => widget.handleDelete(widget.delete,
                  onYes: () => Navigator.pop(context)),
              tooltip: 'Delete this file',
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                widget.handleRename(widget.delete, oldName: widget.filename,
                    onDone: (String newName) {
                  FileWidget.of(context)
                      ?.setProperty(waiting: false, filename: newName);
                  setState(() => widget.filename = newName);
                });
              },
              tooltip: 'Rename this file',
            )
          ],
        ),
        body: ListView(children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 50),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 170),
                  child: Center(
                      child: Icon(widget.fileIcon,
                          size: 56, color: Colors.grey.shade700)),
                ),
                Padding(
                    child: Text(
                      widget.filename,
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.visible,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 23)),
                //Expanded(
                //    child: GridView.count(
                //  crossAxisCount: 2,
                //  childAspectRatio: 1 / 0.25,
                //  children: [
                //    Container(
                //        child:
                //            Text('Size', style: TextStyle(fontSize: fontSize))),
                //    Container(
                //        child: Text(humanSize(widget.fileSize),
                //            style: TextStyle(fontSize: fontSize))),
                //    Container(
                //        child: Text('URL', style: TextStyle(fontSize: fontSize))),
                //    Container(
                //        child: SelectableText(widget.url,
                //            style: TextStyle(fontSize: fontSize))),
                //  ],
                //))
                Table(
                  columnWidths: {
                    0: const FlexColumnWidth(0.3),
                    1: const FixedColumnWidth(0.0),
                    2: const FlexColumnWidth(0.7),
                  },
                  children: [
                    TableRow(children: [
                      TableCell(
                          child: Text(
                        'Size',
                        style: TextStyle(fontSize: fontSize),
                      )),
                      Container(width: 0, height: 50),
                      TableCell(
                          child: Text(
                        humanSize(widget.fileSize),
                        style: TextStyle(fontSize: fontSize),
                      )),
                    ]),
                    TableRow(children: [
                      TableCell(
                          child: SelectableText(
                        'URL',
                        style: TextStyle(fontSize: fontSize),
                      )),
                      Container(width: 0, height: 75),
                      TableCell(
                          child: SelectableText(
                        widget.url,
                        style: TextStyle(fontSize: fontSize),
                      )),
                    ]),
                    TableRow(children: [
                      TableCell(
                          child: Text(
                        'Uploaded on',
                        style: TextStyle(fontSize: fontSize),
                      )),
                      Container(width: 0, height: 0),
                      TableCell(
                          child: Text(
                        uploadDateFormatted,
                        style: TextStyle(fontSize: fontSize),
                      ))
                    ])
                  ],
                ),
              ],
            ),
          )
        ]));
  }
}
