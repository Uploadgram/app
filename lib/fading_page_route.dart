import 'package:flutter/material.dart';

class FadingPageRoute<T> extends PageRoute<T> {
  final Widget child;
  FadingPageRoute(this.child);

  String? get barrierLabel => null;

  bool get barrierDismissible => true;

  Color get barrierColor => Colors.black54;

  bool get opaque => false;

  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  bool get maintainState => true;

  Duration get transitionDuration => Duration(milliseconds: 200);
}
