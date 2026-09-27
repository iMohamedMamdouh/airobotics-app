import 'package:flutter/material.dart';

import '../config/horus_persona.dart';
import '../services/horus_controller.dart';
import '../theme.dart';
import '../widgets/horus_face.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final HorusController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _textFocus = FocusNode();
  bool _showKeyboard = false;

  HorusController get _c => widget.controller;

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text;
    _textController.clear();
    setState(() => _showKeyboard = false);
    _textFocus.unfocus();
    _c.sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF0A2A4F), HorusColors.background],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final face = GestureDetector(
                  onTap:
                      _c.state == HorusState.speaking ||
                          _c.state == HorusState.thinking
                      ? _c.interrupt
                      : null,
                  child: HorusFace(state: _c.state, micLevel: _c.micLevel),
                );
                final panel = _ConversationPanel(controller: _c);

                return Column(
                  children: [
                    _Header(
                      onOpenSettings: () => showSettingsSheet(context, _c),
                    ),
                    Expanded(
                      child: landscape
                          ? Row(
                              children: [
                                Expanded(flex: 5, child: face),
                                Expanded(flex: 6, child: panel),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(flex: 5, child: face),
                                Expanded(flex: 4, child: panel),
                              ],
                            ),
                    ),
                    _Controls(
                      controller: _c,
                      showKeyboard: _showKeyboard,
                      textController: _textController,
                      textFocus: _textFocus,
                      onToggleKeyboard: () {
                        setState(() => _showKeyboard = !_showKeyboard);
                        if (_showKeyboard) _textFocus.requestFocus();
                      },
                      onSubmitText: _submitText,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          // Hidden settings: long-press the logo.
          GestureDetector(
            onLongPress: onOpenSettings,
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset('assets/images/airobotics_logo_cropped.png'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HorusPersona.robotName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                Text(
                  'الروبوت الذكي من ${HorusPersona.companyName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HorusColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({required this.controller});

  final HorusController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final textTheme = Theme.of(context).textTheme;

    Widget body;
    if (c.state == HorusState.idle) {
      body = FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أهلاً! أنا حورس 👋',
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الروبوت الذكي من شركة ${HorusPersona.companyName}.\nاضغط على الميكروفون واسألني أي حاجة.',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: HorusColors.textMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    } else if (c.state == HorusState.error) {
      body = SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.errorMessage ?? 'حصلت مشكلة.',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(color: HorusColors.error),
            ),
            if (c.errorDetail != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                c.errorDetail!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: textTheme.bodySmall?.copyWith(
                  color: HorusColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      body = SingleChildScrollView(
        reverse: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.userText.isNotEmpty)
              Text(
                c.userText.trim(),
                style: textTheme.titleLarge?.copyWith(
                  color: HorusColors.textMuted,
                ),
              ),
            if (c.userText.isNotEmpty && c.horusText.isNotEmpty)
              const SizedBox(height: 16),
            if (c.horusText.isNotEmpty)
              Text(
                c.horusText.trim(),
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        children: [
          _StatusChip(state: c.state),
          const SizedBox(height: 16),
          Expanded(child: Center(child: body)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final HorusState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      HorusState.idle => ('جاهز', HorusColors.sky),
      HorusState.connecting => ('بيتصل...', HorusColors.sky),
      HorusState.listening => ('سامعك... اتكلم', HorusColors.listening),
      HorusState.thinking => ('بيفكر...', HorusColors.thinking),
      HorusState.speaking => (
        'حورس بيتكلم (المس الوش علشان يسكت)',
        HorusColors.gold,
      ),
      HorusState.error => ('فيه مشكلة', HorusColors.error),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.showKeyboard,
    required this.textController,
    required this.textFocus,
    required this.onToggleKeyboard,
    required this.onSubmitText,
  });

  final HorusController controller;
  final bool showKeyboard;
  final TextEditingController textController;
  final FocusNode textFocus;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onSubmitText;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final active = c.isActive;
    final busy = c.state == HorusState.connecting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showKeyboard)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: textController,
                focusNode: textFocus,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmitText(),
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك هنا...',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: HorusColors.sky,
                    ),
                    onPressed: onSubmitText,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
                size: 64,
                color: Colors.white.withValues(alpha: 0.12),
                onPressed: onToggleKeyboard,
                tooltip: 'اكتب سؤال',
              ),
              const SizedBox(width: 32),
              _RoundButton(
                icon: active ? Icons.stop_rounded : Icons.mic_rounded,
                size: 112,
                color: active ? HorusColors.error : HorusColors.sky,
                onPressed: busy ? null : (active ? c.stop : c.start),
                tooltip: active ? 'إنهاء المحادثة' : 'ابدأ الكلام',
                glow: !active,
              ),
              const SizedBox(width: 96),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active ? 'اضغط علشان تنهي المحادثة' : 'اضغط واتكلم',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: HorusColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    this.glow = false,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: onPressed == null ? color.withValues(alpha: 0.4) : color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: size * 0.5, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
