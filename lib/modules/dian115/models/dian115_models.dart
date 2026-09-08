class Dian115ShareItem {
  final int id;
  final String shareKind;
  final String shareKindLabel;
  final int season;
  final String seasons;
  final int episodeCount;
  final String episodes;
  final String resolution;
  final String source;
  final String videoCodec;
  final String audioCodec;
  final String hdr;
  final bool hasChineseSubtitle;
  final String totalSizeHuman;
  final int totalSizeBytes;
  final int unlockCost;
  final String fileName;
  final String fileExtension;
  final List<String> fileList;
  final String tagRaw;
  final String sharerName;
  final String sharerRole;
  final bool isVipSharer;
  final String createdAt;
  final int useCount;

  const Dian115ShareItem({
    required this.id,
    this.shareKind = '',
    this.shareKindLabel = '',
    this.season = 0,
    this.seasons = '',
    this.episodeCount = 0,
    this.episodes = '',
    this.resolution = '',
    this.source = '',
    this.videoCodec = '',
    this.audioCodec = '',
    this.hdr = '',
    this.hasChineseSubtitle = false,
    this.totalSizeHuman = '',
    this.totalSizeBytes = 0,
    this.unlockCost = 0,
    this.fileName = '',
    this.fileExtension = '',
    this.fileList = const [],
    this.tagRaw = '',
    this.sharerName = '',
    this.sharerRole = '',
    this.isVipSharer = false,
    this.createdAt = '',
    this.useCount = 0,
  });

  bool get is115 => shareKind == '115' || shareKindLabel.contains('115');
  bool get isMagnet => shareKind == 'offline' || shareKindLabel.contains('磁力');

  factory Dian115ShareItem.fromJson(Map<String, dynamic> json) {
    return Dian115ShareItem(
      id: json['id'] as int? ?? 0,
      shareKind: json['share_kind']?.toString() ?? '',
      shareKindLabel: json['share_kind_label']?.toString() ?? '',
      season: json['season'] as int? ?? 0,
      seasons: json['seasons']?.toString() ?? '',
      episodeCount: json['episode_count'] as int? ?? 0,
      episodes: json['episodes']?.toString() ?? '',
      resolution: json['resolution']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      videoCodec: json['video_codec']?.toString() ?? '',
      audioCodec: json['audio_codec']?.toString() ?? '',
      hdr: json['hdr']?.toString() ?? '',
      hasChineseSubtitle: json['has_chinese_subtitle'] as bool? ?? false,
      totalSizeHuman: json['total_size_human']?.toString() ?? '',
      totalSizeBytes: json['total_size_bytes'] as int? ?? 0,
      unlockCost: json['unlock_cost'] as int? ?? 0,
      fileName: json['file_name']?.toString() ?? '',
      fileExtension: json['file_extension']?.toString() ?? '',
      fileList: (json['file_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tagRaw: json['tag_raw']?.toString() ?? '',
      sharerName: json['sharer_name']?.toString() ?? '',
      sharerRole: json['sharer_role']?.toString() ?? '',
      isVipSharer: json['is_vip_sharer'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
      useCount: json['use_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'share_kind': shareKind,
        'share_kind_label': shareKindLabel,
        'season': season,
        'seasons': seasons,
        'episode_count': episodeCount,
        'episodes': episodes,
        'resolution': resolution,
        'source': source,
        'video_codec': videoCodec,
        'audio_codec': audioCodec,
        'hdr': hdr,
        'has_chinese_subtitle': hasChineseSubtitle,
        'total_size_human': totalSizeHuman,
        'total_size_bytes': totalSizeBytes,
        'unlock_cost': unlockCost,
        'file_name': fileName,
        'file_extension': fileExtension,
        'file_list': fileList,
        'tag_raw': tagRaw,
        'sharer_name': sharerName,
        'sharer_role': sharerRole,
        'is_vip_sharer': isVipSharer,
        'created_at': createdAt,
        'use_count': useCount,
      };
}

class Dian115AvailableSeason {
  final int season;
  final int shareCount;

  const Dian115AvailableSeason({
    required this.season,
    required this.shareCount,
  });

  factory Dian115AvailableSeason.fromJson(Map<String, dynamic> json) {
    return Dian115AvailableSeason(
      season: json['season'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
    );
  }
}

class Dian115SharesResponse {
  final int tmdbId;
  final String title;
  final String originalTitle;
  final int year;
  final String mediaType;
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final int sharesCount;
  final int totalSharesCount;
  final List<Dian115AvailableSeason> availableSeasons;
  final List<Dian115ShareItem> shares;

  const Dian115SharesResponse({
    required this.tmdbId,
    this.title = '',
    this.originalTitle = '',
    this.year = 0,
    this.mediaType = 'movie',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.overview = '',
    this.sharesCount = 0,
    this.totalSharesCount = 0,
    this.availableSeasons = const [],
    this.shares = const [],
  });

  factory Dian115SharesResponse.fromJson(Map<String, dynamic> json) {
    final rawShares = json['shares'] as List<dynamic>? ?? const [];
    final rawSeasons = json['available_seasons'] as List<dynamic>? ?? const [];

    return Dian115SharesResponse(
      tmdbId: json['tmdb_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      originalTitle: json['original_title']?.toString() ?? '',
      year: json['year'] as int? ?? 0,
      mediaType: json['media_type']?.toString() ?? 'movie',
      posterUrl: json['poster_url']?.toString() ?? '',
      backdropUrl: json['backdrop_url']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      sharesCount: json['shares_count'] as int? ?? rawShares.length,
      totalSharesCount: json['total_shares_count'] as int? ?? rawShares.length,
      availableSeasons: rawSeasons
          .map((e) => Dian115AvailableSeason.fromJson(e as Map<String, dynamic>))
          .toList(),
      shares: rawShares
          .map((e) => Dian115ShareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Dian115UnlockResult {
  final String code;
  final String shareUrl;
  final String receiveCode;
  final String magnetUrl;
  final int pointsCost;
  final int? unlockedAtTimestamp;

  const Dian115UnlockResult({
    this.code = 'ok',
    this.shareUrl = '',
    this.receiveCode = '',
    this.magnetUrl = '',
    this.pointsCost = 0,
    this.unlockedAtTimestamp,
  });

  bool get isSuccess => code == 'ok' || shareUrl.isNotEmpty || magnetUrl.isNotEmpty;

  factory Dian115UnlockResult.fromJson(Map<String, dynamic> json) {
    return Dian115UnlockResult(
      code: json['code']?.toString() ?? 'ok',
      shareUrl: json['share_url']?.toString() ?? '',
      receiveCode: json['receive_code']?.toString() ?? '',
      magnetUrl: json['magnet_url']?.toString() ?? '',
      pointsCost: json['points_cost'] as int? ?? 0,
      unlockedAtTimestamp: json['unlocked_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'share_url': shareUrl,
        'receive_code': receiveCode,
        'magnet_url': magnetUrl,
        'points_cost': pointsCost,
        'unlocked_at': unlockedAtTimestamp ?? DateTime.now().millisecondsSinceEpoch,
      };
}

class Dian115StatusResult {
  final String service;
  final bool isAuthenticated;
  final int points;
  final bool isVip;
  final String nickname;
  final String proxy;

  const Dian115StatusResult({
    this.service = 'online',
    this.isAuthenticated = false,
    this.points = 0,
    this.isVip = false,
    this.nickname = '',
    this.proxy = '',
  });

  factory Dian115StatusResult.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>? ?? const {};
    return Dian115StatusResult(
      service: json['service']?.toString() ?? 'offline',
      isAuthenticated: json['is_authenticated'] as bool? ?? false,
      points: json['points'] as int? ?? account['points'] as int? ?? 0,
      isVip: json['is_vip'] as bool? ?? account['vip'] as bool? ?? false,
      nickname: account['nickname']?.toString() ?? '',
      proxy: json['proxy']?.toString() ?? '',
    );
  }
}

class Dian115SearchItem {
  final int tmdbId;
  final String title;
  final String originalTitle;
  final int year;
  final String mediaType;
  final String posterUrl;
  final String backdropUrl;
  final double voteAverage;
  final String overview;

  const Dian115SearchItem({
    required this.tmdbId,
    this.title = '',
    this.originalTitle = '',
    this.year = 0,
    this.mediaType = 'movie',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.voteAverage = 0.0,
    this.overview = '',
  });

  factory Dian115SearchItem.fromJson(Map<String, dynamic> json) {
    return Dian115SearchItem(
      tmdbId: json['tmdb_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      originalTitle: json['original_title']?.toString() ?? '',
      year: json['year'] as int? ?? 0,
      mediaType: json['media_type']?.toString() ?? 'movie',
      posterUrl: json['poster_url']?.toString() ?? '',
      backdropUrl: json['backdrop_url']?.toString() ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: json['overview']?.toString() ?? '',
    );
  }
}

class Dian115SearchResult {
  final int totalResults;
  final int page;
  final List<Dian115SearchItem> results;

  const Dian115SearchResult({
    this.totalResults = 0,
    this.page = 1,
    this.results = const [],
  });

  factory Dian115SearchResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];
    return Dian115SearchResult(
      totalResults: json['total_results'] as int? ?? rawResults.length,
      page: json['page'] as int? ?? 1,
      results: rawResults
          .map((e) => Dian115SearchItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
