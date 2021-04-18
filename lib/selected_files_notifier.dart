import 'package:flutter/cupertino.dart';

class SelectedFilesNotifier extends ValueNotifier<List<String>> {
  SelectedFilesNotifier() : super(<String>[]);

  void add(String newItem) {
    value.add(newItem);
    notifyListeners();
  }

  void remove(String item) {
    value.remove(item);
    notifyListeners();
  }

  void clear() {
    value.clear();
    notifyListeners();
  }

  int get length => value.length;
  bool contains(String item) => value.contains(item);
  operator [](int _) => value[_];
}
