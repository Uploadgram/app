import 'package:flutter/material.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/file_icons.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/widgets/selected_files_builder.dart';

class FilesList extends FilesViewerTheme {
  const FilesList({Key? key}) : super(key: key);

  @override
  _FilesListState createState() => _FilesListState();
}

class _FilesListState extends State<FilesList> {
  Widget _filesWidgets(BuildContext context, int index) {
    var queueLength = AppLogic.queue.length;
    if (index < queueLength) {
      UploadingFile uploadingFile = AppLogic.queue[queueLength - 1 - index];
      IconData fileIcon = getFileIconFromName(uploadingFile.file.name);
      return UploadingFileWidget(
          builder: (uploading, progress, error, bytesPerSec, file) =>
              FileListTile(
                bytesPerSec: bytesPerSec,
                icon: fileIcon,
                file: file,
                handleDelete: uploading
                    ? null
                    : (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)
                            ?.handleFileDelete([delete], onYes: onYes),
                handleRename: uploading
                    ? null
                    : UploadgramRoute.of(context)!.handleFileRename,
                uploading: uploading,
                progress: progress,
              ),
          file: uploadingFile);
    }
    if (index >= queueLength) index = index - queueLength;
    return FutureBuilder(
        builder: (BuildContext context,
                AsyncSnapshot<UploadedFile?> snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? FileListTile(
                    key: ValueKey(snapshot.data!.delete!),
                    icon: getFileIconFromName(snapshot.data!.name),
                    file: snapshot.data!,
                    handleDelete: (String delete, {Function? onYes}) =>
                        UploadgramRoute.of(context)!
                            .handleFileDelete([delete], onYes: onYes),
                    handleRename: UploadgramRoute.of(context)!.handleFileRename,
                  )
                : const ListTile(leading: CircularProgressIndicator()),
        future: UploadedFiles().elementAt(UploadedFiles().length - index - 1));
  }

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      child: ListView.builder(
          itemBuilder: _filesWidgets,
          itemCount: UploadedFiles().length + AppLogic.queue.length,
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, top: 16.0, bottom: 78.0)),
      selectedTileColor: Colors
          .grey[Theme.of(context).brightness == Brightness.dark ? 900 : 200],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(listBorderRadius)),
      selectedColor: null,
      minVerticalPadding: 5.0,
    );
  }
}

class FileListTile extends StatelessWidget {
  final IconData icon;
  final String? error;
  final bool uploading;
  final double? progress;
  final bool selected;
  final Function(String, {Function? onYes})? handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})?
      handleRename;
  final int? bytesPerSec;
  final UploadedFile file;

  const FileListTile({
    Key? key,
    required this.icon,
    required this.file,
    this.uploading = false,
    this.selected = false,
    this.error,
    this.progress,
    this.handleDelete,
    this.handleRename,
    this.bytesPerSec,
  })  : assert(uploading || (handleDelete != null && handleRename != null)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<String> _filenameNotifier =
        ValueNotifier<String>(file.name);
    final subtitle = error != null
        ? Text(error!, style: const TextStyle(color: Colors.red))
        : uploading
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (progress != null)
                      Padding(
                          child:
                              Text('${(progress! * 100).round().toString()}%'),
                          padding: const EdgeInsets.only(right: 16.0)),
                    Expanded(child: LinearProgressIndicator(value: progress)),
                    Padding(
                        child: Text('${Utils.humanSize(bytesPerSec!)}/s'),
                        padding: const EdgeInsets.only(left: 16.0)),
                  ],
                )
              ])
            : Text(Utils.humanSize(file.size));
    Function() openFileInfo = () => UploadgramRoute.of(context)!.openFileInfo(
        file: file, filenameNotifier: _filenameNotifier, icon: icon, tag: null);
    Function() selectWidget =
        () => UploadgramRoute.of(context)!.selectWidget(file.delete!);
    if (uploading || file.delete == null) {
      selectWidget = openFileInfo = () => null;
    }
    return FileRightClickListener(
        delete: file.delete,
        filenameNotifier: _filenameNotifier,
        handleDelete: handleDelete,
        handleRename: handleRename,
        size: file.size,
        url: file.url,
        child: IsFileOrAnySelectedBuilder(
          delete: file.delete!,
          builder: (context, tuple, _) => ListTile(
            leading: GestureDetector(
                child: AnimatedCrossFade(
                    firstChild:
                        Icon(icon, size: 24, color: Colors.grey.shade700),
                    secondChild: Icon(Icons.check_circle,
                        size: 24,
                        color: Theme.of(context).colorScheme.secondary),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    crossFadeState: selected
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200)),
                onTap: selectWidget,
                onLongPress: selectWidget),
            title: ValueListenableBuilder<String>(
                valueListenable: _filenameNotifier,
                builder: (BuildContext context, String value, _) =>
                    Text(value, maxLines: 2, overflow: TextOverflow.ellipsis)),
            subtitle: subtitle,
            onTap: uploading
                ? null
                : tuple.item2
                    ? selectWidget
                    : openFileInfo,
            onLongPress: uploading ? null : selectWidget,
            selected: tuple.item1,
          ),
        ));
  }
}
