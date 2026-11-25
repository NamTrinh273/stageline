import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/stageline_theme.dart';
import 'concert_hardware_controller.dart';

/// Ultra-lightweight OLED Concert Mode reader.
///
/// Features:
/// - True `#000000` OLED black background with anti-glare `#E2E2E6` text.
/// - Tap-to-Advance (bottom ~72% of lyrics body advances +1, top ~28% steps back -1)
///   while preserving free manual scrolling at all times.
/// - Quick Section Jump horizontal pill bar (`[V1]`, `[Pre]`, `[CHORUS]`, ...).
/// - Extra Dim overlay + hardware brightness unified slider.
/// - Safe WakeLock & brightness lifecycle cleanup on backgrounding and dispose.
class ConcertModeScreen extends StatefulWidget {
  const ConcertModeScreen({
    super.key,
    required this.setlist,
    this.initialSongIndex = 0,
    this.hardwareController = const DeviceConcertHardwareController(),
  });

  final Setlist setlist;
  final int initialSongIndex;
  final ConcertHardwareController hardwareController;

  @override
  State<ConcertModeScreen> createState() => _ConcertModeScreenState();
}

class _ConcertModeScreenState extends State<ConcertModeScreen>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  late final ValueNotifier<int> _songIndexNotifier;
  late final ValueNotifier<int> _activeLineNotifier;
  late final ValueNotifier<double> _fontSizeNotifier;

  /// Unified brightness slider:
  /// `1.0` = system default brightness & 0 dim overlay;
  /// `0.5` = minimum hardware brightness & 0 dim overlay;
  /// `0.0` = minimum hardware brightness & 0.75 Extra Dim black overlay.
  late final ValueNotifier<double> _lightLevelNotifier;
  late final ValueNotifier<bool> _showTranslationsNotifier;
  late final ValueNotifier<bool> _hudVisibleNotifier;
  late final ValueNotifier<bool> _portraitLockedNotifier;

  late List<FlatLyricEntry> _flatLines;
  late List<GlobalKey> _lineKeys;
  Timer? _hudAutoHideTimer;

  Song get _currentSong => widget.setlist.songs[_songIndexNotifier.value];

  double _computeDimAlpha(double lightLevel) {
    if (lightLevel >= 0.5) return 0.0;
    return ((0.5 - lightLevel) / 0.5 * 0.75).clamp(0.0, 0.75);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final safeSongIdx = widget.setlist.songs.isEmpty
        ? 0
        : widget.initialSongIndex.clamp(0, widget.setlist.songs.length - 1);

    _scrollController = ScrollController();
    _songIndexNotifier = ValueNotifier<int>(safeSongIdx);
    _activeLineNotifier = ValueNotifier<int>(0);
    _fontSizeNotifier = ValueNotifier<double>(24.0);
    _lightLevelNotifier = ValueNotifier<double>(1.0);
    _hudVisibleNotifier = ValueNotifier<bool>(true);
    _portraitLockedNotifier = ValueNotifier<bool>(false);

    _rebuildSongData();
    _showTranslationsNotifier = ValueNotifier<bool>(
      widget.setlist.songs.isNotEmpty && _currentSong.hasTranslations,
    );

    unawaited(widget.hardwareController.enableWakeLock());
    _scheduleHudAutoHide();
  }

  void _rebuildSongData() {
    if (widget.setlist.songs.isEmpty) {
      _flatLines = const [];
      _lineKeys = const [];
      return;
    }
    _flatLines = _currentSong.flattenLines();
    _lineKeys = List<GlobalKey>.generate(
      _flatLines.length,
      (_) => GlobalKey(),
      growable: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(widget.hardwareController.disableWakeLock());
      unawaited(widget.hardwareController.resetAppBrightness());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(widget.hardwareController.enableWakeLock());
      _applyHardwareBrightness(_lightLevelNotifier.value);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hudAutoHideTimer?.cancel();
    unawaited(widget.hardwareController.disableWakeLock());
    unawaited(widget.hardwareController.resetAppBrightness());
    unawaited(widget.hardwareController.lockPortrait(false));

    _scrollController.dispose();
    _songIndexNotifier.dispose();
    _activeLineNotifier.dispose();
    _fontSizeNotifier.dispose();
    _lightLevelNotifier.dispose();
    _showTranslationsNotifier.dispose();
    _hudVisibleNotifier.dispose();
    _portraitLockedNotifier.dispose();
    super.dispose();
  }

  void _scheduleHudAutoHide() {
    _hudAutoHideTimer?.cancel();
    _hudAutoHideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _hudVisibleNotifier.value = false;
      }
    });
  }

  void _toggleHud() {
    final next = !_hudVisibleNotifier.value;
    _hudVisibleNotifier.value = next;
    if (next) {
      _scheduleHudAutoHide();
    } else {
      _hudAutoHideTimer?.cancel();
    }
  }

  void _keepHudAlive() {
    if (_hudVisibleNotifier.value) {
      _scheduleHudAutoHide();
    }
  }

  void _applyHardwareBrightness(double lightLevel) {
    if (lightLevel >= 0.98) {
      unawaited(widget.hardwareController.resetAppBrightness());
    } else if (lightLevel >= 0.5) {
      // Map [0.5, 0.98] -> [0.04, 1.0]
      final normalized = (lightLevel - 0.5) / 0.48;
      unawaited(
        widget.hardwareController.setAppBrightness(0.04 + normalized * 0.96),
      );
    } else {
      // Pin hardware brightness near minimum while Extra Dim overlay takes over.
      unawaited(widget.hardwareController.setAppBrightness(0.02));
    }
  }

  void _setActiveLine(int targetIndex, {bool animate = true}) {
    if (_flatLines.isEmpty) return;
    final clamped = targetIndex.clamp(0, _flatLines.length - 1);
    _activeLineNotifier.value = clamped;

    final ctx = _lineKeys[clamped].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _stepLine(int delta) {
    if (_flatLines.isEmpty) return;
    _setActiveLine(_activeLineNotifier.value + delta);
  }

  void _jumpToSection(int sectionIndex) {
    if (widget.setlist.songs.isEmpty) return;
    final targetLine = _currentSong.firstLineIndexForSection(sectionIndex);
    _setActiveLine(targetLine);
  }

  void _switchSong(int delta) {
    if (widget.setlist.songs.length <= 1) return;
    final nextIdx = _songIndexNotifier.value + delta;
    if (nextIdx < 0 || nextIdx >= widget.setlist.songs.length) return;

    setState(() {
      _songIndexNotifier.value = nextIdx;
      _rebuildSongData();
      _activeLineNotifier.value = 0;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _keepHudAlive();
  }

  void _adjustFontSize(double delta) {
    _fontSizeNotifier.value = (_fontSizeNotifier.value + delta).clamp(
      18.0,
      38.0,
    );
    _keepHudAlive();
  }

  void _togglePortraitLock() {
    final next = !_portraitLockedNotifier.value;
    _portraitLockedNotifier.value = next;
    unawaited(widget.hardwareController.lockPortrait(next));
    _keepHudAlive();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.setlist.songs.isEmpty) {
      return Scaffold(
        backgroundColor: StageLineColors.background,
        appBar: AppBar(title: Text(widget.setlist.title)),
        body: const Center(
          child: Text(
            'Setlist chưa có bài hát nào.',
            style: TextStyle(color: StageLineColors.secondaryText),
          ),
        ),
      );
    }

    final songCount = widget.setlist.songs.length;
    final songIdx = _songIndexNotifier.value;
    final song = _currentSong;

    return Scaffold(
      backgroundColor: StageLineColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top ~10% slim header strip: swipe horizontally to switch song, tap to toggle HUD.
                _ConcertHeaderStrip(
                  songTitle: song.title,
                  songPositionLabel: '${songIdx + 1}/$songCount',
                  canPrev: songIdx > 0,
                  canNext: songIdx < songCount - 1,
                  onBack: () => Navigator.of(context).pop(),
                  onPrevSong: () => _switchSong(-1),
                  onNextSong: () => _switchSong(1),
                  onToggleHud: _toggleHud,
                ),

                // Expandable HUD control bar (auto-hides after 3.5s).
                ValueListenableBuilder<bool>(
                  valueListenable: _hudVisibleNotifier,
                  builder: (context, visible, _) {
                    if (!visible) return const SizedBox.shrink();
                    return _ConcertHudBar(
                      fontSizeListenable: _fontSizeNotifier,
                      lightLevelListenable: _lightLevelNotifier,
                      showTranslationsListenable: _showTranslationsNotifier,
                      portraitLockedListenable: _portraitLockedNotifier,
                      hasTranslations: song.hasTranslations,
                      onDecreaseFont: () => _adjustFontSize(-2),
                      onIncreaseFont: () => _adjustFontSize(2),
                      onToggleTranslations: () {
                        _showTranslationsNotifier.value =
                            !_showTranslationsNotifier.value;
                        _keepHudAlive();
                      },
                      onLightChanged: (value) {
                        _lightLevelNotifier.value = value;
                        _applyHardwareBrightness(value);
                        _keepHudAlive();
                      },
                      onTogglePortraitLock: _togglePortraitLock,
                    );
                  },
                ),

                // Main Lyrics Area: Free Scroll + Tap-to-Advance (bottom ~72% +1, top ~28% -1).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bodyHeight = constraints.maxHeight;
                      return GestureDetector(
                        key: const ValueKey('concert_tap_zone'),
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final yRatio = bodyHeight <= 0
                              ? 0.5
                              : details.localPosition.dy / bodyHeight;
                          if (yRatio < 0.28) {
                            _stepLine(-1);
                          } else {
                            _stepLine(1);
                          }
                        },
                        child: _flatLines.isEmpty
                            ? const Center(
                                child: Text(
                                  'Bài hát chưa có lời.',
                                  style: TextStyle(
                                    color: StageLineColors.secondaryText,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  180,
                                ),
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _fontSizeNotifier,
                                  builder: (context, fontSize, _) {
                                    return ValueListenableBuilder<bool>(
                                      valueListenable:
                                          _showTranslationsNotifier,
                                      builder: (context, showTranslations, _) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < _flatLines.length;
                                              i++
                                            )
                                              _ConcertLineTile(
                                                key: _lineKeys[i],
                                                entry: _flatLines[i],
                                                activeLineListenable:
                                                    _activeLineNotifier,
                                                fontSize: fontSize,
                                                showTranslations:
                                                    showTranslations,
                                              ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                      );
                    },
                  ),
                ),

                // Quick Section Jump pill bar pinned at bottom.
                if (song.sections.isNotEmpty)
                  _QuickSectionJumpBar(
                    sections: song.sections,
                    flatLines: _flatLines,
                    activeLineListenable: _activeLineNotifier,
                    onJumpToSection: _jumpToSection,
                  ),
              ],
            ),
          ),

          // Extra Dim Overlay (IgnorePointer so gestures pass straight through).
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _lightLevelNotifier,
                builder: (context, lightLevel, _) {
                  final alpha = _computeDimAlpha(lightLevel);
                  return ColoredBox(
                    key: const ValueKey('extra_dim_overlay'),
                    color: Colors.black.withValues(alpha: alpha),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertHeaderStrip extends StatelessWidget {
  const _ConcertHeaderStrip({
    required this.songTitle,
    required this.songPositionLabel,
    required this.canPrev,
    required this.canNext,
    required this.onBack,
    required this.onPrevSong,
    required this.onNextSong,
    required this.onToggleHud,
  });

  final String songTitle;
  final String songPositionLabel;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onBack;
  final VoidCallback onPrevSong;
  final VoidCallback onNextSong;
  final VoidCallback onToggleHud;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('concert_header_strip'),
      behavior: HitTestBehavior.opaque,
      onTap: onToggleHud,
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0;
        if (vx < -180 && canNext) {
          onNextSong();
        } else if (vx > 180 && canPrev) {
          onPrevSong();
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: const BoxDecoration(
          color: StageLineColors.background,
          border: Border(bottom: BorderSide(color: Color(0xFF14141A))),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              color: StageLineColors.secondaryText,
              onPressed: onBack,
              tooltip: 'Thoát Concert Mode',
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StageLineColors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Bài $songPositionLabel • Chạm để ẩn/hiện chỉnh nhanh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StageLineColors.translationText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('concert_prev_song_btn'),
              icon: const Icon(Icons.chevron_left, size: 22),
              color: canPrev
                  ? StageLineColors.primaryText
                  : const Color(0xFF2C2C34),
              onPressed: canPrev ? onPrevSong : null,
              tooltip: 'Bài trước',
            ),
            IconButton(
              key: const ValueKey('concert_next_song_btn'),
              icon: const Icon(Icons.chevron_right, size: 22),
              color: canNext
                  ? StageLineColors.primaryText
                  : const Color(0xFF2C2C34),
              onPressed: canNext ? onNextSong : null,
              tooltip: 'Bài tiếp theo',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcertHudBar extends StatelessWidget {
  const _ConcertHudBar({
    required this.fontSizeListenable,
    required this.lightLevelListenable,
    required this.showTranslationsListenable,
    required this.portraitLockedListenable,
    required this.hasTranslations,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onToggleTranslations,
    required this.onLightChanged,
    required this.onTogglePortraitLock,
  });

  final ValueNotifier<double> fontSizeListenable;
  final ValueNotifier<double> lightLevelListenable;
  final ValueNotifier<bool> showTranslationsListenable;
  final ValueNotifier<bool> portraitLockedListenable;
  final bool hasTranslations;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;
  final VoidCallback onToggleTranslations;
  final ValueChanged<double> onLightChanged;
  final VoidCallback onTogglePortraitLock;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('concert_hud_bar'),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: const BoxDecoration(
        color: StageLineColors.surface,
        border: Border(bottom: BorderSide(color: StageLineColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Font size buttons
              _HudChipButton(
                key: const ValueKey('hud_font_minus'),
                label: 'A-',
                onTap: onDecreaseFont,
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<double>(
                valueListenable: fontSizeListenable,
                builder: (context, size, _) => Text(
                  '${size.round()}',
                  style: const TextStyle(
                    color: StageLineColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _HudChipButton(
                key: const ValueKey('hud_font_plus'),
                label: 'A+',
                onTap: onIncreaseFont,
              ),
              const Spacer(),
              // Translation toggle
              ValueListenableBuilder<bool>(
                valueListenable: showTranslationsListenable,
                builder: (context, showTr, _) {
                  return _HudChipButton(
                    key: const ValueKey('hud_toggle_tr'),
                    label: showTr ? 'Dịch: Bật' : 'Dịch: Tắt',
                    active: showTr && hasTranslations,
                    onTap: onToggleTranslations,
                  );
                },
              ),
              const SizedBox(width: 6),
              // Portrait lock toggle
              ValueListenableBuilder<bool>(
                valueListenable: portraitLockedListenable,
                builder: (context, locked, _) {
                  return _HudChipButton(
                    key: const ValueKey('hud_lock_orientation'),
                    label: locked ? 'Khóa dọc' : 'Tự xoay',
                    active: locked,
                    onTap: onTogglePortraitLock,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.brightness_2_outlined,
                size: 16,
                color: StageLineColors.secondaryText,
              ),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: lightLevelListenable,
                  builder: (context, level, _) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        key: const ValueKey('hud_dim_slider'),
                        value: level,
                        min: 0.0,
                        max: 1.0,
                        activeColor: StageLineColors.singAlongGold,
                        inactiveColor: StageLineColors.border,
                        onChanged: onLightChanged,
                      ),
                    );
                  },
                ),
              ),
              const Icon(
                Icons.brightness_high,
                size: 16,
                color: StageLineColors.secondaryText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudChipButton extends StatelessWidget {
  const _HudChipButton({
    super.key,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? StageLineColors.singAlongSurface
              : StageLineColors.activeSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? StageLineColors.singAlongGold
                : StageLineColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? StageLineColors.singAlongGold
                : StageLineColors.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConcertLineTile extends StatelessWidget {
  const _ConcertLineTile({
    super.key,
    required this.entry,
    required this.activeLineListenable,
    required this.fontSize,
    required this.showTranslations,
  });

  final FlatLyricEntry entry;
  final ValueNotifier<int> activeLineListenable;
  final double fontSize;
  final bool showTranslations;

  @override
  Widget build(BuildContext context) {
    final isSingAlong = entry.section.singAlong;

    return ValueListenableBuilder<int>(
      valueListenable: activeLineListenable,
      builder: (context, activeIndex, _) {
        final isActive = activeIndex == entry.flatIndex;
        final textColor = isActive
            ? (isSingAlong
                  ? StageLineColors.singAlongGold
                  : StageLineColors.primaryText)
            : (isSingAlong
                  ? const Color(0xFFB3954D)
                  : StageLineColors.secondaryText);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (entry.isSectionStart)
              Padding(
                padding: EdgeInsets.only(
                  top: entry.flatIndex == 0 ? 4 : 22,
                  bottom: 6,
                ),
                child: Row(
                  children: [
                    if (isSingAlong)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: StageLineColors.singAlongGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      entry.section.tag.toUpperCase(),
                      style: TextStyle(
                        color: isSingAlong
                            ? StageLineColors.singAlongGold
                            : StageLineColors.translationText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              key: ValueKey('lyric_line_${entry.flatIndex}'),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? (isSingAlong
                          ? StageLineColors.singAlongSurface
                          : StageLineColors.activeSurface)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSingAlong
                    ? const Border(
                        left: BorderSide(
                          color: StageLineColors.singAlongGold,
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.line.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      height: 1.32,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  if (showTranslations && entry.line.hasTranslation)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entry.line.translation!,
                        style: TextStyle(
                          color: isActive
                              ? StageLineColors.secondaryText
                              : StageLineColors.translationText,
                          fontSize: fontSize * 0.72,
                          height: 1.25,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickSectionJumpBar extends StatelessWidget {
  const _QuickSectionJumpBar({
    required this.sections,
    required this.flatLines,
    required this.activeLineListenable,
    required this.onJumpToSection,
  });

  final List<LyricSection> sections;
  final List<FlatLyricEntry> flatLines;
  final ValueNotifier<int> activeLineListenable;
  final ValueChanged<int> onJumpToSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: StageLineColors.background,
        border: Border(top: BorderSide(color: Color(0xFF1A1A22))),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: activeLineListenable,
        builder: (context, activeLineIdx, _) {
          final activeSectionIdx =
              flatLines.isNotEmpty && activeLineIdx < flatLines.length
              ? flatLines[activeLineIdx].sectionIndex
              : 0;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final section = sections[idx];
              final isCurrent = idx == activeSectionIdx;
              final isSingAlong = section.singAlong;

              final bgColor = isCurrent
                  ? (isSingAlong
                        ? StageLineColors.singAlongGold
                        : StageLineColors.primaryText)
                  : StageLineColors.surface;

              final fgColor = isCurrent
                  ? StageLineColors.background
                  : (isSingAlong
                        ? StageLineColors.singAlongGold
                        : StageLineColors.secondaryText);

              final borderColor = isSingAlong
                  ? StageLineColors.singAlongGold
                  : (isCurrent
                        ? StageLineColors.primaryText
                        : StageLineColors.border);

              return InkWell(
                key: ValueKey('section_pill_$idx'),
                onTap: () => onJumpToSection(idx),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    section.shortLabel,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
