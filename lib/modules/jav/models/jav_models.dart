class JavItem {
  final String code;
  final String title;
  final String cover;
  final String? thumb;
  final String date;
  final bool hasSubtitles;
  final bool isHd;
  final String? url;
  final String? actress;
  final String? size;

  JavItem({
    required this.code,
    required this.title,
    required this.cover,
    this.thumb,
    required this.date,
    this.hasSubtitles = false,
    this.isHd = false,
    this.url,
    this.actress,
    this.size,
  });

  factory JavItem.fromJson(Map<String, dynamic> json) {
    return JavItem(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      thumb: json['thumb']?.toString(),
      date: json['date']?.toString() ?? '',
      hasSubtitles: json['has_subtitles'] == true,
      isHd: json['is_hd'] == true,
      url: json['url']?.toString(),
      actress: json['actress']?.toString(),
      size: json['size']?.toString(),
    );
  }

  String getProxyCover(String baseUrl) {
    if (cover.isEmpty) return '';
    if (cover.startsWith(baseUrl)) return cover;
    final encoded = Uri.encodeComponent(cover);
    return '$baseUrl/api/img/proxy?url=$encoded&code=$code';
  }
}

class JavTagPrompt {
  final String name;
  final String prompt;

  JavTagPrompt({required this.name, required this.prompt});

  factory JavTagPrompt.fromJson(Map<String, dynamic> json) {
    return JavTagPrompt(
      name: json['name']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
    );
  }
}

class JavSearchResult {
  final String prompt;
  final String? aiComment;
  final List<JavItem> results;

  JavSearchResult({
    required this.prompt,
    this.aiComment,
    required this.results,
  });
}

class JavActressRef {
  final String name;
  final String? starId;

  JavActressRef({required this.name, this.starId});

  factory JavActressRef.fromJson(dynamic json) {
    if (json is String) {
      return JavActressRef(name: json);
    }
    if (json is Map) {
      return JavActressRef(
        name: json['name']?.toString() ?? '',
        starId: json['star_id']?.toString(),
      );
    }
    return JavActressRef(name: json.toString());
  }

  @override
  String toString() => name;
}

class JavMagnet {
  final String name;
  final String magnet;
  final String size;
  final double? sizeMb;
  final String date;
  final bool hasSubtitles;
  final bool isHd;

  JavMagnet({
    required this.name,
    required this.magnet,
    required this.size,
    this.sizeMb,
    required this.date,
    this.hasSubtitles = false,
    this.isHd = false,
  });

  factory JavMagnet.fromJson(Map<String, dynamic> json) {
    return JavMagnet(
      name: json['name']?.toString() ?? '',
      magnet: json['magnet']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      sizeMb: (json['size_mb'] is num) ? (json['size_mb'] as num).toDouble() : null,
      date: json['date']?.toString() ?? '',
      hasSubtitles: json['has_subtitles'] == true,
      isHd: json['is_hd'] == true,
    );
  }
}

class JavStreams {
  final String? hlsMaster;
  final String? hls720p;
  final String? webpage;
  final String? source;

  JavStreams({
    this.hlsMaster,
    this.hls720p,
    this.webpage,
    this.source,
  });

  factory JavStreams.fromJson(Map<String, dynamic> json) {
    return JavStreams(
      hlsMaster: json['hls_master']?.toString(),
      hls720p: (json['hls_720p'] ?? json['source842'] ?? json['source1280'])?.toString(),
      webpage: json['webpage']?.toString(),
      source: json['source']?.toString(),
    );
  }
}

class JavGenreRef {
  final String id;
  final String name;

  JavGenreRef({required this.id, required this.name});

  factory JavGenreRef.fromJson(dynamic json) {
    if (json is Map) {
      return JavGenreRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
    }
    return JavGenreRef(id: '', name: json?.toString() ?? '');
  }
}

class JavStarRef {
  final String id;
  final String name;

  JavStarRef({required this.id, required this.name});

