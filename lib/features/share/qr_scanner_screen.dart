import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/models.dart';
import '../../core/parser/parser.dart';
import '../../core/theme/stageline_theme.dart';

/// Full-screen dark OLED QR scanner for importing a single StageLine [Song].
///
/// Pops with the decoded [Song] via `Navigator.of(context).pop(song)` on the
/// first valid StageLine QR payload (`SL1:`), or `null` if cancelled.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.codec = const QrSongCodec()});

  final QrSongCodec codec;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _hasCompleted = false;
  String? _statusError;
  Timer? _statusClearTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasCompleted) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_controller.value.isRunning) {
          unawaited(_controller.stop().catchError((Object _) {}));
        }
      case AppLifecycleState.resumed:
        if (_controller.value.isInitialized &&
            !_controller.value.isRunning &&
            !_controller.value.isStarting) {
          unawaited(_controller.start().catchError((Object _) {}));
        }
    }
  }

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasCompleted || !mounted) return;

    var sawNonEmptyCode = false;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) {
        continue;
      }
      sawNonEmptyCode = true;

      try {
        final song = widget.codec.decode(rawValue);
        _hasCompleted = true;
        _statusClearTimer?.cancel();
        unawaited(_controller.stop().catchError((Object _) {}));
        Navigator.of(context).pop<Song>(song);
        return;
      } on ConcertFormatException {
        // Continue checking remaining barcodes in this frame.
      } on FormatException {
        // Continue checking remaining barcodes in this frame.
      }
    }

    if (sawNonEmptyCode) {
      _showTemporaryStatusError('Không phải mã QR bài hát StageLine');
    }
  }

  void _showTemporaryStatusError(String message) {
    _statusClearTimer?.cancel();
    if (_statusError != message && mounted) {
      setState(() {
        _statusError = message;
      });
    }
    _statusClearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_hasCompleted) {
        setState(() {
          _statusError = null;
        });
      }
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on Object {
      // Ignore if camera is uninitialized or torch is unavailable.
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } on Object {
      // Ignore if camera is uninitialized or only one camera exists.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StageLineColors.background,
      appBar: AppBar(
        backgroundColor: StageLineColors.background,
        foregroundColor: StageLineColors.primaryText,
        title: const Text(
          'Quét QR bài hát',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              final torchAvailable =
                  state.isRunning && state.torchState != TorchState.unavailable;
              return IconButton(
                tooltip: torchOn ? 'Tắt đèn flash' : 'Bật đèn flash',
                onPressed: torchAvailable ? _toggleTorch : null,
                icon: Icon(
                  torchOn ? Icons.flash_on : Icons.flash_off,
                  color: torchOn
                      ? StageLineColors.singAlongGold
                      : StageLineColors.primaryText,
                ),
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final canSwitch =
                  state.isRunning &&
                  (state.availableCameras == null ||
                      state.availableCameras! > 1);
              return IconButton(
                tooltip: 'Đổi camera',
                onPressed: canSwitch ? _switchCamera : null,
                icon: const Icon(
                  Icons.cameraswitch_outlined,
                  color: StageLineColors.primaryText,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return _ScannerErrorView(error: error);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _statusError == null
                        ? StageLineColors.singAlongGold
                        : StageLineColors.danger,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: StageLineColors.activeSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _statusError == null
                          ? StageLineColors.border
                          : StageLineColors.danger,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusError == null
                            ? Icons.qr_code_scanner
                            : Icons.error_outline,
                        size: 18,
                        color: _statusError == null
                            ? StageLineColors.singAlongGold
                            : StageLineColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusError ?? 'Đưa mã QR StageLine vào khung giữa',
                          style: TextStyle(
                            color: _statusError == null
                                ? StageLineColors.primaryText
                                : StageLineColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: StageLineColors.background,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            size: 48,
            color: StageLineColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            isDenied
                ? 'Chưa cấp quyền truy cập camera'
                : 'Không thể khởi động camera',
            style: const TextStyle(
              color: StageLineColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isDenied
                ? 'Hãy bật quyền Camera cho StageLine trong cài đặt thiết bị để quét mã QR.'
                : (error.errorDetails?.message ??
                      'Thiết bị không hỗ trợ camera hoặc camera đang được ứng dụng khác sử dụng.'),
            style: const TextStyle(
              color: StageLineColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
