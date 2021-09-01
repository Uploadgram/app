import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/utils.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';
import 'package:uploadgram/widgets/uploaded_file_thumbnail.dart';

class FileInfoRoute extends StatefulWidget {
  final UploadedFile file;
  final IconData fileIcon;
  final Function(String, {Function? onYes}) handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})
      handleRename;
  final ValueNotifier<String> filename;
  final Object? tag;

  const FileInfoRoute({
    Key? key,
    required this.file,
    required this.filename,
    required this.fileIcon,
    required this.handleDelete,
    required this.handleRename,
    this.tag,
  }) : super(key: key);
  @override
  _FileInfoRouteState createState() => _FileInfoRouteState();
}

class _FileInfoRouteState extends State<FileInfoRoute> {
  bool isFullThumbnailAvailable = false;
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    Widget? uploadedOnTile;
    Uri? uri = Uri.tryParse(widget.file.url);
    if (uri != null) {
      int? uploadDateInt =
          int.tryParse(uri.pathSegments.lastEntry.substring(0, 8), radix: 16);
      if (uploadDateInt != null) {
        String uploadDateFormatted = DateFormat(
                localizations.uploadDateFormatted,
                Localizations.localeOf(context).toString())
            .format(DateTime.fromMillisecondsSinceEpoch(uploadDateInt * 1000)
                .toLocal());
        uploadedOnTile = ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(localizations.uploadedOnText),
          subtitle: Text(uploadDateFormatted),
        );
      }
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(localizations.fileInfoTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: localizations.shareLinkText,
              onPressed: () => Share.share(widget.file.url),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                widget.handleRename.call(widget.file.delete!,
                    oldName: widget.filename.value, onDone: (String newName) {
                  widget.filename.value = newName;
                });
              },
              tooltip: localizations.renameFileTooltip,
            )
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16.0), children: [
            ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
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
                                    barrierColor:
                                        Colors.black.withOpacity(0.75),
                                    fullscreenDialog: true,
                                    transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                    pageBuilder: (BuildContext context, _,
                                            __) =>
                                        Center(
                                          child: PhotoView.customChild(
                                            backgroundDecoration:
                                                const BoxDecoration(
                                                    color: Colors.transparent),
                                            child: Center(
                                                child: UploadedFileThumbnail(
                                              fullscreenImage: true,
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
                                        ))).then((value) {
                              if (!isFullThumbnailAvailable &&
                                  ThumbnailsUtils.isFullThumbAvailable(
                                      widget.file.delete!)) {
                                setState(() {});
                              }
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
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.start,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15)))
            ]),
            ListTile(
                leading: const Icon(Icons.archive),
                title: Text(localizations.sizeText),
                subtitle: Text(Utils.humanSize(widget.file.size))),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(localizations.linkText),
              subtitle: Text(widget.file.url),
              trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async => ScaffoldMessenger.of(context).snack(
                        await AppLogic.copy(
                          widget.file.url,
                        )
                            ? localizations.linkCopySuccessful
                            : localizations.linkCopyError,
                      )),
              onTap: () => Share.share(widget.file.url),
            ),
            if (uploadedOnTile != null) uploadedOnTile,
            const Divider(),
            ListTileTheme(
              child: ListTile(
                leading: const Icon(Icons.delete),
                title: Text(localizations.deleteThisFileTile),
                onTap: () => widget.handleDelete.call(widget.file.delete!,
                    onYes: () => Navigator.pop(context)),
              ),
              textColor: Colors.red,
              iconColor: Colors.red,
            )
          ]),
        ));
  }
}
