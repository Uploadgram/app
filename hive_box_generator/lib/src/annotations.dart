class HiveBox {
  final String boxName;
  final bool isLazyBox;
  const HiveBox({required this.boxName, this.isLazyBox = false});
}

class HiveBoxField<T> {
  final T? defaultValue;
  const HiveBoxField({this.defaultValue});
}
