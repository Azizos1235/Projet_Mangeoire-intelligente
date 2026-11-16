// ignore: constant_identifier_names
const String API_BASE_URL = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://cloud-server-icjx.onrender.com',
);

Uri get wsBaseUri {
  final apiUri = Uri.parse(API_BASE_URL);
  return apiUri.replace(
    scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
  );
}
