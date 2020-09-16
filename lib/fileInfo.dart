import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'utils.dart';
import 'appSettings.dart';
import 'fileWidget.dart';

// ignore: must_be_immutable
class FileInfoRoute extends StatefulWidget {
  String filename;
  double fileSize;
  String url;
  IconData fileIcon;
  Function(String, {Function onYes}) handleDelete;
  Function(String, {Function(String) onDone, String oldName}) handleRename;
  String delete;

  FileInfoRoute({
    @required this.filename,
    @required this.fileSize,
    @required this.fileIcon,
    @required this.delete,
    @required this.handleDelete,
    @required this.handleRename,
    @required this.url,
  });
  _FileInfoRouteState createState() => _FileInfoRouteState();
}

class _FileInfoRouteState extends State<FileInfoRoute> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    double fontSize = 20;
    List<List<Widget>> tableChildren = [
      [
        Text('Size', style: TextStyle(fontSize: fontSize)),
        Text(humanSize(widget.fileSize), style: TextStyle(fontSize: fontSize))
      ],
      [
        Text('URL', style: TextStyle(fontSize: fontSize)),
        SelectableText(widget.url, style: TextStyle(fontSize: fontSize))
      ]
    ];
    Uri uri = Uri.tryParse(widget.url);
    if (uri != null) {
      int uploadDateInt =
          int.tryParse(uri.path.split('/').last.substring(0, 8), radix: 16);
      if (uploadDateInt != null) {
        DateTime uploadDate =
            new DateTime.fromMillisecondsSinceEpoch(uploadDateInt * 1000)
                .toLocal();
        String uploadDateFormatted =
            DateFormat("E', 'dd MMMM yyyy' at 'HH:mm:ss").format(uploadDate);
        tableChildren.add([
          Text('Uploaded on', style: TextStyle(fontSize: fontSize)),
          Text(
            uploadDateFormatted,
            style: TextStyle(fontSize: fontSize),
          )
        ]);
      }
    }
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Theme.of(context).accentColor,
          title: Text('File info'),
          actions: [
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () async {
                _scaffoldKey.currentState.showSnackBar(SnackBar(
                    content: Text(await AppSettings.api.copy(
                  widget.url,
                )
                        ? 'Link copied to clipboard successfully!'
                        : 'Unable to copy file link. Please copy it manually.')));
              },
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
              child: Column(mainAxisSize: MainAxisSize.max, children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 170),
                  child: Center(
                      child: Icon(widget.fileIcon,
                          size: 56, color: Colors.grey.shade700)),
                ),
                Row(children: [
                  Expanded(
                      child: Padding(
                          child: Text(
                            widget.filename,
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.start,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 23)))
                ]),
                Table(
                  columnWidths: {
                    0: const FlexColumnWidth(0.3),
                    2: const FlexColumnWidth(0.7),
                  },
                  children: tableChildren
                      .map((e) => TableRow(
                          children: e
                              .map((wid) => TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Container(
                                      child: wid,
                                      margin: EdgeInsets.only(bottom: 30))))
                              .toList()))
                      .toList(),
                ),
              ]))
        ]));
  }
}
