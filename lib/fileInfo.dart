import 'package:flutter/material.dart';
import 'utils.dart';

// ignore: must_be_immutable
class FileInfoRoute extends StatelessWidget {
  String filename;
  double fileSize;
  String url;
  IconData fileIcon;
  Function(String, {Function onYes}) handleDelete;
  Function handleRename;
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

  @override
  Widget build(BuildContext context) {
    double fontSize = 20;
    // TODO: some padding on the table cells would be beautiful
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).accentColor,
          title: Text('File info'),
          actions: [
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                handleDelete(delete, onYes: () => Navigator.pop(context));
              },
            )
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 50),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 170),
                child: Center(
                    child:
                        Icon(fileIcon, size: 56, color: Colors.grey.shade700)),
              ),
              Padding(
                  child: Text(
                    filename,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.visible,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 23)),
              Table(
                columnWidths: {
                  0: FlexColumnWidth(0.3),
                  1: FlexColumnWidth(0.7),
                },
                children: [
                  TableRow(children: [
                    TableCell(
                        child: Text(
                      'Size',
                      style: TextStyle(fontSize: fontSize),
                    )),
                    TableCell(
                        child: Text(
                      humanSize(fileSize),
                      style: TextStyle(fontSize: fontSize),
                    )),
                  ]),
                  TableRow(children: [
                    TableCell(
                        child: Text(
                      'URL',
                      style: TextStyle(fontSize: fontSize),
                    )),
                    TableCell(
                        child: Text(
                      url,
                      style: TextStyle(fontSize: fontSize),
                    )),
                  ]),
                ],
              )
            ],
          ),
        ));
  }
}
