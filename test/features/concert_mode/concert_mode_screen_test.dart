import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stageline/core/theme/stageline_theme.dart';
import 'package:stageline/features/concert_mode/concert_hardware_controller.dart';
import 'package:stageline/features/concert_mode/concert_mode_screen.dart';
import 'package:stageline/features/setlists/demo_setlist_seed.dart';

class FakeConcertHardwareController implements ConcertHardwareController {
  int enableWakeLockCalls = 0;
  int disableWakeLockCalls = 0;
  int resetBrightnessCalls = 0;
  double? lastBrightness;
  bool portraitLocked = false;

  @override
  Future<void> enableWakeLock() async {
    enableWakeLockCalls++;
  }

  @override
  Future<void> disableWakeLock() async {
    disableWakeLockCalls++;
  }

  @override
  Future<void> setAppBrightness(double brightness) async {
    lastBrightness = brightness;
  }

  @override
  Future<void> resetAppBrightness() async {
    resetBrightnessCalls++;
  }

  @override
  Future<void> lockPortrait(bool locked) async {
    portraitLocked = locked;
  }
}

void main() {
  group('ConcertModeScreen', () {
    testWidgets(
      'uses true OLED black, Tap-to-Advance, Quick Section Jump, and lifecycle cleanup',
      (tester) async {
        final hardware = FakeConcertHardwareController();
        final demo = buildDemoSetlist();

        await tester.pumpWidget(
          MaterialApp(
            theme: StageLineTheme.buildDarkTheme(),
            home: ConcertModeScreen(
              setlist: demo,
              hardwareController: hardware,
            ),
          ),
        );
        await tester.pump();

        // Verify true OLED black background and WakeLock enabled on enter.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, StageLineColors.background);
        expect(hardware.enableWakeLockCalls, 1);

        // Line 0 is active initially.
        Container lineContainer(int idx) =>
            tester.widget<Container>(find.byKey(ValueKey('lyric_line_$idx')));

        expect(
          (lineContainer(0).decoration! as BoxDecoration).color,
          StageLineColors.activeSurface,
        );

        // Tap bottom 65% of lyrics area -> advances active line 0 -> 1.
        final tapZoneRect = tester.getRect(
          find.byKey(const ValueKey('concert_tap_zone')),
        );
        await tester.tapAt(
          Offset(
            tapZoneRect.center.dx,
            tapZoneRect.top + tapZoneRect.height * 0.75,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          (lineContainer(1).decoration! as BoxDecoration).color,
          StageLineColors.activeSurface,
        );

        // Tap top 25% of lyrics area -> steps back active line 1 -> 0.
        await tester.tapAt(
          Offset(
            tapZoneRect.center.dx,
            tapZoneRect.top + tapZoneRect.height * 0.12,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          (lineContainer(0).decoration! as BoxDecoration).color,
          StageLineColors.activeSurface,
        );

        // Quick Section Jump to Chorus (index 2 -> line index 5).
        await tester.tap(find.byKey(const ValueKey('section_pill_2')));
        await tester.pumpAndSettle();

        expect(
          (lineContainer(5).decoration! as BoxDecoration).color,
          StageLineColors.singAlongSurface,
        );

        // Switch to Song 2 (US-UK bilingual with translations).
        await tester.tap(find.byKey(const ValueKey('concert_next_song_btn')));
        await tester.pumpAndSettle();

        expect(find.text('City Under Stars (Demo US-UK)'), findsOneWidget);
        // Reveal HUD if auto-hidden, then toggle translations on/off.
        if (find.byKey(const ValueKey('concert_hud_bar')).evaluate().isEmpty) {
          await tester.tap(find.byKey(const ValueKey('concert_header_strip')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('hud_toggle_tr')));
        await tester.pump();
        expect(
          find.text('Ta lái xe suốt đêm chỉ để đứng nơi đây'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('hud_toggle_tr')));
        await tester.pump();
        expect(
          find.text('Ta lái xe suốt đêm chỉ để đứng nơi đây'),
          findsNothing,
        );

        // Slide Extra Dim slider to minimum -> dim overlay alpha ramps up & brightness lowers.
        final sliderFinder = find.byKey(const ValueKey('hud_dim_slider'));
        final sliderRect = tester.getRect(sliderFinder);
        await tester.tapAt(Offset(sliderRect.left + 2, sliderRect.center.dy));
        await tester.pump();

        final dimBox = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('extra_dim_overlay')),
        );
        expect(dimBox.color.a, greaterThan(0.6));
        expect(hardware.lastBrightness, lessThanOrEqualTo(0.05));

        // Verify lifecycle pause releases WakeLock and resets brightness, then resume re-enables.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(hardware.disableWakeLockCalls, 1);
        expect(hardware.resetBrightnessCalls, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(hardware.enableWakeLockCalls, 2);

        // Dispose cleans up timer, WakeLock, and brightness.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(hardware.disableWakeLockCalls, 2);
        expect(hardware.resetBrightnessCalls, 2);
      },
    );
  });
}
