import 'package:flutter/material.dart';

class FadingPageRoute<T> extends PageRoute<T> {
  final Widget child;
  FadingPageRoute(this.child);

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  bool get opaque => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      FadeTransition(
        opacity: animation,
        child: child,
      );

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
}
