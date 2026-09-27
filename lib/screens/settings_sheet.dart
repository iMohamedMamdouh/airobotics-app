import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/horus_controller.dart';
import '../services/settings_store.dart';

/// Hidden operator settings (opened by long-pressing the logo).
Future<void> showSettingsSheet(BuildContext context, HorusController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SettingsSheet(controller: c),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.controller});

  final HorusController controller;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late HorusSettings _settings = widget.controller.settings;

  void _update(HorusSettings s) {
    setState(() => _settings = s);
    widget.controller.updateSettings(s);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إعدادات حورس', style: textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('صوت حورس', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in maleVoices.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _settings.voiceName == entry.key,
                    onSelected: (_) =>
                        _update(_settings.copyWith(voiceName: entry.key)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('يسمح للزائر يقاطع حورس وهو بيتكلم'),
              subtitle: const Text(
                'لو السماعة عالية وحورس بيقاطع نفسه، اقفل الاختيار ده.',
              ),
              value: _settings.allowInterruptions,
              onChanged: (v) =>
                  _update(_settings.copyWith(allowInterruptions: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('حورس يرحب بالزائر أول ما يضغط'),
              value: _settings.greetOnStart,
              onChanged: (v) => _update(_settings.copyWith(greetOnStart: v)),
            ),
            const SizedBox(height: 8),
            Text(
              'ينهي المحادثة بعد ${_settings.idleTimeoutSeconds} ثانية سكوت',
              style: textTheme.titleMedium,
            ),
            Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: _settings.idleTimeoutSeconds.toDouble(),
              label: '${_settings.idleTimeoutSeconds}',
              onChanged: (v) => setState(
                () => _settings = _settings.copyWith(
                  idleTimeoutSeconds: v.round(),
                ),
              ),
              onChangeEnd: (v) =>
                  _update(_settings.copyWith(idleTimeoutSeconds: v.round())),
            ),
            const Divider(height: 32),
            Text(
              'Model: ${AppConfig.geminiLiveModel}\n'
              'Firebase project: ${AppConfig.firebaseProjectId}\n'
              'API key: ${_mask(AppConfig.firebaseApiKey)}\n'
              'App Check token: ${_mask(AppConfig.appCheckDebugToken)}',
              style: textTheme.bodySmall,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows only the ends of a secret, enough to spot a wrong value.
String _mask(String value) {
  if (value.length < 12) return value.isEmpty ? '(empty)' : '***';
  final start = value.substring(0, 6);
  final end = value.substring(value.length - 4);
  return '$start...$end (${value.length} chars)';
}
