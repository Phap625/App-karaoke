import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/song_model.dart';
import '../../../services/song_service.dart';
import '../../../utils/lrc_parser.dart';

class SongDetailScreen extends StatefulWidget {
  final int songId;
  final VoidCallback onBack;

  const SongDetailScreen({
    Key? key,
    required this.songId,
    required this.onBack,
  }) : super(key: key);

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  // Bỏ TickerProviderStateMixin vì không còn dùng Animation đĩa xoay
  SongModel? _song;
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;

  final AudioPlayer _beatPlayer = AudioPlayer();
  final AudioPlayer _vocalPlayer = AudioPlayer();

  final AutoScrollController _scrollController = AutoScrollController();

  // Đã xóa _diskController

  final int _syncOffset = -100;

  bool _isVocalEnabled = false;
  bool _hasVocalUrl = false;
  bool _isCompleted = false;

  int _lastAutoScrollIndex = -1;
  bool _isUserScrolling = false;
  Timer? _userScrollTimeoutTimer;

  final StreamController<Duration> _positionStreamController = StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // Lắng nghe vị trí để update lyric
    _beatPlayer.positionStream.listen((position) {
      if (!_positionStreamController.isClosed) {
        _positionStreamController.add(position);
      }
      if (_beatPlayer.playing && !_isUserScrolling) {
        _autoScroll(position);
      }
    });

