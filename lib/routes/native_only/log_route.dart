import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/internal_api_wrapper/native_platform.dart';

class LoggingRoute extends StatefulWidget {
  const LoggingRoute({Key? key}) : super(key: key);

  @override
  _LoggingRouteState createState() => _LoggingRouteState();
}

class _LoggingRouteState extends State<LoggingRoute> {
  Set<String> loggerNames = {};
  final ScrollController _controller = ScrollController();
  final _freeScroll = ValueNotifier(false);
  bool _expandAll = false;
  Exception? error;

  Set<String> deselectedLoggerNames = {};
  late Level fromLevel = Logger.root.level;

  @override
  void initState() {
    _controller.addListener(() {
      if (_controller.offset == 0.0) {
        _freeScroll.value = false;
      } else {
        _freeScroll.value = true;
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    loggerNames.clear();
    super.dispose();
  }

  void clearLogs() {
    final localizations = AppLocalizations.of(context);
    if (InternalAPIWrapper().loggingBox.isEmpty) {
      ScaffoldMessenger.of(context)
          .snack(localizations.logsNoLogsToDeleteError);
      return;
    }
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(localizations.deleteLogs),
              content: Text(localizations.deleteLogsDialogSubtitle),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(localizations.dialogNo)),
                TextButton(
                    onPressed: () {
                      error = null;
                      Navigator.pop(context);
                      InternalAPIWrapper()
                          .clearLogs()
                          .then((value) => setState(() {}));
                    },
                    child: Text(localizations.dialogYes))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final length = InternalAPIWrapper().loggingBox.length;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.appLogs), actions: [
        IconButton(
            onPressed: () => showDialog(
                context: context,
                builder: (context) => _FilterDialog(
                      loggerNames: loggerNames,
                      onChanged: (fromLevel, deselectedLoggerNames) =>
                          setState(() {
                        this.fromLevel = fromLevel;
                        this.deselectedLoggerNames = deselectedLoggerNames;
                      }),
                      fromLevel: fromLevel,
                      deselectedLoggerNames: deselectedLoggerNames,
                    )),
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.filterLogsDialog),
        IconButton(
            onPressed: clearLogs,
            icon: const Icon(Icons.delete),
            tooltip: localizations.deleteLogs),
        IconButton(
            onPressed: () => setState(() => _expandAll = !_expandAll),
            icon: Icon(_expandAll ? Icons.expand_less : Icons.expand_more),
            tooltip: _expandAll
                ? localizations.collapseAll
                : localizations.expandAll),
      ]),
      body: SafeArea(
        child: error == null
            ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                controller: _controller,
                shrinkWrap: true,
                reverse: true,
                itemBuilder: (context, index) {
                  return FutureBuilder<UploadgramLogRecord?>(
                    future: InternalAPIWrapper()
                        .loggingBox
                        .getAt(length - 1 - index),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(height: 64.0);
                      }
                      final entry = snapshot.data;
                      if (entry != null &&
                          entry.level >= fromLevel &&
                          !deselectedLoggerNames.contains(entry.loggerName)) {
                        loggerNames.add(entry.loggerName);

                        return _LogEntryTile(
                          key: Key('$index$_expandAll'),
                          entry: entry,
                          startExpanded: _expandAll,
                        );
                      }
                      return const SizedBox();
                    },
                  );
                },
                //separatorBuilder: (context, index) => Divider(),
                itemCount: length)
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 42.0,
                      ),
                      const SizedBox(height: 8.0),
                      Text(error.toString(),
                          style: const TextStyle(fontSize: 16.0),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16.0),
                      Text(localizations.errorClearingLogsTip,
                          style: const TextStyle(fontSize: 16.0),
                          textAlign: TextAlign.center)
                    ]),
              ),
      ),
      //: Center(
      //    child: Column(
      //      children: [
      //        CircularProgressIndicator(),
      //        const SizedBox(height: 15),
      //        Text('Please wait, fetching logs...'),
      //      ],
      //      mainAxisAlignment: MainAxisAlignment.center,
      //      crossAxisAlignment: CrossAxisAlignment.center,
      //    ),
      floatingActionButton:
          error == null && InternalAPIWrapper().loggingBox.isNotEmpty
              ? ValueListenableBuilder(
                  valueListenable: _freeScroll,
                  builder: (context, bool value, _) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        if (value) ...[
                          FloatingActionButton(
                              mini: true,
                              child: const Icon(Icons.arrow_downward),
                              onPressed: () {
                                _controller.jumpTo(0.0);
                                _freeScroll.value = false;
                              }),
                          const SizedBox(height: 16.0),
                        ],
                        FloatingActionButton(
                            onPressed: () => InternalAPIWrapper().saveLogs(),
                            child: const Icon(Icons.save),
                            tooltip: localizations.exportLogsTooltip),
                      ]))
              : null,
    );
  }
}

