import 'package:uploadgram/api_definitions.dart';

const int maxUploadSize = 2 * 1000 * 1000 * 1000;

// If you have a single endpoint, you can use the Endpoint.single constructor
/// App's default endpoints
const Endpoint defaultEndpoint = Endpoint(
  main: 'uploadgram.me',
  download: 'dl.uploadgram.me',
  api: 'api.uploadgram.me',
);