    // Lắng nghe trạng thái player
    _beatPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isCompleted = true;
          });
        }
        _vocalPlayer.pause();
        _vocalPlayer.seek(Duration.zero);
      } else if (state.playing) {
        if (_isCompleted && mounted) setState(() => _isCompleted = false);
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _beatPlayer.dispose();
    _vocalPlayer.dispose();
    _scrollController.dispose();
    _userScrollTimeoutTimer?.cancel();
    _positionStreamController.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final song = await SongService.instance.getSongDetail(widget.songId);
      if (mounted) setState(() => _song = song);

      List<Future> setupFutures = [];
      await _beatPlayer.setSpeed(1.0);
      await _vocalPlayer.setSpeed(1.0);

      if (song.beatUrl != null) setupFutures.add(_beatPlayer.setUrl(song.beatUrl!));
      if (song.vocalUrl != null && song.vocalUrl!.isNotEmpty) {
        _hasVocalUrl = true;
        setupFutures.add(_vocalPlayer.setUrl(song.vocalUrl!));
        await _vocalPlayer.setVolume(0.0);
      }

      await Future.wait(setupFutures);

      _beatPlayer.play();
      if (_hasVocalUrl) _vocalPlayer.play();

      if (song.lyricUrl != null) {
        final response = await http.get(Uri.parse(song.lyricUrl!));
        if (response.statusCode == 200) {
          final lrcContent = utf8.decode(response.bodyBytes);
          final parsedLyrics = await compute(LrcParser.parse, lrcContent);
          if (mounted) setState(() => _lyrics = parsedLyrics);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleVocal() {
    if (!_hasVocalUrl) return;
    setState(() => _isVocalEnabled = !_isVocalEnabled);
    _vocalPlayer.setVolume(_isVocalEnabled ? 1.0 : 0.0);
  }

  void _onSeek(double value) {
    final position = Duration(milliseconds: value.toInt());
    _beatPlayer.seek(position);
    if (_hasVocalUrl) _vocalPlayer.seek(position);

    if (_isCompleted) {
      setState(() => _isCompleted = false);
    }
  }

  void _onPlayPause() {
    if (_isCompleted) {
      _beatPlayer.seek(Duration.zero);
      if (_hasVocalUrl) _vocalPlayer.seek(Duration.zero);
      _beatPlayer.play();
      if (_hasVocalUrl) _vocalPlayer.play();

      setState(() {
        _isCompleted = false;
      });
    } else if (_beatPlayer.playing) {
      _beatPlayer.pause();
      if (_hasVocalUrl) _vocalPlayer.pause();
    } else {
      if (_hasVocalUrl) {
        _vocalPlayer.seek(_beatPlayer.position);
        _vocalPlayer.play();
      }
      _beatPlayer.play();
    }
    setState(() {});
  }

  // --- LOGIC TÌM DÒNG & SCROLL ---
  int _findActiveLineIndex(int currentMs) {
    if (_lyrics.isEmpty) return -1;
    return _lyrics.lastIndexWhere((line) => currentMs >= line.startTime);
  }

  void _scrollToCurrentLine() {
    if (_lyrics.isEmpty) return;
    final currentMs = _beatPlayer.position.inMilliseconds;
    final activeIndex = _findActiveLineIndex(currentMs);

    if (activeIndex != -1 && _scrollController.hasClients) {
      _scrollController.scrollToIndex(
        activeIndex,
        preferPosition: AutoScrollPosition.middle,
        duration: const Duration(milliseconds: 300),
      );
      _lastAutoScrollIndex = activeIndex;
    }
  }

  void _autoScroll(Duration position) {
    if (_lyrics.isEmpty) return;
    int currentMs = position.inMilliseconds;
    final activeIndex = _findActiveLineIndex(currentMs);

    if (activeIndex != -1 && activeIndex != _lastAutoScrollIndex) {
      _lastAutoScrollIndex = activeIndex;
      if (_scrollController.hasClients) {
        _scrollController.scrollToIndex(
          activeIndex,
          preferPosition: AutoScrollPosition.middle,
          duration: const Duration(milliseconds: 600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // AppBar custom để hiện tên bài hát/ca sĩ
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // PHẦN 1: Thay Header thành Tên bài + Ca sĩ
        title: Column(
          children: [
            Text(
              _song?.title ?? "Đang tải...",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _song?.artistName ?? "",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.black],
          ),
        ),
        child: Column(
          children: [
            // Khoảng cách an toàn cho AppBar
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),

            // PHẦN 2: Lyric Area (2/3 màn hình)
            SizedBox(
              height: size.height * 0.66,
              width: double.infinity,
              // Wrapper để chứa Lyric
              child: _buildLyricSection(),
            ),

            // PHẦN 3: Controls Area (Phần còn lại)
            Expanded(
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  // --- PHẦN XỬ LÝ LYRIC ---
  Widget _buildLyricSection() {
    if (_lyrics.isEmpty) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF00CC)));
      }
      return const Center(child: Text("Chưa có lời bài hát", style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<Duration>(
      stream: _positionStreamController.stream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentMs = position.inMilliseconds + _syncOffset;

        int activeIndex = _findActiveLineIndex(currentMs);

        // Logic 5s ẩn highlight
        bool highlightActiveLine = true;
        if (activeIndex != -1 && activeIndex < _lyrics.length) {
          final currentLine = _lyrics[activeIndex];
          if (currentMs > currentLine.endTime + 5000) {
            if (activeIndex + 1 < _lyrics.length) {
              final nextLine = _lyrics[activeIndex + 1];
              if (currentMs < nextLine.startTime) {
                highlightActiveLine = false;
              }
            } else {
              highlightActiveLine = false;
            }
          }
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (notification.dragDetails != null) {
                _isUserScrolling = true;
                _userScrollTimeoutTimer?.cancel();
              }
            } else if (notification is ScrollEndNotification) {
              if (_isUserScrolling) {
                _userScrollTimeoutTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() => _isUserScrolling = false);
                    _scrollToCurrentLine();
                  }
                });
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            // Điều chỉnh padding vì khung nhìn giờ đã nhỏ lại (cố định), không cần padding quá lớn
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            itemCount: _lyrics.length,
            physics: const BouncingScrollPhysics(),
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final line = _lyrics[index];

              // --- LOGIC 1: ĐẾM NGƯỢC ---
              int? countdownValue;
              int timeUntilStart = line.startTime - currentMs;
              if (timeUntilStart > 0 && timeUntilStart <= 4000) {
                if (index == 0) {
                  countdownValue = (timeUntilStart / 1000).ceil();
                } else {
                  final prevLine = _lyrics[index - 1];
                  if (line.startTime - prevLine.endTime >= 10000) {
                    countdownValue = (timeUntilStart / 1000).ceil();
                  }
                }
                if (countdownValue != null && countdownValue! > 3) countdownValue = null;
              }

              // --- LOGIC 2: KIỂM TRA FAST FLOW ---
              bool isFastFlow = false;
              if (index < _lyrics.length - 1) {
                final nextLine = _lyrics[index + 1];
                final gap = nextLine.startTime - line.endTime;
                if (gap < 600) {
                  isFastFlow = true;
                }
              }

              return AutoScrollTag(
                key: ValueKey(index),
                controller: _scrollController,
                index: index,
                child: KaraokeLineItem(
                  line: line,
                  currentPositionMs: currentMs,
                  index: index,
                  activeIndex: activeIndex,
                  highlightActiveLine: highlightActiveLine,
                  countdownValue: countdownValue,
                  isFastFlow: isFastFlow,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return StreamBuilder<Duration?>(
      stream: _beatPlayer.durationStream,
      builder: (context, snapshotDuration) {
        final duration = snapshotDuration.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _beatPlayer.positionStream,
          builder: (context, snapshotPosition) {
            var position = snapshotPosition.data ?? Duration.zero;
            if (position > duration) position = duration;

            IconData playIcon = Icons.play_arrow;
            if (_isCompleted) {
              playIcon = Icons.replay;
            } else if (_beatPlayer.playing) {
              playIcon = Icons.pause;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: const Color(0xFFFF00CC),
                      activeTrackColor: const Color(0xFFFF00CC),
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: _onSeek,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatTime(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_formatTime(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _toggleVocal,
                        iconSize: 28,
                        tooltip: "Bật/Tắt lời ca sĩ",
                        icon: Icon(Icons.record_voice_over, color: _isVocalEnabled ? const Color(0xFFFF00CC) : Colors.white54),
                      ),
                      IconButton(
                        onPressed: () {
                          // Logic Previous (nếu có)
                        },
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: _onPlayPause,
                        child: Container(
                          width: 70, height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF00CC),
                            boxShadow: [BoxShadow(color: Color(0x66FF00CC), blurRadius: 20, spreadRadius: 2)],
                          ),
                          child: Icon(playIcon, color: Colors.white, size: 38),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Logic Next (nếu có)
                        },
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () {},
                        iconSize: 28,
                        icon: const Icon(Icons.playlist_play_rounded, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

// --- CLASS KaraokeLineItem GIỮ NGUYÊN ---
class KaraokeLineItem extends StatelessWidget {
  final LyricLine line;
  final int currentPositionMs;
  final int index;
  final int activeIndex;
  final bool highlightActiveLine;
  final int? countdownValue;
  final bool isFastFlow;

  const KaraokeLineItem({
    Key? key,
    required this.line,
    required this.currentPositionMs,
    required this.index,
    required this.activeIndex,
    this.highlightActiveLine = true,
    this.countdownValue,
    this.isFastFlow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isActive = (index == activeIndex);
    bool isNextFocus = (index == activeIndex + 1);

    // --- TÍNH TOÁN SCALE & OPACITY ---
    double scale = 1.0;
    double opacity = 0.5;

    if (isActive) {
      if (highlightActiveLine) {
        scale = 1.1;
        opacity = 1.0;
      } else {
        scale = 1.0;
        opacity = 0.6;
      }
    }
    else if (isNextFocus) {
      if (!highlightActiveLine) {
        scale = 1.05;
        opacity = 0.9;
      } else {
        scale = 1.0;
        opacity = 0.6;
      }
    } else if (index < activeIndex) {
      scale = 0.95;
      opacity = 0.3;
    }

    const double fixedFontSize = 18.0;
    const TextStyle commonStyle = TextStyle(
      fontSize: fixedFontSize,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: Colors.white,
      fontFamily: 'Roboto',
    );

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        width: double.infinity,
        // Không padding horizontal ở đây nữa vì đã padding ở ListView cha
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6.0,
            runSpacing: 6.0,
            children: [
              if (countdownValue != null)
                Container(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    "$countdownValue",
                    style: const TextStyle(
                      color: Color(0xFFFF00CC),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Loop qua từng từ
              ...line.words.asMap().entries.map((entry) {
                final wordIndex = entry.key;
                final word = entry.value;
                final isLastWord = wordIndex == line.words.length - 1;

                return _buildWord(
                  word,
                  commonStyle,
                  isActive && highlightActiveLine,
                  index < activeIndex,
                  isLastWord,
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWord(LyricWord word, TextStyle style, bool shouldKaraoke, bool isPastLine, bool isLastWord) {
    // 1. Nếu dòng đã qua hẳn (dựa trên index) -> Ép full hồng
    if (isPastLine) {
      return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
    }

    if (!shouldKaraoke) {
      if (currentPositionMs >= word.endTime) {
        return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
      }
      return Text(word.text, style: style);
    }

    // 2. Logic Karaoke (Shader)
    if (currentPositionMs >= word.endTime) {
      return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
    }

    // Nếu chưa đến từ này -> Màu trắng
    if (currentPositionMs < word.startTime) {
      return Text(word.text, style: style.copyWith(color: Colors.white));
    }

    // Tính toán Shader gradient
    double effectiveEndTime = word.endTime.toDouble();

    if (isLastWord && isFastFlow) {
      double fakeEnd = effectiveEndTime - 250;
      if (fakeEnd > word.startTime) {
        effectiveEndTime = fakeEnd;
      }
    }

    final double progress = (currentPositionMs - word.startTime) / (effectiveEndTime - word.startTime);
    final clampedProgress = progress.clamp(0.0, 1.0);

    return ShaderMask(
      shaderCallback: (bounds) {
        if (bounds.width == 0) return const LinearGradient(colors: [Colors.white, Colors.white]).createShader(bounds);
        return LinearGradient(
          colors: const [Color(0xFFFF00CC), Colors.white],
          stops: [clampedProgress, clampedProgress],
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        word.text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}