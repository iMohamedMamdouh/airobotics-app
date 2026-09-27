import 'package:shared_preferences/shared_preferences.dart';

/// Male Gemini voices that fit Horus.
const maleVoices = <String, String>{
  'Charon': 'Charon (عميق وهادي)',
  'Orus': 'Orus (قوي وواثق)',
  'Fenrir': 'Fenrir (متحمس)',
  'Puck': 'Puck (مرح)',
};

class HorusSettings {
  const HorusSettings({
    this.voiceName = 'Charon',
    this.allowInterruptions = false,
    this.greetOnStart = true,
    this.idleTimeoutSeconds = 60,
  });

  final String voiceName;

  /// When true the mic stays open while Horus talks, so visitors can cut him
  /// off by speaking. When false the mic is muted while he talks, which
  /// avoids Horus hearing his own voice on loud robot speakers.
  final bool allowInterruptions;

  final bool greetOnStart;

  /// Seconds of silence before Horus ends the conversation and returns to
  /// the welcome screen.
  final int idleTimeoutSeconds;

  HorusSettings copyWith({
    String? voiceName,
    bool? allowInterruptions,
    bool? greetOnStart,
    int? idleTimeoutSeconds,
  }) {
    return HorusSettings(
      voiceName: voiceName ?? this.voiceName,
      allowInterruptions: allowInterruptions ?? this.allowInterruptions,
      greetOnStart: greetOnStart ?? this.greetOnStart,
      idleTimeoutSeconds: idleTimeoutSeconds ?? this.idleTimeoutSeconds,
    );
  }
}

class SettingsStore {
  static const _voiceKey = 'voiceName';
  static const _interruptKey = 'allowInterruptions';
  static const _greetKey = 'greetOnStart';
  static const _idleKey = 'idleTimeoutSeconds';

  Future<HorusSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = HorusSettings();
    final voice = prefs.getString(_voiceKey);
    return HorusSettings(
      voiceName: maleVoices.containsKey(voice) ? voice! : defaults.voiceName,
      allowInterruptions:
          prefs.getBool(_interruptKey) ?? defaults.allowInterruptions,
      greetOnStart: prefs.getBool(_greetKey) ?? defaults.greetOnStart,
      idleTimeoutSeconds: prefs.getInt(_idleKey) ?? defaults.idleTimeoutSeconds,
    );
  }

  Future<void> save(HorusSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceKey, settings.voiceName);
    await prefs.setBool(_interruptKey, settings.allowInterruptions);
    await prefs.setBool(_greetKey, settings.greetOnStart);
    await prefs.setInt(_idleKey, settings.idleTimeoutSeconds);
  }
}
