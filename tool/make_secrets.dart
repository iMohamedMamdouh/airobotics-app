// Creates config/secrets.json from the google-services.json downloaded
// from Firebase, so no key has to be copied by hand.
//
// Usage:
//   dart run tool/make_secrets.dart [path/to/google-services.json] [appCheckDebugToken]
//
// The google-services.json path defaults to android/app/google-services.json.
// The App Check debug token defaults to the one already in
// config/secrets.json, or a new one is generated.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _defaultModel = 'gemini-2.5-flash-native-audio-preview-09-2025';
final _uuid = RegExp(
  r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
);

void main(List<String> args) {
  final servicesPath = args.isNotEmpty
      ? args[0]
      : 'android/app/google-services.json';
  final servicesFile = File(servicesPath);
  if (!servicesFile.existsSync()) {
    stderr.writeln('Not found: $servicesPath');
    stderr.writeln(
      'Download google-services.json from Firebase Console '
      '(Project settings > Your apps) and pass its path.',
    );
    exit(1);
  }

  final services = jsonDecode(servicesFile.readAsStringSync()) as Map;
  final project = services['project_info'] as Map;
  final client = (services['client'] as List).cast<Map>().firstWhere(
    (c) =>
        c['client_info']['android_client_info']['package_name'] ==
        'com.company.airobotics',
    orElse: () => (services['client'] as List).first as Map,
  );

  final secretsFile = File('config/secrets.json');
  final existing = secretsFile.existsSync()
      ? (jsonDecode(secretsFile.readAsStringSync()) as Map)
      : const {};

  var token = args.length > 1
      ? args[1]
      : '${existing['APP_CHECK_DEBUG_TOKEN']}';
  var newToken = false;
  if (!_uuid.hasMatch(token)) {
    token = _randomUuid();
    newToken = true;
  }

  final secrets = {
    'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
    'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
    'FIREBASE_MESSAGING_SENDER_ID': project['project_number'],
    'FIREBASE_PROJECT_ID': project['project_id'],
    'APP_CHECK_DEBUG_TOKEN': token,
    'GEMINI_LIVE_MODEL': existing['GEMINI_LIVE_MODEL'] ?? _defaultModel,
  };
  secretsFile
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(secrets)}\n',
    );

  final key = secrets['FIREBASE_API_KEY'] as String;
  stdout.writeln('Wrote config/secrets.json');
  stdout.writeln(
    '  API key: ${key.substring(0, 6)}...${key.substring(key.length - 4)} '
    '(${key.length} chars)',
  );
  stdout.writeln('  Project: ${secrets['FIREBASE_PROJECT_ID']}');
  if (newToken) {
    stdout.writeln('');
    stdout.writeln('New App Check debug token (register it in Firebase');
    stdout.writeln('App Check > Apps > Manage debug tokens):');
    stdout.writeln('  $token');
  }
}

String _randomUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
          '${h.substring(16, 20)}-${h.substring(20)}'
      .toUpperCase();
}
