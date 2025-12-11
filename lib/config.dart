import 'package:uploadgram/api_definitions.dart';

const int maxUploadSize = 2 * 1000 * 1000 * 1000;

const bool enableAutoUpdater = true;

// If you have a single endpoint, you can use the Endpoint.single constructor
// Uploadgram's public instance is dead, meaning that it doesn't make sense
// specifying a default endpoint now.
/// App's default endpoints
const Endpoint? defaultEndpoint = null;
