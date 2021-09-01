import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_definitions.g.dart';

class RenameApiResponse {
  final bool ok;
  final String? newName;

  final int statusCode;
  final String? errorMessage;

  RenameApiResponse({
    required this.ok,
    required this.statusCode,
    this.newName,
    this.errorMessage,
  });

  factory RenameApiResponse.fromJson(Map json) => RenameApiResponse(
      ok: json['ok'],
      newName: json['ok'] ? json['new_filename'] : null,
      statusCode: 200);

  @override
  String toString() {
    return '${runtimeType.toString()}(ok: $ok, statusCode: $statusCode)';
  }
}

class DeleteApiResponse {
  final bool ok;
  final int statusCode;

  DeleteApiResponse({
    required this.ok,
    required this.statusCode,
  });

  factory DeleteApiResponse.fromJson(Map json) =>
      DeleteApiResponse(ok: json['ok'], statusCode: 200);
}

enum UploadgramFileError { none, permissionNotGranted, abortedByUser }

class UploadgramFile<T> {
  final int size;
  final String name;
  final T realFile; // this should either be a web file or a io file

  UploadgramFile({
    required this.size,
    required this.name,
    required this.realFile,
  });

  UploadgramFile copyWith({
    int? size,
    String? name,
    Object? realFile,
  }) =>
      UploadgramFile(
          name: name ?? this.name, size: size ?? this.size, realFile: realFile);

  UploadgramFile withoutRealFile() =>
      UploadgramFile(size: size, name: name, realFile: null);
}

class UploadingFile {
  final String taskId;
  final UploadgramFile file;
  Stream<UploadingEvent>? stream;
  DateTime? startedUploadingAt;

  UploadingFile({
    required this.file,
    required this.taskId,
    this.stream,
    this.startedUploadingAt,
  });

  UploadingFile copyWith(
          {UploadgramFile? file,
          String? taskId,
          Stream<UploadingEvent>? stream}) =>
      UploadingFile(
          file: file ?? this.file,
          taskId: taskId ?? this.taskId,
          stream: stream ?? this.stream);
  @override
  String toString() => 'UploadingFile(${file.name} (${file.size}), $taskId)';
}

class UploadingEvent {}

class UploadingEventProgress extends UploadingEvent {
  double progress;
  int bytesPerSec;

  UploadingEventProgress({
    required this.progress,
    required this.bytesPerSec,
  });
}

enum UploadingEventErrorType {
  generic,
  canceled,
}

class UploadingEventError implements Exception {
  final UploadingEventErrorType errorType;
  final int? statusCode;
  final String? message;
  UploadingEventError({
    required this.errorType,
    required this.message,
    this.statusCode,
  });
}

class UploadingEventResponse extends UploadingEvent with EquatableMixin {
  final String url;
  final String delete;

  final int statusCode;

  UploadingEventResponse({
    required this.url,
    required this.delete,
    this.statusCode = 200,
  });

  factory UploadingEventResponse.fromJson(Map json,
      {bool shouldAddFileToBox = true}) {
    return UploadingEventResponse(
        url: json['url'] as String, delete: json['delete'] as String);
  }

  @override
  List<Object?> get props => [url, delete, statusCode];
}

@JsonSerializable()
class Endpoint extends Equatable {
  final String main;
  final String download;
  final String api;
  const Endpoint({
    required this.main,
    required this.download,
    required this.api,
  });
  const Endpoint.single(this.main)
      : download = main,
        api = main;

  /// can return a [Map] or a [String]
  Object toJson() {
    if (main == download && download == api) return main;
    return _$EndpointToJson(this);
  }

  factory Endpoint.fromJson(Object json) {
    if (json is! String && json is! Map<String, dynamic>) throw Exception();
    if (json is String) return Endpoint.single(json);
    return _$EndpointFromJson(json as Map<String, dynamic>);
  }

  @override
  List<Object?> get props => [main, download, api];
}
