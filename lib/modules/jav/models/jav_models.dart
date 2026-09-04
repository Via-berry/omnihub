class JavItem {
  final String code;
  final String title;
  final String cover;
  final String? thumb;
  final String date;
  final bool hasSubtitles;
  final bool isHd;
  final String? url;

  JavItem({
    required this.code,
    required this.title,
    required this.cover,
    this.thumb,
    required this.date,
    this.hasSubtitles = false,
    this.isHd = false,
    this.url,
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
    );
  }

  String getProxyCover(String baseUrl) {
    if (cover.isEmpty) return '';
    final encoded = Uri.encodeComponent(cover);
    return '$baseUrl/api/img/proxy?url=$encoded&code=$code';
  }
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
  });

  factory JavDetail.fromJson(Map<String, dynamic> json) {
    final genresList = (json['genres'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final actressesList = (json['actresses'] as List?)
            ?.map((e) => JavActressRef.fromJson(e))
            .toList() ??
        [];
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

    return JavDetail(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      cid: json['cid']?.toString(),
      releaseDate: json['release_date']?.toString(),
      duration: json['duration']?.toString(),
      director: json['director']?.toString(),
      maker: json['maker']?.toString(),
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
