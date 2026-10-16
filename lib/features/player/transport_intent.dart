/// The latest play or pause someone asked for, and whether one has arrived
/// since a given moment.
///
/// A queue opened paused — restored at launch — writes mpv's pause only once
/// every entry is loaded. A play that arrived during a long load unpaused mpv
/// and was then paused again by the load: Android Auto showed the track and
/// nothing played. The load marks this before it starts and plays at the end
/// if a play has arrived since, unless a pause came after it.
class TransportIntent {
  int _sequence = 0;
  bool _playing = false;

  /// Someone asked to play.
  void play() {
    _sequence++;
    _playing = true;
  }

  /// Someone asked to pause.
  void pause() {
    _sequence++;
    _playing = false;
  }

  /// The moment to compare against later.
  int mark() => _sequence;

  /// Whether a play was asked for after [mark], and is still the latest word.
  bool playRequestedSince(int mark) => _sequence != mark && _playing;
}
