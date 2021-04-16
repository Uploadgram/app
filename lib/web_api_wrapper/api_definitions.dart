class RenameApiResponse {
  final bool ok;
  final String? newName;

  final int statusCode;
  final String? errorMessage;

  RenameApiResponse(
      {required this.ok,
      this.newName,
      this.statusCode = 200,
      this.errorMessage});

  factory RenameApiResponse.fromJson(Map json) => RenameApiResponse(
      ok: json['ok'], newName: json['ok'] ? json['new_filename'] : null);
}

class UploadApiResponse {
  final bool ok;
  final String? url;
  final String? delete;

  final int statusCode;
  final String? errorMessage;

  UploadApiResponse(
      {required this.ok,
      this.url,
      this.delete,
      this.statusCode = 200,
      this.errorMessage});

  factory UploadApiResponse.fromJson(Map json) {
    if (json['ok'])
      return UploadApiResponse(
          ok: json['ok'], url: json['url'], delete: json['delete']);
    return UploadApiResponse(
        ok: false,
        statusCode: json['statusCode'],
        errorMessage: json['message']);
  }
}
