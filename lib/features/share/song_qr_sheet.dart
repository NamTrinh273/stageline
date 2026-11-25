import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/models.dart';
import '../../core/parser/parser.dart';
import '../../core/theme/stageline_theme.dart';

/// Opens a dark OLED modal bottom sheet showing an offline QR code for [song].
///
/// If [song] exceeds [QrSongCodec.maxEncodedChars], the sheet explains the
/// capacity limit and displays a fallback action invoking
/// [onExportSetlistFallback].
Future<void> showSongQrSheet(
  BuildContext context, {
  required Song song,
  VoidCallback? onExportSetlistFallback,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: StageLineColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: StageLineColors.border),
    ),
    builder: (sheetContext) {
      return SongQrSheet(
        song: song,
        onExportSetlistFallback: onExportSetlistFallback == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onExportSetlistFallback();
              },
      );
    },
  );
}

/// Bottom-sheet body that renders a single-song offline QR payload (`SL1:`)
/// or a `.concert` export fallback warning when the song exceeds QR capacity.
class SongQrSheet extends StatelessWidget {
  const SongQrSheet({
    super.key,
    required this.song,
    this.onExportSetlistFallback,
    this.codec = const QrSongCodec(),
  });

  final Song song;
  final VoidCallback? onExportSetlistFallback;
  final QrSongCodec codec;

  @override
  Widget build(BuildContext context) {
    String? payload;
    QrPayloadTooLargeException? tooLargeError;

    try {
      payload = codec.encode(song);
    } on QrPayloadTooLargeException catch (e) {
      tooLargeError = e;
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StageLineColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: StageLineColors.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.artist != null && song.artist!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          song.artist!,
                          style: const TextStyle(
                            color: StageLineColors.secondaryText,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close,
                    color: StageLineColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (payload != null)
              _buildQrContent(payload)
            else if (tooLargeError != null)
              _buildTooLargeWarning(tooLargeError),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent(String payload) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
              child: QrImageView(
                key: const ValueKey('song_qr_image'),
                data: payload,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
                gapless: true,
                semanticsLabel: 'Mã QR bài hát ${song.title}',
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: StageLineColors.activeSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: StageLineColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 16,
                color: StageLineColors.singAlongGold,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${payload.length} / ${QrSongCodec.maxEncodedChars} ký tự • Quét 100% offline',
                  style: const TextStyle(
                    color: StageLineColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Mở máy quét trong StageLine trên điện thoại khác để nhận ngay lời bài hát không cần mạng.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StageLineColors.secondaryText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTooLargeWarning(QrPayloadTooLargeException error) {
    return Container(
      key: const ValueKey('song_qr_too_large'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StageLineColors.activeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StageLineColors.singAlongGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: StageLineColors.singAlongGold,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bài hát vượt giới hạn mã QR',
                  style: TextStyle(
                    color: StageLineColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Dữ liệu nén của bài hát dài ${error.encodedLength} ký tự '
            '(giới hạn an toàn để quét trong đêm diễn là ${error.maxLength} ký tự). '
            'Hãy xuất và chia sẻ dưới dạng tệp .concert để đảm bảo đầy đủ lời bài hát.',
            style: const TextStyle(
              color: StageLineColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (onExportSetlistFallback != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('song_qr_fallback_btn'),
              onPressed: onExportSetlistFallback,
              style: FilledButton.styleFrom(
                backgroundColor: StageLineColors.singAlongGold,
                foregroundColor: StageLineColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.ios_share),
              label: const Text(
                'Xuất tệp .concert thay thế',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
