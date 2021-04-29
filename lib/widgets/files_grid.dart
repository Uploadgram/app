import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';

import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/file_icons.dart';
import 'package:uploadgram/selected_files_notifier.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/widgets/file_widget_grid.dart';

class FilesGrid extends FilesViewerTheme {
  final SelectedFilesNotifier selectedFiles;
  FilesGrid({
    required this.selectedFiles,
  });
  Widget _filesWidgets(BuildContext context, int key) {
    var len = AppLogic.uploadingQueue.length - 1;

    if (key <= len) {
      var uploadingFile = AppLogic.uploadingQueue[len - key];
      IconData fileIcon =
          getFileIconFromName(uploadingFile.uploadgramFile.name);
      return buildUploadingWidget(
          (uploading, progress, error, bytesPerSec, delete, file) =>
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
                selectedFilesNotifier: selectedFiles,
                handleDelete: uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                handleRename: uploading
                    ? null
                    : UploadgramRoute.of(context)?.handleFileRename,
                compact: AppSettings.filesTheme == FilesTheme.gridCompact,
                uploadgramFile: uploadingFile.uploadgramFile,
              ),
          uploadingFile);
    }
    if (key > len) key = key - len;

    return FutureBuilder(
        builder: (BuildContext context,
                AsyncSnapshot<UploadedFile?> snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? FileWidgetGrid(
                    key: Key(snapshot.data!.delete!),
                    icon: fileIcons[snapshot.data!.name
                            .split('.')
                            .last
                            .toLowerCase()] ??
                        fileIcons['default']!,
                    file: snapshot.data!,
                    uploading: false,
                    selectedFilesNotifier: selectedFiles,
                    handleDelete: (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                    handleRename: UploadgramRoute.of(context)?.handleFileRename,
                    compact: AppSettings.filesTheme == FilesTheme.gridCompact,
                  )
                : Center(child: CircularProgressIndicator()),
        future: AppLogic.files.elementAt(AppLogic.files.length - key));
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    int gridSize = (size.width / 170).floor();
    double aspectRatio =
        AppSettings.filesTheme == FilesTheme.grid ? 1 / 1 : 17 / 6;
    print('Reloaded state!');
    return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: aspectRatio,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            crossAxisCount: gridSize > 0 ? gridSize : 1),
        itemBuilder: _filesWidgets,
        itemCount: AppLogic.files.length + AppLogic.uploadingQueue.length,
        padding: EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 78));
    // bottom: 78, normal padding + fab
  }
}
