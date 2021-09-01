import 'package:flutter/cupertino.dart';

/// Simple [ValueNotifier] that wraps around a [List]
class ListNotifier<T> extends ValueNotifier<List<T>> {
  ListNotifier() : super(<T>[]);

  void add(T newItem) {
    value.add(newItem);
    notifyListeners();
  }

  void remove(T item) {
    value.remove(item);
    notifyListeners();
  }

  void clear() {
    value.clear();
    notifyListeners();
  }

  int get length => value.length;
  bool contains(T item) => value.contains(item);
  operator [](int _) => value[_];

  bool get isEmpty => value.isEmpty;
  bool get isNotEmpty => value.isNotEmpty;
}
