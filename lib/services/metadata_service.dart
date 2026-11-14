import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../models/nami_models.dart';
import '../utils/nami_helpers.dart';

class NamiMetadataService {
  static String sanitizeMetadataText(String input) {
    return input
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<LyricLine> parseLrc(String raw) {
    final List<LyricLine> lines = [];
    final lineReg = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)');
    final sylReg = RegExp(r'<(\d+):(\d+(?:\.\d+)?)>([^<]+)');

    for (final rawLine in raw.split('\n')) {
      final match = lineReg.firstMatch(rawLine.trim());
      if (match != null) {
        final mins = int.tryParse(match.group(1)!) ?? 0;
        final secs = double.tryParse(match.group(2)!) ?? 0.0;
        var text = match.group(3)?.trim() ?? '';
        final lineTime = Duration(milliseconds: (mins * 60000 + secs * 1000).round());

        final List<SyllableToken> syllables = [];
        final sylMatches = sylReg.allMatches(text).toList();
        if (sylMatches.isNotEmpty) {
          for (final sm in sylMatches) {
            final sMins = int.tryParse(sm.group(1)!) ?? 0;
            final sSecs = double.tryParse(sm.group(2)!) ?? 0.0;
            final sText = sm.group(3) ?? '';
            syllables.add(SyllableToken(
              timestamp: Duration(milliseconds: (sMins * 60000 + sSecs * 1000).round()),
              text: sText,
            ));
          }
          text = text.replaceAll(RegExp(r'<\d+:\d+(?:\.\d+)?>'), '').trim();
        }

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: lineTime,
            text: text,
            syllables: syllables,
          ));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static Future<void> extractAudioMetadataUniversal(
    AudioTrack track,
    Directory thumbDir, {
    VoidCallback? onArtworkUpdated,
  }) async {
    try {
      final file = File(track.path);
      if (!await file.exists()) return;
      track.fileSize = await file.length();

      final thumbFile = File('${thumbDir.path}/${namiDeterministicPathHash(track.path)}.jpg');
      if (await thumbFile.exists()) {
        final bytes = await thumbFile.readAsBytes();
        if (namiLooksLikeImage(bytes)) {
          track.thumbPath = thumbFile.path;
          track.albumArt = bytes;
        }
      }

      // Check folder cover images if still missing
      if (track.albumArt == null) {
        final parent = file.parent;
        for (final name in ['cover.jpg', 'cover.png', 'folder.jpg', 'album.jpg', 'front.jpg']) {
          final f = File('${parent.path}/$name');
          if (await f.exists()) {
            final b = await f.readAsBytes();
            if (namiLooksLikeImage(b)) {
              await thumbFile.writeAsBytes(b);
              track.thumbPath = thumbFile.path;
              track.albumArt = b;
              onArtworkUpdated?.call();
              break;
            }
          }
        }
      }

      // Read header bytes for FLAC/ID3v2 tags & embedded artwork
      final raf = await file.open(mode: FileMode.read);
      try {
        final maxRead = track.fileSize < 384 * 1024 ? track.fileSize : 384 * 1024;
        final header = await raf.read(maxRead);

        if (header.length >= 42 &&
            header[0] == 0x66 &&
            header[1] == 0x4C &&
            header[2] == 0x61 &&
            header[3] == 0x43) {
          _parseFlacBlocks(header, track, thumbFile, onArtworkUpdated);
        } else if (header.length >= 10 &&
            header[0] == 0x49 &&
            header[1] == 0x44 &&
            header[2] == 0x33) {
          _parseId3v2(header, track, thumbFile, onArtworkUpdated);
        }
      } finally {
        await raf.close();
      }
      track.isMetadataLoaded = true;
    } catch (_) {
      track.isMetadataLoaded = true;
    }
  }

  static void _parseFlacBlocks(
    Uint8List data,
    AudioTrack track,
    File thumbFile,
    VoidCallback? onArtworkUpdated,
  ) {
    int offset = 4;
    bool isLast = false;
    while (!isLast && offset + 4 <= data.length) {
      final headerByte = data[offset];
      isLast = (headerByte & 0x80) != 0;
      final blockType = headerByte & 0x7F;
      final length = (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
      offset += 4;
      if (offset + length > data.length) break;

      if (blockType == 0 && length >= 34) {
        // STREAMINFO
        final sr = (data[offset + 10] << 12) | (data[offset + 11] << 4) | ((data[offset + 12] & 0xF0) >> 4);
        final bps = (((data[offset + 12] & 0x01) << 4) | ((data[offset + 13] & 0xF0) >> 4)) + 1;
        final totalSamples = ((data[offset + 13] & 0x0F) << 32) |
            (data[offset + 14] << 24) |
            (data[offset + 15] << 16) |
            (data[offset + 16] << 8) |
            data[offset + 17];
        if (sr > 0) track.sampleRateHz = sr;
        if (bps > 0) track.bitDepth = bps;
        if (sr > 0 && totalSamples > 0) {
          final secs = totalSamples ~/ sr;
          if (secs > 0) {
            track.duration = Duration(seconds: secs);
            if (track.fileSize > 0) {
              track.bitrateKbps = ((track.fileSize * 8) ~/ 1000) ~/ secs;
            }
          }
        }
      } else if (blockType == 4) {
        // VORBIS_COMMENT
        try {
          int p = offset;
          if (p + 4 <= offset + length) {
            final vendorLen = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
            p += 4 + vendorLen;
            if (p + 4 <= offset + length) {
              final count = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
              p += 4;
              for (int i = 0; i < count && p + 4 <= offset + length; i++) {
                final cLen = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
                p += 4;
                if (p + cLen > offset + length) break;
                final str = utf8.decode(data.sublist(p, p + cLen), allowMalformed: true);
                p += cLen;
                final eq = str.indexOf('=');
                if (eq > 0) {
                  final k = str.substring(0, eq).toUpperCase().trim();
                  final v = sanitizeMetadataText(str.substring(eq + 1));
                  if (v.isNotEmpty) {
                    if (k == 'TITLE') track.title = v;
                    if (k == 'ARTIST') track.artist = v;
                    if (k == 'ALBUM') track.album = v;
                    if (k == 'GENRE') track.genre = v;
                    if (k == 'DATE' || k == 'YEAR') track.year = v;
                  }
                }
              }
            }
          }
        } catch (_) {}
      } else if (blockType == 6 && track.albumArt == null) {
        // PICTURE
        try {
          int p = offset + 4;
          final mimeLen = (data[p] << 24) | (data[p + 1] << 16) | (data[p + 2] << 8) | data[p + 3];
          p += 4 + mimeLen;
          final descLen = (data[p] << 24) | (data[p + 1] << 16) | (data[p + 2] << 8) | data[p + 3];
          p += 4 + descLen + 16;
          final picLen = (data[p] << 24) | (data[p + 1] << 16) | (data[p + 2] << 8) | data[p + 3];
          p += 4;
          if (p + picLen <= offset + length && picLen > 256) {
            final picBytes = data.sublist(p, p + picLen);
            if (namiLooksLikeImage(picBytes)) {
              track.albumArt = picBytes;
              track.thumbPath = thumbFile.path;
              thumbFile.writeAsBytesSync(picBytes);
              onArtworkUpdated?.call();
            }
          }
        } catch (_) {}
      }
      offset += length;
    }
  }

  static void _parseId3v2(
    Uint8List data,
    AudioTrack track,
    File thumbFile,
    VoidCallback? onArtworkUpdated,
  ) {
    if (track.albumArt != null) return;
    // Scan for embedded JPEG (FF D8 FF) inside ID3 APIC frame
    for (int i = 10; i + 512 < data.length; i++) {
      if (data[i] == 0x41 && data[i + 1] == 0x50 && data[i + 2] == 0x49 && data[i + 3] == 0x43) {
        final frameSize = (data[i + 4] << 24) | (data[i + 5] << 16) | (data[i + 6] << 8) | data[i + 7];
        final end = (i + 10 + frameSize).clamp(0, data.length);
        for (int j = i + 10; j + 4 < end; j++) {
          if (data[j] == 0xFF && data[j + 1] == 0xD8 && data[j + 2] == 0xFF) {
            final picBytes = data.sublist(j, end);
            if (namiLooksLikeImage(picBytes)) {
              track.albumArt = picBytes;
              track.thumbPath = thumbFile.path;
              try {
                thumbFile.writeAsBytesSync(picBytes);
              } catch (_) {}
              onArtworkUpdated?.call();
              return;
            }
          }
        }
      }
    }
  }

  static Future<void> enrichTrackOnlineIfMissing(
    AudioTrack track,
    Directory thumbDir, {
    bool force = false,
    VoidCallback? onArtworkUpdated,
  }) async {
    if (!force && track.isOnlineEnriched && track.albumArt != null) return;
    final cleanTitle = sanitizeMetadataText(
      track.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]|\b(?:official|video|audio|lyrics|hd|hq|flac)\b', caseSensitive: false), ''),
    );
    final query = track.artist != 'Unknown Artist'
        ? '${track.artist} $cleanTitle'
        : cleanTitle;
    if (query.trim().isEmpty) {
      track.isOnlineEnriched = true;
      return;
    }

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query.trim())}&media=music&entity=song&limit=3',
      );
      final res = await http.get(uri, headers: namiHttpHeaders).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body);
        final results = (map['results'] as List?) ?? [];
        if (results.isNotEmpty) {
          final best = results.first;
          if (track.artist == 'Unknown Artist' && best['artistName'] != null) {
            track.artist = sanitizeMetadataText(best['artistName'].toString());
          }
          if ((track.album.isEmpty || track.album == track.title || track.album == 'Unknown Album') &&
              best['collectionName'] != null) {
            track.album = sanitizeMetadataText(best['collectionName'].toString());
          }
          if (best['primaryGenreName'] != null) {
            track.genre = sanitizeMetadataText(best['primaryGenreName'].toString());
          }
          final artUrl = best['artworkUrl100']?.toString().replaceAll('100x100bb', '600x600bb');
          if (artUrl != null && (track.albumArt == null || force)) {
            final imgRes = await http.get(Uri.parse(artUrl), headers: namiHttpHeaders).timeout(const Duration(seconds: 6));
            if (imgRes.statusCode == 200 && namiLooksLikeImage(imgRes.bodyBytes)) {
              final thumbFile = File('${thumbDir.path}/${namiDeterministicPathHash(track.path)}.jpg');
              await thumbFile.writeAsBytes(imgRes.bodyBytes);
              track.thumbPath = thumbFile.path;
              track.albumArt = imgRes.bodyBytes;
              onArtworkUpdated?.call();
            }
          }
        }
      }
    } catch (_) {}
    track.isOnlineEnriched = true;
  }
}
