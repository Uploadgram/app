import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/file_icons.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/widgets/file_widget_grid.dart';

class FilesGrid extends FilesViewerTheme {
  const FilesGrid({Key? key}) : super(key: key);

  @override
  _FilesGridState createState() => _FilesGridState();
}

class _FilesGridState extends State<FilesGrid> {
  Widget _filesWidgets(BuildContext context, int key) {
    var len = AppLogic.queue.length - 1;

    if (key <= len) {
      var uploadingFile = AppLogic.queue[len - key];
      IconData fileIcon = getFileIconFromName(uploadingFile.file.name);
      return UploadingFileWidget(
          builder: (uploading, progress, error, bytesPerSec, file) =>
              FileWidgetGrid(
                file: file,
                icon: fileIcon,
                uploading: uploading,
                progress: progress,
                upperWidget: progress == null
                    ? null
                    : Text(
                        '${(progress * 100).round().toString()}% (${Utils.humanSize(bytesPerSec)}/s)'),
                error: error,
                handleDelete: uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                handleRename: uploading
                    ? null
                    : UploadgramRoute.of(context)?.handleFileRename,
                compact: settings.filesTheme == FilesTheme.gridCompact,
                uploadgramFile: uploadingFile.file,
              ),
          file: uploadingFile);
    }
    if (key > len) key = key - len;

    return FutureBuilder(
        builder: (BuildContext context,
                AsyncSnapshot<UploadedFile?> snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? FileWidgetGrid(
                    key: ValueKey(snapshot.data!.delete!),
                    icon: fileIcons[snapshot.data!.name
                            .split('.')
                            .lastEntry
                            .toLowerCase()] ??
                        fileIcons['default']!,
                    file: snapshot.data!,
                    uploading: false,
                    handleDelete: (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                    handleRename: UploadgramRoute.of(context)?.handleFileRename,
                    compact: settings.filesTheme == FilesTheme.gridCompact,
                  )
                : Shimmer(child: Container()),
        future: UploadedFiles().elementAt(UploadedFiles().length - key));
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    int gridSize = (size.width / 170).floor();
    double aspectRatio =
        settings.filesTheme == FilesTheme.grid ? 1 / 1 : 17 / 6;
    return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: aspectRatio,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            crossAxisCount: gridSize > 0 ? gridSize : 1),
        itemBuilder: _filesWidgets,
        itemCount: UploadedFiles().length + AppLogic.queue.length,
        padding:
            const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 78));
    // bottom: 78, normal padding + fab
  }
}