  factory JavStarRef.fromJson(dynamic json) {
    if (json is Map) {
      return JavStarRef(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
    }
    return JavStarRef(id: '', name: json?.toString() ?? '');
  }
}

class JavSettings {
  final String missavBase;
  final String missavLocale;
  final List<String> allowedHosts;
  final String version;

  JavSettings({
    required this.missavBase,
    required this.missavLocale,
    required this.allowedHosts,
    required this.version,
  });

  factory JavSettings.fromJson(Map<String, dynamic> json) {
    return JavSettings(
      missavBase: json['missav_base']?.toString() ?? 'https://missav.ai',
      missavLocale: json['missav_locale']?.toString() ?? 'ja',
      allowedHosts: (json['allowed_hosts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      version: json['version']?.toString() ?? '2.4.0',
    );
  }
}

class JavDetail {
  final String code;
  final String title;
  final String cover;
  final String? cid;
  final String? releaseDate;
  final String? duration;
  final String? director;
  final String? maker;
  final String? publisher;
  final String? series;
  final List<String> genres;
  final List<JavActressRef> actresses;
  final List<String> samplePhotos;
  final List<JavMagnet> magnets;
  final int magnetCount;
  final Map<String, String> onlineWatchUrls;
  final String? trailerPlayerUrl;
  final String? synopsis;
  final String? studio;
  final String? label;
  final String? previewUrl;
  final JavStreams? streams;
  final List<JavGenreRef> structuredGenres;
  final List<JavStarRef> stars;
  final bool isMissavAvailable;
  final String? source;

  JavDetail({
    required this.code,
    required this.title,
    required this.cover,
    this.cid,
    this.releaseDate,
    this.duration,
    this.director,
    this.maker,
    this.publisher,
    this.series,
    required this.genres,
    required this.actresses,
    required this.samplePhotos,
    required this.magnets,
    this.magnetCount = 0,
    required this.onlineWatchUrls,
    this.trailerPlayerUrl,
    this.synopsis,
    this.studio,
    this.label,
    this.previewUrl,
    this.streams,
    this.structuredGenres = const [],
    this.stars = const [],
    this.isMissavAvailable = false,
    this.source,
  });

  factory JavDetail.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'] as List?;
    final genresList = <String>[];
    final structGenres = <JavGenreRef>[];
    if (rawGenres != null) {
      for (final g in rawGenres) {
        if (g is Map) {
          final name = g['name']?.toString() ?? '';
          final id = g['id']?.toString() ?? '';
          if (name.isNotEmpty) {
            genresList.add(name);
            structGenres.add(JavGenreRef(id: id, name: name));
          }
        } else if (g != null) {
          final str = g.toString();
          if (str.isNotEmpty) {
            genresList.add(str);
            structGenres.add(JavGenreRef(id: '', name: str));
          }
        }
      }
    }

    final starsList = (json['stars'] as List?)
            ?.whereType<Map>()
            .map((e) => JavStarRef.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    final actressesList = (json['actresses'] as List?)
            ?.map((e) => JavActressRef.fromJson(e))
            .toList() ??
        [];

    if (actressesList.isEmpty && starsList.isNotEmpty) {
      actressesList.addAll(starsList.map((s) => JavActressRef(name: s.name, starId: s.id)));
    }

    final photosList = (json['sample_photos'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final magnetsList = (json['magnets'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => JavMagnet.fromJson(e))
            .toList() ??
        [];

    final watchUrls = <String, String>{};
    if (json['online_watch_urls'] is Map) {
      (json['online_watch_urls'] as Map).forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          watchUrls[k.toString()] = v.toString();
        }
      });
    }

    String? maker = json['maker']?.toString();
    if ((maker == null || maker.isEmpty) && json['makers'] is List && (json['makers'] as List).isNotEmpty) {
      final first = (json['makers'] as List).first;
      if (first is Map) maker = first['name']?.toString();
    }

    String? label = json['label']?.toString();
    if ((label == null || label.isEmpty) && json['labels'] is List && (json['labels'] as List).isNotEmpty) {
      final first = (json['labels'] as List).first;
      if (first is Map) label = first['name']?.toString();
    }

    JavStreams? streams;
    if (json['streams'] is Map) {
      streams = JavStreams.fromJson(Map<String, dynamic>.from(json['streams']));
    }

    bool isMissav = false;
    if (json['missav'] is Map) {
      isMissav = (json['missav'] as Map)['available'] == true;
    }

    return JavDetail(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      cid: json['cid']?.toString(),
      releaseDate: json['release_date']?.toString(),
      duration: json['duration']?.toString(),
      director: json['director']?.toString(),
      maker: maker,
      publisher: json['publisher']?.toString(),
      series: json['series']?.toString(),
      genres: genresList,
      actresses: actressesList,
      samplePhotos: photosList,
      magnets: magnetsList,
      magnetCount: json['magnet_count'] is int
          ? json['magnet_count'] as int
          : magnetsList.length,
      onlineWatchUrls: watchUrls,
      trailerPlayerUrl: json['trailer_player_url']?.toString(),
      synopsis: json['synopsis']?.toString(),
      studio: maker ?? json['studio']?.toString(),
      label: label,
      previewUrl: json['preview_url']?.toString(),
      streams: streams,
      structuredGenres: structGenres,
      stars: starsList,
      isMissavAvailable: isMissav,
      source: json['_source']?.toString(),
    );
  }

  String getProxyCover(String baseUrl) {
    if (cover.isEmpty) return '';
    final encoded = Uri.encodeComponent(cover);
    return '$baseUrl/api/img/proxy?url=$encoded&code=$code';
  }

  String getProxySamplePhoto(String baseUrl, String photoUrl) {
    final encoded = Uri.encodeComponent(photoUrl);
    return '$baseUrl/api/img/proxy?url=$encoded&code=$code';
  }
}

class JavActress {
  final String name;
  final String kanji;
  final String pinyin;
  final String starId;
  final String avatar;
  final String? badge;
  final String? desc;
  final int count;

  JavActress({
    required this.name,
    required this.kanji,
    required this.pinyin,
    required this.starId,
    required this.avatar,
    this.badge,
    this.desc,
    this.count = 0,
  });

  factory JavActress.fromJson(Map<String, dynamic> json) {
    return JavActress(
      name: json['name']?.toString() ?? '',
      kanji: json['kanji']?.toString() ?? '',
      pinyin: json['pinyin']?.toString() ?? '',
      starId: json['star_id']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      badge: json['badge']?.toString(),
      desc: json['desc']?.toString(),
      count: (json['count'] is num) ? (json['count'] as num).toInt() : 0,
    );
  }

  String getProxyAvatar(String baseUrl) {
    if (avatar.isEmpty) return '';
    final encoded = Uri.encodeComponent(avatar);
    return '$baseUrl/api/img/proxy?url=$encoded';
  }
}

class JavGenre {
  final String id;
  final String name;
  final String tag;

  JavGenre({required this.id, required this.name, this.tag = ''});

  factory JavGenre.fromJson(Map<String, dynamic> json) {
    return JavGenre(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
    );
  }
}

class JavHomeSegment {
  final String name;
  final List<JavItem> items;

  JavHomeSegment({required this.name, required this.items});

  factory JavHomeSegment.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List? ?? [];
    return JavHomeSegment(
      name: json['name']?.toString() ?? '',
      items: rawList
          .whereType<Map>()
          .map((e) => JavItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class JavHomeRecommendations {
  final List<JavItem> recommended;
  final List<JavHomeSegment> segments;
  final String? source;

  JavHomeRecommendations({
    required this.recommended,
    required this.segments,
    this.source,
  });

  factory JavHomeRecommendations.fromJson(Map<String, dynamic> json) {
    final rawRec = json['recommended'] as List? ?? [];
    final rawSeg = json['segments'] as List? ?? [];
    return JavHomeRecommendations(
      recommended: rawRec
          .whereType<Map>()
          .map((e) => JavItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      segments: rawSeg
          .whereType<Map>()
          .map((e) => JavHomeSegment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      source: json['_source']?.toString(),
    );
  }
}

