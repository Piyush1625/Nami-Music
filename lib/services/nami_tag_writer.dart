import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

class NamiTagWriteRequest {
  final String path;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String year;
  final String lyrics;
  final Uint8List? coverBytes;

  const NamiTagWriteRequest({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.year,
    required this.lyrics,
    this.coverBytes,
  });
}

class NamiTagWriter {
  static Future<bool> writeTagsToFile({
    required String path,
    required String title,
    required String artist,
    required String album,
    required String genre,
    required String year,
    required String lyrics,
    Uint8List? coverBytes,
  }) async {
    final req = NamiTagWriteRequest(
      path: path,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      year: year,
      lyrics: lyrics,
      coverBytes: coverBytes,
    );
    try {
      return await Isolate.run(() => _writeTagsSync(req));
    } catch (_) {
      return false;
    }
  }

  static bool _writeTagsSync(NamiTagWriteRequest req) {
    final lower = req.path.toLowerCase();
    if (lower.endsWith('.flac')) {
      return _writeFlacTagsSync(req);
    } else if (lower.endsWith('.mp3')) {
      return _writeMp3Id3v23Sync(req);
    }
    return false;
  }

  static String _detectMime(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  static void _writeUint32LE(BytesBuilder out, int v) {
    out.addByte(v & 0xFF);
    out.addByte((v >> 8) & 0xFF);
    out.addByte((v >> 16) & 0xFF);
    out.addByte((v >> 24) & 0xFF);
  }

  static void _writeUint32BE(BytesBuilder out, int v) {
    out.addByte((v >> 24) & 0xFF);
    out.addByte((v >> 16) & 0xFF);
    out.addByte((v >> 8) & 0xFF);
    out.addByte(v & 0xFF);
  }

  static Uint8List _buildVorbisCommentBlock(NamiTagWriteRequest req) {
    final bb = BytesBuilder(copy: false);
    final vendor = utf8.encode('NamiMusicPlayer/2.0');
    _writeUint32LE(bb, vendor.length);
    bb.add(vendor);

    final comments = <String>[
      if (req.title.trim().isNotEmpty) 'TITLE=${req.title.trim()}',
      if (req.artist.trim().isNotEmpty) 'ARTIST=${req.artist.trim()}',
      if (req.album.trim().isNotEmpty) 'ALBUM=${req.album.trim()}',
      if (req.genre.trim().isNotEmpty) 'GENRE=${req.genre.trim()}',
      if (req.year.trim().isNotEmpty) 'DATE=${req.year.trim()}',
      if (req.lyrics.trim().isNotEmpty) 'LYRICS=${req.lyrics}',
    ];

    _writeUint32LE(bb, comments.length);
    for (final c in comments) {
      final enc = utf8.encode(c);
      _writeUint32LE(bb, enc.length);
      bb.add(enc);
    }
    return bb.toBytes();
  }

  static Uint8List _buildFlacPictureBlock(Uint8List imgBytes) {
    final bb = BytesBuilder(copy: false);
    final mime = utf8.encode(_detectMime(imgBytes));
    _writeUint32BE(bb, 3); // Front cover
    _writeUint32BE(bb, mime.length);
    bb.add(mime);
    _writeUint32BE(bb, 0); // Description length
    _writeUint32BE(bb, 0); // Width
    _writeUint32BE(bb, 0); // Height
    _writeUint32BE(bb, 24); // Color depth
    _writeUint32BE(bb, 0); // Indexed colors
    _writeUint32BE(bb, imgBytes.length);
    bb.add(imgBytes);
    return bb.toBytes();
  }

  static bool _writeFlacTagsSync(NamiTagWriteRequest req) {
    final src = File(req.path);
    if (!src.existsSync()) return false;
    final tmpPath = '${req.path}.nami_tmp';
    RandomAccessFile? raf;
    try {
      final totalLen = src.lengthSync();
      if (totalLen < 64) return false;
      raf = src.openSync(mode: FileMode.read);
      final magic = raf.readSync(4);
      if (magic.length < 4 ||
          magic[0] != 0x66 ||
          magic[1] != 0x4C ||
          magic[2] != 0x61 ||
          magic[3] != 0x43) {
        return false;
      }

      final preservedBlocks = <(int, Uint8List)>[];
      int pos = 4;
      while (pos + 4 <= totalLen) {
        raf.setPositionSync(pos);
        final hdr = raf.readSync(4);
        if (hdr.length < 4) return false;
        final isLast = (hdr[0] & 0x80) != 0;
        final blockType = hdr[0] & 0x7F;
        final length = (hdr[1] << 16) | (hdr[2] << 8) | hdr[3];
        pos += 4;
        if (length < 0 || pos + length > totalLen) return false;

        final keepPicture = req.coverBytes == null || req.coverBytes!.length < 256;
        if (blockType != 4 && blockType != 1 && (blockType != 6 || keepPicture)) {
          final body = raf.readSync(length);
          preservedBlocks.add((blockType, body));
        }
        pos += length;
        if (isLast) break;
      }

      final audioStart = pos;
      final vcBlock = _buildVorbisCommentBlock(req);
      preservedBlocks.add((4, vcBlock));
      if (req.coverBytes != null && req.coverBytes!.length >= 256) {
        preservedBlocks.add((6, _buildFlacPictureBlock(req.coverBytes!)));
      }

      final tmpFile = File(tmpPath);
      final outRaf = tmpFile.openSync(mode: FileMode.write);
      try {
        outRaf.writeFromSync([0x66, 0x4C, 0x61, 0x43]);
        for (int i = 0; i < preservedBlocks.length; i++) {
          final isLast = i == preservedBlocks.length - 1;
          final (bType, payload) = preservedBlocks[i];
          if (payload.length > 0xFFFFFF) continue;
          final b0 = (isLast ? 0x80 : 0x00) | (bType & 0x7F);
          outRaf.writeFromSync([
            b0,
            (payload.length >> 16) & 0xFF,
            (payload.length >> 8) & 0xFF,
            payload.length & 0xFF,
          ]);
          outRaf.writeFromSync(payload);
        }

        // Stream raw FLAC audio frames in 256KB chunks (low RAM)
        raf.setPositionSync(audioStart);
        int remaining = totalLen - audioStart;
        const chunkSize = 262144;
        while (remaining > 0) {
          final toRead = remaining < chunkSize ? remaining : chunkSize;
          final buf = raf.readSync(toRead);
          if (buf.isEmpty) break;
          outRaf.writeFromSync(buf);
          remaining -= buf.length;
        }
        outRaf.flushSync();
      } finally {
        outRaf.closeSync();
      }

      raf.closeSync();
      raf = null;
      tmpFile.renameSync(req.path);
      return true;
    } catch (_) {
      try {
        final tf = File(tmpPath);
        if (tf.existsSync()) tf.deleteSync();
      } catch (_) {}
      return false;
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
  }

  static Uint8List _encodeUtf16LEWithBom(String text) {
    final bb = BytesBuilder(copy: false);
    bb.add([0xFF, 0xFE]);
    for (final unit in text.codeUnits) {
      bb.addByte(unit & 0xFF);
      bb.addByte((unit >> 8) & 0xFF);
    }
    return bb.toBytes();
  }

  static Uint8List _buildId3v23TextFrame(String frameId, String value) {
    final payload = BytesBuilder(copy: false);
    payload.addByte(1); // UTF-16 with BOM
    payload.add(_encodeUtf16LEWithBom(value));
    final body = payload.toBytes();

    final frame = BytesBuilder(copy: false);
    frame.add(ascii.encode(frameId));
    _writeUint32BE(frame, body.length);
    frame.add([0x00, 0x00]);
    frame.add(body);
    return frame.toBytes();
  }

  static Uint8List _buildId3v23UsltFrame(String lyrics) {
    final payload = BytesBuilder(copy: false);
    payload.addByte(1);
    payload.add(ascii.encode('eng'));
    payload.add([0xFF, 0xFE, 0x00, 0x00]);
    payload.add(_encodeUtf16LEWithBom(lyrics));
    final body = payload.toBytes();

    final frame = BytesBuilder(copy: false);
    frame.add(ascii.encode('USLT'));
    _writeUint32BE(frame, body.length);
    frame.add([0x00, 0x00]);
    frame.add(body);
    return frame.toBytes();
  }

  static Uint8List _buildId3v23ApicFrame(Uint8List imgBytes) {
    final mime = ascii.encode(_detectMime(imgBytes));
    final payload = BytesBuilder(copy: false);
    payload.addByte(0);
    payload.add(mime);
    payload.addByte(0);
    payload.addByte(3); // Front cover
    payload.addByte(0);
    payload.add(imgBytes);
    final body = payload.toBytes();

    final frame = BytesBuilder(copy: false);
    frame.add(ascii.encode('APIC'));
    _writeUint32BE(frame, body.length);
    frame.add([0x00, 0x00]);
    frame.add(body);
    return frame.toBytes();
  }

  static bool _writeMp3Id3v23Sync(NamiTagWriteRequest req) {
    final src = File(req.path);
    if (!src.existsSync()) return false;
    final tmpPath = '${req.path}.nami_tmp';
    RandomAccessFile? raf;
    try {
      final totalLen = src.lengthSync();
      if (totalLen < 64) return false;
      raf = src.openSync(mode: FileMode.read);
      final head10 = raf.readSync(10);
      int audioStart = 0;
      if (head10.length >= 10 &&
          head10[0] == 0x49 &&
          head10[1] == 0x44 &&
          head10[2] == 0x33) {
        final flags = head10[5];
        final tagSize = ((head10[6] & 0x7F) << 21) |
            ((head10[7] & 0x7F) << 14) |
            ((head10[8] & 0x7F) << 7) |
            (head10[9] & 0x7F);
        final footer = ((flags & 0x10) != 0) ? 10 : 0;
        audioStart = 10 + tagSize + footer;
        if (audioStart > totalLen) audioStart = 0;
      }

      final frames = BytesBuilder(copy: false);
      if (req.title.trim().isNotEmpty) {
        frames.add(_buildId3v23TextFrame('TIT2', req.title.trim()));
      }
      if (req.artist.trim().isNotEmpty) {
        frames.add(_buildId3v23TextFrame('TPE1', req.artist.trim()));
      }
      if (req.album.trim().isNotEmpty) {
        frames.add(_buildId3v23TextFrame('TALB', req.album.trim()));
      }
      if (req.genre.trim().isNotEmpty) {
        frames.add(_buildId3v23TextFrame('TCON', req.genre.trim()));
      }
      if (req.year.trim().isNotEmpty) {
        frames.add(_buildId3v23TextFrame('TYER', req.year.trim()));
      }
      if (req.lyrics.trim().isNotEmpty) {
        frames.add(_buildId3v23UsltFrame(req.lyrics));
      }
      if (req.coverBytes != null && req.coverBytes!.length >= 256) {
        frames.add(_buildId3v23ApicFrame(req.coverBytes!));
      }

      final frameBytes = frames.toBytes();
      final sz = frameBytes.length;
      final header = Uint8List.fromList([
        0x49, 0x44, 0x33,
        0x03, 0x00,
        0x00,
        (sz >> 21) & 0x7F,
        (sz >> 14) & 0x7F,
        (sz >> 7) & 0x7F,
        sz & 0x7F,
      ]);

      final tmpFile = File(tmpPath);
      final outRaf = tmpFile.openSync(mode: FileMode.write);
      try {
        outRaf.writeFromSync(header);
        outRaf.writeFromSync(frameBytes);
        raf.setPositionSync(audioStart);
        int remaining = totalLen - audioStart;
        const chunkSize = 262144;
        while (remaining > 0) {
          final toRead = remaining < chunkSize ? remaining : chunkSize;
          final buf = raf.readSync(toRead);
          if (buf.isEmpty) break;
          outRaf.writeFromSync(buf);
          remaining -= buf.length;
        }
        outRaf.flushSync();
      } finally {
        outRaf.closeSync();
      }

      raf.closeSync();
      raf = null;
      tmpFile.renameSync(req.path);
      return true;
    } catch (_) {
      try {
        final tf = File(tmpPath);
        if (tf.existsSync()) tf.deleteSync();
      } catch (_) {}
      return false;
    } finally {
      try {
        raf?.closeSync();
      } catch (_) {}
    }
  }
}
