import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';

class IsFileSelectedBuilder extends Selector<SelectedFilesProvider, bool> {
  IsFileSelectedBuilder({
    Key? key,
    required ValueWidgetBuilder<bool> builder,
    required String? delete,
    Widget? child,
  }) : super(
          key: key,
          builder: builder,
          child: child,
          selector: delete == null
              ? (_, __) => false
              : (context, provider) => provider.contains(delete),
          shouldRebuild: (previous, next) => previous != next,
        );
}

class IsAnyFileSelectedBuilder extends Selector<SelectedFilesProvider, bool> {
  IsAnyFileSelectedBuilder({
    Key? key,
    required ValueWidgetBuilder<bool> builder,
    Widget? child,
  }) : super(
            key: key,
            builder: builder,
            selector: (context, provider) => provider.length > 0,
            child: child,
            shouldRebuild: (prev, next) => prev != next);
}

class FilesSelectedBuilder extends Selector<SelectedFilesProvider, int> {
  FilesSelectedBuilder({
    Key? key,
    required ValueWidgetBuilder<int> builder,
    Widget? child,
  }) : super(
            key: key,
            builder: builder,
            selector: (context, provider) => provider.length,
            child: child,
            shouldRebuild: (prev, next) => prev != next);
}

class IsFileOrAnySelectedBuilder
    extends Selector<SelectedFilesProvider, Tuple2<bool, bool>> {
  IsFileOrAnySelectedBuilder({
    Key? key,
    required ValueWidgetBuilder<Tuple2<bool, bool>> builder,
    required String? delete,
    Widget? child,
  }) : super(
            key: key,
            builder: builder,
            selector: delete == null
                ? (_, __) => const Tuple2(false, false)
                : (context, provider) =>
                    Tuple2(provider.contains(delete), provider.length > 0),
            child: child);
}
