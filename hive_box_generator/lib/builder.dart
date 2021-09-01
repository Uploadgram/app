import 'package:hive_box_generator/hive_box_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_helper/source_helper.dart';

const _settingsFieldChecker = TypeChecker.fromRuntime(HiveBoxField);

class HiveBoxGenerator extends GeneratorForAnnotation<HiveBox> {
  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final isLazyBox = annotation.read('isLazyBox').boolValue;
    final boxName = annotation.read('boxName').stringValue;
    assert(element.kind == ElementKind.CLASS);
    var classElement = element as ClassElement;
    var elements = classElement.fields
        .where((element) => _settingsFieldChecker.hasAnnotationOf(element));
    var codeBuilder = StringBuffer(
        '''class _\$${classElement.name}Instance extends ${classElement.name} {
        ${generateForBoxClass(elements, boxName, isLazyBox: isLazyBox)}
      }''');
    return codeBuilder.toString();
  }

  String generateForBoxClass(Iterable<FieldElement> elements, String boxName,
      {bool isLazyBox = false}) {
    var codeBuilder = StringBuffer('''
      late final ${isLazyBox ? 'Lazy' : ''}Box _box;

      @override
      Future<void> init() async {
        _box = await Hive.open${isLazyBox ? 'Lazy' : ''}Box('$boxName');
        await super.init();
      }

      @override
      Future<void> close() async {
        await super.close();
        await _box.close();
      }

      Future<void> clear() => _box.clear();

      ''');
    for (var element in elements) {
      var elAnnotation = _settingsFieldChecker.firstAnnotationOfExact(element);
      var defaultValue = elAnnotation!.getField('defaultValue');
      final forceNullable = defaultValue == null || defaultValue.isNull;
      final setterType = typeToCode(element.type, forceNullable: forceNullable);
      final getterType = forceNullable || !element.type.isNullableType
          ? setterType
          : element.type.element!.name;
      if (isLazyBox) {
        codeBuilder.writeln('''
          Future<$getterType> get${firstCapitalize(element.name)}() =>
            _box.get('${element.name}'${defaultValue == null ? '' : ', defaultValue: ' + constantToString(defaultValue)}).then((value) => value as $getterType);

          Future<void> set${firstCapitalize(element.name)}($setterType value) =>
            _box.put('${element.name}', value);
        ''');
      } else {
        codeBuilder.writeln('''
        @override
        $getterType get ${element.name} =>
          _box.get('${element.name}'${defaultValue == null ? '' : ', defaultValue: ' + constantToString(defaultValue)}) as $getterType;
        @override
        set ${element.name}($setterType value) =>
          _box.put('${element.name}', value);
      ''');
      }
    }
    return codeBuilder.toString();
  }

  String firstCapitalize(String input) {
    return input.substring(0, 1).toUpperCase() + input.substring(1);
  }

  String constantToString(
    DartObject? object, [
    List<String> typeInformation = const [],
  ]) {
    if (object == null || object.isNull) return 'null';
    final reader = ConstantReader(object);
    return reader.isLiteral
        ? literalToString(object, typeInformation)
        : revivableToString(object, typeInformation);
  }

  String revivableToString(DartObject? object, List<String> typeInformation) {
    final reader = ConstantReader(object);
    final revivable = reader.revive();

    if (revivable.source.fragment.isEmpty) {
      // Enums
      return revivable.accessor;
    } else {
      // Classes
      final nextTypeInformation = [...typeInformation, '$object'];
      final ctor = revivable.accessor.isEmpty ? '' : '.${revivable.accessor}';
      final arguments = <String>[
        for (var arg in revivable.positionalArguments)
          constantToString(arg, nextTypeInformation),
        for (var kv in revivable.namedArguments.entries)
          '${kv.key}: ${constantToString(kv.value, nextTypeInformation)}'
      ];

      return 'const ${revivable.source.fragment}$ctor(${arguments.join(', ')})';
    }
  }

// The code below is based on code from https://github.com/google/json_serializable.dart/blob/df60c2a95c4c0054d6ab785849937d7f5ade39fe/json_serializable/lib/src/json_key_utils.dart#L43

  String literalToString(DartObject object, List<String> typeInformation) {
    final reader = ConstantReader(object);

    String? badType;
    if (reader.isSymbol) {
      badType = 'Symbol';
    } else if (reader.isType) {
      badType = 'Type';
    } else if (object.type is FunctionType) {
      badType = 'Function';
    } else if (!reader.isLiteral) {
      badType = object.type!.element!.name;
    }

    if (badType != null) {
      badType = typeInformation.followedBy([badType]).join(' > ');
      throwUnsupported('`defaultValue` is `$badType`, it must be a literal.');
    }

    if (reader.isDouble || reader.isInt || reader.isString || reader.isBool) {
      final value = reader.literalValue;

      if (value is String) return escapeDartString(value);

      if (value is double) {
        if (value.isNaN) {
          return 'double.nan';
        }

        if (value.isInfinite) {
          if (value.isNegative) {
            return 'double.negativeInfinity';
          }
          return 'double.infinity';
        }
      }

      if (value is bool || value is num) return value.toString();
    }

    if (reader.isList) {
      final listTypeInformation = [...typeInformation, 'List'];
      final listItems = reader.listValue
          .map((it) => constantToString(it, listTypeInformation))
          .join(', ');
      return '[$listItems]';
    }

    if (reader.isSet) {
      final setTypeInformation = [...typeInformation, 'Set'];
      final setItems = reader.setValue
          .map((it) => constantToString(it, setTypeInformation))
          .join(', ');
      return '{$setItems}';
    }

    if (reader.isMap) {
      final mapTypeInformation = [...typeInformation, 'Map'];
      final buffer = StringBuffer('{');

      var first = true;

      reader.mapValue.forEach((key, value) {
        if (first) {
          first = false;
        } else {
          buffer.writeln(',');
        }

        buffer
          ..write(constantToString(key, mapTypeInformation))
          ..write(': ')
          ..write(constantToString(value, mapTypeInformation));
      });

      buffer.write('}');

      return buffer.toString();
    }

    badType = typeInformation.followedBy(['$object']).join(' > ');
    throwUnsupported(
      'The provided value is not supported: $badType. '
      'This may be an error in package:json_serializable. '
      'Please rerun your build with `--verbose` and file an issue.',
    );
  }

  Never throwUnsupported(String message) =>
      throw InvalidGenerationSourceError('Error with `@HiveBox`. $message');

  /// Return the Dart code presentation for the given [type].
  ///
  /// This function is intentionally limited, and does not support all possible
  /// types and locations of these files in code. Specifically, it supports
  /// only [InterfaceType]s, with optional type arguments that are also should
  /// be [InterfaceType]s.
  String typeToCode(
    DartType type, {
    bool forceNullable = false,
  }) {
    if (type.isDynamic) {
      return 'dynamic';
    } else if (type is InterfaceType) {
      return [
        type.element.name,
        if (type.typeArguments.isNotEmpty)
          '<${type.typeArguments.map(typeToCode).join(', ')}>',
        (type.isNullableType || forceNullable) ? '?' : '',
      ].join();
    }
    throw UnimplementedError('(${type.runtimeType}) $type');
  }
}

Builder hiveBoxBuilder(BuilderOptions options) =>
    SharedPartBuilder([HiveBoxGenerator()], 'hive_box_generator');
