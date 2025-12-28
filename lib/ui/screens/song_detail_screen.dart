import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/song_model.dart';
import '../../services/song_service.dart';
import '../../utils/lrc_parser.dart';

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

class _SongDetailScreenState extends State<SongDetailScreen> with TickerProviderStateMixin {
  SongModel? _song;
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;

  final AudioPlayer _beatPlayer = AudioPlayer();
  final AudioPlayer _vocalPlayer = AudioPlayer();

  final AutoScrollController _scrollController = AutoScrollController();
  late AnimationController _diskController;
  final int _syncOffset = -220;

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

    _diskController = AnimationController(vsync: this, duration: const Duration(seconds: 10));

    _beatPlayer.positionStream.listen((position) {
      if (!_positionStreamController.isClosed) {
        _positionStreamController.add(position);
      }
      if (_beatPlayer.playing && !_isUserScrolling) {
        _autoScroll(position);
      }
    });

    _beatPlayer.playerStateStream.listen((state) {
      // [MỚI] Cập nhật trạng thái hoàn thành
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isCompleted = true; // Đánh dấu đã xong
            _diskController.stop();
          });
        }
        _vocalPlayer.pause();
        _vocalPlayer.seek(Duration.zero);
      } else if (state.playing) {
        // Nếu đang hát thì chắc chắn chưa xong
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
    _diskController.dispose();
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
      _diskController.repeat();

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

    // Khi tua lại, reset trạng thái completed
    if (_isCompleted) {
      setState(() => _isCompleted = false);
      if (!_diskController.isAnimating && _beatPlayer.playing) _diskController.repeat();
    }
  }

  // [MỚI] Logic nút Play/Pause/Replay
  void _onPlayPause() {
    if (_isCompleted) {
      // Nếu đã xong -> Replay
      _beatPlayer.seek(Duration.zero);
      if (_hasVocalUrl) _vocalPlayer.seek(Duration.zero);
      _beatPlayer.play();
      if (_hasVocalUrl) _vocalPlayer.play();

      setState(() {
        _isCompleted = false;
        _diskController.repeat();
      });
    } else if (_beatPlayer.playing) {
      // Đang hát -> Pause
      _beatPlayer.pause();
      if (_hasVocalUrl) _vocalPlayer.pause();
      _diskController.stop();
    } else {
      // Đang dừng -> Play tiếp
      if (_hasVocalUrl) {
        _vocalPlayer.seek(_beatPlayer.position);
        _vocalPlayer.play();
      }
      _beatPlayer.play();
      if (!_diskController.isAnimating) _diskController.repeat();
    }
    setState(() {});
  }

  void _scrollToCurrentLine() {
    if (_lyrics.isEmpty) return;
    final currentMs = _beatPlayer.position.inMilliseconds;
    // Tìm index an toàn hơn
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

  // [MỚI] Logic tìm dòng hát "thông minh" hơn
  // Thay vì check range (start <= t <= end), ta tìm dòng cuối cùng mà t >= start.
  // Điều này giúp giữ trạng thái active cho dòng đó cho đến khi dòng tiếp theo thực sự bắt đầu.
  int _findActiveLineIndex(int currentMs) {
    if (_lyrics.isEmpty) return -1;
    // lastIndexWhere trả về index cao nhất thỏa mãn điều kiện
    return _lyrics.lastIndexWhere((line) => currentMs >= line.startTime);
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
          duration: const Duration(milliseconds: 600), // Cuộn mượt
        );
      }
    }
  }

  // ... (build, _buildHeader giữ nguyên) ...
  @override
  Widget build(BuildContext context) {
    // (Code build UI giữ nguyên như bài trước)
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Đang phát", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E005E), Color(0xFF000000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading || _song == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
          children: [
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 20),
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: RepaintBoundary(child: _buildLyricSection()),
            ),
            _buildControls(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        RotationTransition(
          turns: _diskController,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 2),
              image: DecorationImage(
                image: NetworkImage(_song!.imageUrl ?? "https://via.placeholder.com/220"),
                fit: BoxFit.cover,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(_song!.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(_song!.artistName, style: const TextStyle(fontSize: 14, color: Colors.white70)),
      ],
    );
  }

  Widget _buildLyricSection() {
    if (_lyrics.isEmpty) {
      return const Center(child: Text("Đang tải lời...", style: TextStyle(color: Colors.grey)));
    }

    return StreamBuilder<Duration>(
      stream: _positionStreamController.stream,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentMs = position.inMilliseconds + _syncOffset;

        final activeIndex = _findActiveLineIndex(currentMs);

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
            padding: const EdgeInsets.symmetric(vertical: 120),
            itemCount: _lyrics.length,
            physics: const BouncingScrollPhysics(),
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final line = _lyrics[index];
              return AutoScrollTag(
                key: ValueKey(index),
                controller: _scrollController,
                index: index,
                child: KaraokeLineItem(
                  line: line,
                  currentPositionMs: currentMs,
                  index: index,              // [MỚI] Truyền index dòng này
                  activeIndex: activeIndex,  // [MỚI] Truyền index đang hát
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

            // [MỚI] Xác định icon Play/Pause hay Replay
            IconData playIcon = Icons.play_arrow;
            if (_isCompleted) {
              playIcon = Icons.replay;
            } else if (_beatPlayer.playing) {
              playIcon = Icons.pause;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // (Slider code cũ giữ nguyên)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: const Color(0xFFFF00CC),
                      activeTrackColor: const Color(0xFFFF00CC),
                      inactiveTrackColor: Colors.grey,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
                      Text(_formatTime(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Text(_formatTime(duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _toggleVocal,
                        iconSize: 32,
                        icon: Icon(Icons.mic, color: _isVocalEnabled ? const Color(0xFFFF00CC) : Colors.grey),
                      ),

                      // Nút Play/Pause/Replay
                      GestureDetector(
                        onTap: _onPlayPause,
                        child: Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF00CC),
                            boxShadow: [BoxShadow(color: Color(0x66FF00CC), blurRadius: 15, spreadRadius: 2)],
                          ),
                          child: Icon(
                            playIcon, // [MỚI] Sử dụng icon động
                            color: Colors.white, size: 32,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {},
                        iconSize: 32,
                        icon: const Icon(Icons.playlist_play, color: Colors.grey),
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

// --- WIDGET KARAOKE CẢI TIẾN ---
class KaraokeLineItem extends StatelessWidget {
  final LyricLine line;
  final int currentPositionMs;
  // [MỚI] Thêm tham số để biết dòng nào đang hát
  final int index;
  final int activeIndex;

  const KaraokeLineItem({
    Key? key,
    required this.line,
    required this.currentPositionMs,
    required this.index,
    required this.activeIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. LOGIC 2 DÒNG ZOOM
    // Dòng hiện tại (activeIndex) -> Zoom to nhất
    bool isCurrentLine = (index == activeIndex);
    // Dòng kế tiếp (activeIndex + 1) -> Zoom vừa (chuẩn bị)
    bool isNextLine = (index == activeIndex + 1);

    // Logic hiển thị "đã qua" (nhưng giữ lại dòng vừa hát xong cho đến khi dòng mới bắt đầu hẳn)
    bool isPastLine = index < activeIndex;

    const double fixedFontSize = 18.0;
    final TextStyle commonStyle = TextStyle(
      fontSize: fixedFontSize,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Colors.white,
    );

    // Tính toán Scale và Opacity linh hoạt
    double scale = 1.0;
    double opacity = 0.5;

    if (isCurrentLine) {
      scale = 1.1;      // Dòng đang hát: To nhất
      opacity = 1.0;     // Sáng nhất
    } else if (isNextLine) {
      scale = 1.0;       // Dòng kế tiếp: Hơi to (để mắt dễ đọc trước)
      opacity = 0.8;     // Hơi sáng
    } else if (isPastLine) {
      scale = 0.8;
      opacity = 0.3;     // Dòng đã qua: Mờ hẳn
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        // Điều chỉnh margin để tạo không gian
        margin: EdgeInsets.symmetric(
          vertical: isCurrentLine ? 16.0 : (isNextLine ? 10.0 : 6.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            child: isCurrentLine
                ? _buildActiveLine(commonStyle)
                : Text(
              line.content,
              textAlign: TextAlign.center,
              style: commonStyle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveLine(TextStyle style) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0,
      runSpacing: 2.0,
      children: line.words.map((word) {
        return _buildSingleWord(word, style);
      }).toList(),
    );
  }

  Widget _buildSingleWord(LyricWord word, TextStyle style) {
    // Logic tô màu từng chữ
    // Lưu ý: Dù dòng active giữ lại (do index == activeIndex),
    // nhưng việc tô màu vẫn dựa trên thời gian thực tế của từ.

    final isWordPast = currentPositionMs >= word.endTime;
    final isWordFuture = currentPositionMs < word.startTime;

    if (isWordPast) {
      return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
    }

    if (isWordFuture) {
      return Text(word.text, style: style.copyWith(color: Colors.white));
    }

    // ĐANG HÁT
    final double progress = (currentPositionMs - word.startTime) / (word.endTime - word.startTime);
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