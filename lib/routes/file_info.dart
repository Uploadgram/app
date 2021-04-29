import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

import 'package:uploadgram/utils.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';

// ignore: must_be_immutable
class FileInfoRoute extends StatefulWidget {
  final UploadedFile file;
  final IconData fileIcon;
  final Function(String, {Function? onYes}) handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})
      handleRename;
  final ValueNotifier<String> filename;
  final Object? tag;

  FileInfoRoute({
    required this.file,
    required this.filename,
    required this.fileIcon,
    required this.handleDelete,
    required this.handleRename,
    this.tag,
  });
  _FileInfoRouteState createState() => _FileInfoRouteState();
}

class _FileInfoRouteState extends State<FileInfoRoute> {
  bool isFullThumbnailAvailable = false;
  @override
  Widget build(BuildContext context) {
    Widget? uploadedOnTile;
    Uri? uri = Uri.tryParse(widget.file.url);
    if (uri != null) {
      int? uploadDateInt =
          int.tryParse(uri.path.split('/').last.substring(0, 8), radix: 16);
      if (uploadDateInt != null) {
        String uploadDateFormatted =
            DateFormat("E', 'dd MMMM yyyy' at 'HH:mm:ss").format(
                DateTime.fromMillisecondsSinceEpoch(uploadDateInt * 1000)
                    .toLocal());
        uploadedOnTile = ListTile(
          leading: Icon(Icons.calendar_today),
          title: Text('Uploaded on'),
          subtitle: Text(uploadDateFormatted),
        );
      }
    }
    return Scaffold(
        appBar: AppBar(
          title: Text('File info'),
          actions: [
            IconButton(
              icon: Icon(Icons.share),
              tooltip: 'Share this file\'s link',
              onPressed: () =>
                  AppLogic.platformApi.shareUploadgramLink(widget.file.url),
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                widget.handleRename.call(widget.file.delete!,
                    oldName: widget.filename.value, onDone: (String newName) {
                  widget.filename.value = newName;
                });
              },
              tooltip: 'Rename this file',
            )
          ],
        ),
        body: ListView(padding: EdgeInsets.all(15), children: [
          ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250),
              child: Stack(children: [
                Positioned.fill(
                    child: UploadedFileThumbnail(
                        uploadedFile: widget.file,
                        defaultIcon: widget.fileIcon,
                        defaultIconSize: 56,
                        defaultIconColor: Colors.grey.shade700,
                        fullImageSize: true,
                        heroTag: widget.tag)),
                if (canGenerateThumbnail(widget.file.size, widget.file.name))
                  Positioned.fill(
                    child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                  opaque: false,
                                  barrierDismissible: true,
                                  barrierColor: Colors.black.withOpacity(0.75),
                                  fullscreenDialog: true,
                                  transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                  pageBuilder: (BuildContext context, _, __) =>
                                      Center(
                                          child: Dismissible(
                                        key: UniqueKey(),
                                        resizeDuration:
                                            const Duration(milliseconds: 100),
                                        direction: DismissDirection.down,
                                        child: PhotoView.customChild(
                                          backgroundDecoration: BoxDecoration(
                                              color: Colors.transparent),
                                          child: Center(
                                              child: UploadedFileThumbnail(
                                            imageInsteadOfContainer: true,
                                            uploadedFile: widget.file,
                                            defaultIcon: widget.fileIcon,
                                            defaultIconSize: 56,
                                            defaultIconColor:
                                                Colors.grey.shade700,
                                            fullImageSize: true,
                                            heroTag: widget.tag,
                                            forceDownloadImage: true,
                                          )),
                                          minScale: 0.2,
                                        ),
                                        onDismissed: Navigator.of(context).pop,
                                      )))).then((value) {
                            if (!isFullThumbnailAvailable &&
                                ThumbnailsUtils.isFullThumbAvailable(
                                    widget.file.delete!)) setState(() => null);
                          }),
                        )),
                  ),
              ])),
          Row(children: [
            Expanded(
                child: Padding(
                    child: ValueListenableBuilder<String>(
                      valueListenable: widget.filename,
                      builder: (BuildContext context, String name, _) => Text(
                        name,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.start,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15)))
          ]),
          ListTile(
              leading: Icon(Icons.archive),
              title: Text('Size'),
              subtitle: Text(Utils.humanSize(widget.file.size))),
          ListTile(
            leading: Icon(Icons.link),
            title: Text('Link'),
            subtitle: Text(widget.file.url),
            trailing: IconButton(
              icon: Icon(Icons.copy),
              onPressed: () async =>
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(await AppLogic.copy(
                widget.file.url,
              )
                          ? 'Link copied to clipboard successfully!'
                          : 'Unable to copy file link. Please copy it manually.'))),
            ),
            onTap: () =>
                AppLogic.platformApi.shareUploadgramLink(widget.file.url),
          ),
          if (uploadedOnTile != null) uploadedOnTile,
          Divider(),
          ListTileTheme(
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete this file'),
              onTap: () => widget.handleDelete.call(widget.file.delete!,
                  onYes: () => Navigator.pop(context)),
            ),
            textColor: Colors.red,
            iconColor: Colors.red,
          )
        ]));
  }
}
