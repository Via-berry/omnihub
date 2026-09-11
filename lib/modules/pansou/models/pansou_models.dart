enum PansouItemType {
  pan115,
  magnet,
  ed2k,
  other;

  static PansouItemType fromRaw(String raw, String url) {
    final lowerRaw = raw.toLowerCase().trim();
    final lowerUrl = url.toLowerCase().trim();
    if (lowerRaw == '115' ||
        lowerUrl.contains('115.com') ||
        lowerUrl.contains('115cdn.com') ||
        lowerUrl.contains('anxia.com')) {
      return PansouItemType.pan115;
    }
    if (lowerRaw == 'magnet' || lowerUrl.startsWith('magnet:?')) {
      return PansouItemType.magnet;
    }
    if (lowerRaw == 'ed2k' || lowerUrl.startsWith('ed2k://')) {
      return PansouItemType.ed2k;
    }
    return PansouItemType.other;
  }

  String get label {
    switch (this) {
      case PansouItemType.pan115:
        return '115 网盘';
      case PansouItemType.magnet:
        return '磁力链接';
      case PansouItemType.ed2k:
        return '电驴链接';
      case PansouItemType.other:
        return '其他来源';
    }
  }
}

class PansouItem {
  final String uniqueId;
  final PansouItemType type;
  final String rawType;
  final String url;
  final String password;
  final String note;
  final String title;
  final String datetime;
  final String source;
  final List<String> images;

  // 智能解析字段
  final String resolution;
  final String videoCodec;
  final String audioCodec;
  final String hdr;
  final bool hasChineseSubtitle;
  final int season;
  final String totalSizeHuman;

  const PansouItem({
    required this.uniqueId,
    required this.type,
    required this.rawType,
    required this.url,
    required this.password,
    required this.note,
    required this.title,
    required this.datetime,
    required this.source,
    this.images = const [],
    this.resolution = '',
    this.videoCodec = '',
    this.audioCodec = '',
    this.hdr = '',
    this.hasChineseSubtitle = false,
    this.season = 0,
    this.totalSizeHuman = '',
  });

  bool get is115 => type == PansouItemType.pan115;
  bool get isMagnet => type == PansouItemType.magnet;
  bool get isEd2k => type == PansouItemType.ed2k;
  bool get isOfflineDownload => isMagnet || isEd2k;

