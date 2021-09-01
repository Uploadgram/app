import 'package:flutter/material.dart';

class PopupMenuItemIcon<T> extends PopupMenuItem<T> {
  PopupMenuItemIcon({
    Key? key,
    required T value,
    required Icon icon,
    required Widget child,
  }) : super(
            key: key,
            value: value,
            child: _PopupMenuTile(icon: icon, child: child));
}

class _PopupMenuTile extends StatelessWidget {
  final Widget icon;
  final Widget child;
  const _PopupMenuTile({Key? key, required this.icon, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconTheme(
              data: IconThemeData(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[700]
                      : Colors.white),
              child: icon),
          const SizedBox(width: 16.0),
          Flexible(child: child),
        ],
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
      );
}
