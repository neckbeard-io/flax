enum DownloadState { none, queued, downloading, complete, error }

enum FilterType { peaking, lowShelf, highShelf, lowPass, highPass, bandPass, notch }

enum StreamQuality {
  original,
  flac,
  kbps320,
  kbps256,
  kbps192,
  kbps128,
  kbps64,
  disabled;

  int? get maxBitRate => switch (this) {
        StreamQuality.original => null,
        StreamQuality.flac => null,
        StreamQuality.kbps320 => 320,
        StreamQuality.kbps256 => 256,
        StreamQuality.kbps192 => 192,
        StreamQuality.kbps128 => 128,
        StreamQuality.kbps64 => 64,
        StreamQuality.disabled => null,
      };

  String get label => switch (this) {
        StreamQuality.original => 'Original',
        StreamQuality.flac => 'FLAC',
        StreamQuality.kbps320 => '320 kbps',
        StreamQuality.kbps256 => '256 kbps',
        StreamQuality.kbps192 => '192 kbps',
        StreamQuality.kbps128 => '128 kbps',
        StreamQuality.kbps64 => '64 kbps',
        StreamQuality.disabled => 'Disabled',
      };
}

enum TranscodeFormat {
  opus,
  aac,
  mp3;

  String get value => name;
}

enum AlbumListType {
  random,
  newest,
  frequent,
  recent,
  starred,
  alphabeticalByName,
  alphabeticalByArtist,
  byYear,
  byGenre;

  String get apiValue => switch (this) {
        AlbumListType.random => 'random',
        AlbumListType.newest => 'newest',
        AlbumListType.frequent => 'frequent',
        AlbumListType.recent => 'recent',
        AlbumListType.starred => 'starred',
        AlbumListType.alphabeticalByName => 'alphabeticalByName',
        AlbumListType.alphabeticalByArtist => 'alphabeticalByArtist',
        AlbumListType.byYear => 'byYear',
        AlbumListType.byGenre => 'byGenre',
      };
}

enum RepeatMode { off, all, one }

enum ThemeModeSetting { system, light, dark }