  factory PansouItem.fromMergedJson({
    required String rawType,
    required Map<String, dynamic> json,
    int index = 0,
  }) {
    final url = json['url']?.toString().trim() ?? '';
    final password = json['password']?.toString().trim() ?? '';
    final note = json['note']?.toString().trim() ?? '';
    final datetime = json['datetime']?.toString().trim() ?? '';
    final source = json['source']?.toString().trim() ?? '';
    final parsedType = PansouItemType.fromRaw(rawType, url);

    final rawImages = json['images'];
    final images = <String>[];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is String && img.trim().isNotEmpty) {
          images.add(img.trim());
        }
      }
    }

    final meta = _parseMetadata(note: note, url: url);

    return PansouItem(
      uniqueId: '${source}_${url.hashCode}_$index',
      type: parsedType,
      rawType: rawType,
      url: url,
      password: password,
      note: note,
      title: meta.title.isNotEmpty ? meta.title : (note.isNotEmpty ? note : '未知资源'),
      datetime: datetime,
      source: source,
      images: images,
      resolution: meta.resolution,
      videoCodec: meta.videoCodec,
      audioCodec: meta.audioCodec,
      hdr: meta.hdr,
      hasChineseSubtitle: meta.hasChineseSubtitle,
      season: meta.season,
      totalSizeHuman: meta.totalSizeHuman,
    );
  }

  static _ParsedMeta _parseMetadata({required String note, required String url}) {
    final text = '$note $url';
    final lower = text.toLowerCase();

    // 1. 分辨率
    var resolution = '';
    if (text.contains('4K') ||
        text.contains('2160') ||
        lower.contains('uhd') ||
        lower.contains('4k')) {
      resolution = '4K';
    } else if (text.contains('1080') || lower.contains('fhd')) {
      resolution = '1080P';
    } else if (text.contains('720')) {
      resolution = '720P';
    }

    // 2. 视频编码
    var videoCodec = '';
    if (lower.contains('hevc') ||
        lower.contains('h.265') ||
        lower.contains('h265') ||
        lower.contains('x265')) {
      videoCodec = 'HEVC';
    } else if (lower.contains('avc') ||
        lower.contains('h.264') ||
        lower.contains('h264') ||
        lower.contains('x264')) {
      videoCodec = 'H.264';
    } else if (lower.contains('av1')) {
      videoCodec = 'AV1';
    }

    // 3. 音频编码
    var audioCodec = '';
    if (lower.contains('atmos') || lower.contains('全景声')) {
      audioCodec = 'Atmos';
    } else if (lower.contains('dts-hd') || lower.contains('dtshd')) {
      audioCodec = 'DTS-HD';
    } else if (lower.contains('dts')) {
      audioCodec = 'DTS';
    } else if (lower.contains('truehd')) {
      audioCodec = 'TrueHD';
    } else if (lower.contains('aac')) {
      audioCodec = 'AAC';
    } else if (lower.contains('ac3') || lower.contains('eac3') || lower.contains('ddp')) {
      audioCodec = 'DDP';
    }

    // 4. HDR / 杜比视界
    var hdr = '';
    if (lower.contains('dv') ||
        lower.contains('dovi') ||
        lower.contains('dolby vision') ||
        text.contains('杜比视界')) {
      hdr = 'DV';
    } else if (lower.contains('hdr10+')) {
      hdr = 'HDR10+';
    } else if (lower.contains('hdr')) {
      hdr = 'HDR';
    }

    // 5. 中文字幕
    final hasChineseSubtitle = lower.contains('中字') ||
        lower.contains('官中') ||
        lower.contains('内封中字') ||
        lower.contains('中文字幕') ||
        lower.contains('国语') ||
        lower.contains('国配') ||
        lower.contains('简繁');

    // 6. 季数提取
    var season = 0;
    final seasonRegex = RegExp(r'[sS](0?[1-9]\d?)|第\s*([一二三四五六七八九十\d]+)\s*季');
    final match = seasonRegex.firstMatch(text);
    if (match != null) {
      final sStr = match.group(1);
      final cnStr = match.group(2);
      if (sStr != null) {
        season = int.tryParse(sStr) ?? 0;
      } else if (cnStr != null) {
        season = _cnNumToInt(cnStr);
      }
    }

    // 7. 体积提取 (例如 [62.81 GB] 或 480.7GB)
    var totalSizeHuman = '';
    final sizeRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(GB|MB|TB|G|M|T)', caseSensitive: false);
    final sizeMatch = sizeRegex.firstMatch(note);
    if (sizeMatch != null) {
      final numPart = sizeMatch.group(1) ?? '';
      final unitPart = (sizeMatch.group(2) ?? '').toUpperCase();
      final fullUnit = unitPart.length == 1 ? '${unitPart}B' : unitPart;
      totalSizeHuman = '$numPart $fullUnit';
    }

    // 8. 标题提纯
    var title = note.split('\n').first.trim();
    if (title.startsWith('【标题】：')) {
      title = title.substring(5).trim();
    } else if (title.startsWith('名称:')) {
      title = title.substring(3).trim();
    } else if (title.startsWith('🎬') || title.startsWith('📺') || title.startsWith('📢')) {
      title = title.substring(2).trim();
    }

    return _ParsedMeta(
      title: title,
      resolution: resolution,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      hdr: hdr,
      hasChineseSubtitle: hasChineseSubtitle,
      season: season,
      totalSizeHuman: totalSizeHuman,
    );
  }

  static int _cnNumToInt(String cn) {
    switch (cn) {
      case '一':
      case '1':
        return 1;
      case '二':
      case '2':
        return 2;
      case '三':
      case '3':
        return 3;
      case '四':
      case '4':
        return 4;
      case '五':
      case '5':
        return 5;
      case '六':
      case '6':
        return 6;
      case '七':
      case '7':
        return 7;
      case '八':
      case '8':
        return 8;
      case '九':
      case '9':
        return 9;
      case '十':
      case '10':
        return 10;
      default:
        return int.tryParse(cn) ?? 0;
    }
  }
}

class _ParsedMeta {
  final String title;
  final String resolution;
  final String videoCodec;
  final String audioCodec;
  final String hdr;
  final bool hasChineseSubtitle;
  final int season;
  final String totalSizeHuman;

  _ParsedMeta({
    required this.title,
    required this.resolution,
    required this.videoCodec,
    required this.audioCodec,
    required this.hdr,
    required this.hasChineseSubtitle,
    required this.season,
    required this.totalSizeHuman,
  });
}

class Pansou115SnapInfo {
  final bool isValid;
  final int fileSizeBytes;
  final String fileSizeHuman;
  final int fileCount;
  final String shareTitle;
  final String? errorMessage;

  const Pansou115SnapInfo({
    required this.isValid,
    this.fileSizeBytes = 0,
    this.fileSizeHuman = '',
    this.fileCount = 0,
    this.shareTitle = '',
    this.errorMessage,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    const tb = gb * 1024;
    if (bytes >= tb) {
      return '${(bytes / tb).toStringAsFixed(2)} TB';
    } else if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / kb).toStringAsFixed(0)} KB';
    }
  }
}