class _LogEntryTile extends StatefulWidget {
  final UploadgramLogRecord entry;
  final bool startExpanded;
  static const _defaultLinesOfText = 2;
  static const _entryFontSize = 14.0;
  const _LogEntryTile({
    Key? key,
    required this.entry,
    this.startExpanded = false,
  }) : super(key: key);

  @override
  __LogEntryTileState createState() => __LogEntryTileState();
}

class __LogEntryTileState extends State<_LogEntryTile> {
  late bool expand = widget.startExpanded;
  TapDownDetails? _tapPosition;

  @override
  Widget build(BuildContext context) {
    final color = chooseColorForLevel(widget.entry.level);
    return GestureDetector(
      onTapDown: (details) => _tapPosition = details,
      child: ListTile(
          title: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text:
                      '[${widget.entry.time.toString()}] ${widget.entry.loggerName} '),
              TextSpan(
                  text: widget.entry.level.name,
                  style: TextStyle(
                      backgroundColor: color,
                      color: textColorWithColor(color))),
              TextSpan(text: ': ${widget.entry.message}'),
            ], style: const TextStyle(fontSize: _LogEntryTile._entryFontSize)),
            maxLines: expand ? null : _LogEntryTile._defaultLinesOfText,
            overflow: expand ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          onLongPress: showPopupMenu,
          onTap: () => setState(() => expand = !expand)),
    );
  }

  Color chooseColorForLevel(Level level) {
    return {
          1000: Colors.red,
          900: Colors.yellow,
          500: Colors.purple[400],
          400: Colors.purple[700],
          300: Colors.purple[900],
        }[level.value] ??
        Colors.white;
  }

  Color textColorWithColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  void showPopupMenu() async {
    if (_tapPosition == null) return;
    final overlay =
        Overlay?.of(context)?.context.findRenderObject() as RenderBox;
    showMenu<_LogTileMenuEntry>(
        context: context,
        position: RelativeRect.fromSize(
            _tapPosition!.globalPosition & Size.zero, overlay.size),
        items: [
          PopupMenuItem(
              child: Text(AppLocalizations.of(context).actionCopy),
              value: _LogTileMenuEntry.copy),
        ]).then((selected) {
      switch (selected) {
        case _LogTileMenuEntry.copy:
          Clipboard.setData(ClipboardData(text: widget.entry.format()));
          break;
        default:
          break;
      }
    });
  }
}

enum _LogTileMenuEntry {
  copy,
}

class _FilterDialog extends StatefulWidget {
  final Set<String> loggerNames;
  final Function(Level fromLevel, Set<String> deselectedLoggerNames) onChanged;
  final Level fromLevel;
  final Set<String> deselectedLoggerNames;
  const _FilterDialog({
    Key? key,
    required this.loggerNames,
    required this.onChanged,
    required this.fromLevel,
    required this.deselectedLoggerNames,
  }) : super(key: key);

  @override
  __FilterDialogState createState() => __FilterDialogState();
}

class __FilterDialogState extends State<_FilterDialog> {
  late final levels =
      Level.LEVELS.sublist(Level.LEVELS.indexOf(Logger.root.level));
  late int _levelSliderValue = levels.indexOf(widget.fromLevel);
  late final Set<String> _deselectedLoggerNames =
      Set.from(widget.deselectedLoggerNames);
  @override
  Widget build(BuildContext context) {
    final length = levels.length - 1;
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.filterLogsDialog),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.filterLogsDialogFrom,
              style: Theme.of(context).textTheme.overline),
          const Divider(),
          Wrap(
              children: widget.loggerNames
                  .map((loggerName) => FilterChip(
                        label: Text(loggerName),
                        onSelected: (selected) => setState(() => selected
                            ? _deselectedLoggerNames.remove(loggerName)
                            : _deselectedLoggerNames.add(loggerName)),
                        selected: !_deselectedLoggerNames.contains(loggerName),
                      ))
                  .toList(growable: false)),
          const SizedBox(height: 16.0),
          Text(localizations.filterLogsDialogVerbosity,
              style: Theme.of(context).textTheme.overline),
          const Divider(),
          Slider(
            value: (length - _levelSliderValue).toDouble(),
            onChanged: (value) =>
                setState(() => _levelSliderValue = length - value.toInt()),
            max: length.toDouble(),
            divisions: length,
            label: levels[_levelSliderValue].name,
          )
        ],
      )),
      actions: [
        TextButton(
            child: Text(localizations.dialogCancel),
            onPressed: () => Navigator.pop(context)),
        TextButton(
            child: Text(localizations.endpointsDialogActionDefault),
            onPressed: () {
              widget.onChanged.call(Logger.root.level, {});
              Navigator.pop(context);
            }),
        TextButton(
            child: Text(localizations.dialogOK),
            onPressed: () {
              widget.onChanged
                  .call(levels[_levelSliderValue], _deselectedLoggerNames);
              Navigator.pop(context);
            }),
      ],
    );
  }
}
