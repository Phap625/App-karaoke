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

class _SongDetailScreenState extends State<SongDetailScreen> with TickerProviderStateMixin {
  // ... (Phần khai báo biến giữ nguyên như cũ)
  SongModel? _song;
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;

  final AudioPlayer _beatPlayer = AudioPlayer();
  final AudioPlayer _vocalPlayer = AudioPlayer();

  final AutoScrollController _scrollController = AutoScrollController();
  late AnimationController _diskController;
  final int _syncOffset = -100; // Tinh chỉnh lại offset nếu cần

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
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isCompleted = true;
            _diskController.stop();
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

  // ... (dispose, _loadData, _toggleVocal, _onSeek, _onPlayPause giữ nguyên) ...
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

    if (_isCompleted) {
      setState(() => _isCompleted = false);
      if (!_diskController.isAnimating && _beatPlayer.playing) _diskController.repeat();
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
        _diskController.repeat();
      });
    } else if (_beatPlayer.playing) {
      _beatPlayer.pause();
      if (_hasVocalUrl) _vocalPlayer.pause();
      _diskController.stop();
    } else {
      if (_hasVocalUrl) {
        _vocalPlayer.seek(_beatPlayer.position);
        _vocalPlayer.play();
      }
      _beatPlayer.play();
      if (!_diskController.isAnimating) _diskController.repeat();
    }
    setState(() {});
  }

  // --- LOGIC TÌM DÒNG & SCROLL ---

  // Hàm tìm index dòng đang hát
  int _findActiveLineIndex(int currentMs) {
    if (_lyrics.isEmpty) return -1;
    // Tìm dòng cuối cùng mà startTime <= currentMs
    return _lyrics.lastIndexWhere((line) => currentMs >= line.startTime);
  }

  // Hàm scroll tay khi user dừng thao tác
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

  // Hàm auto scroll
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

  // ... (UI build, _buildHeader, _buildControls giữ nguyên) ...
  @override
  Widget build(BuildContext context) {
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

  // --- [QUAN TRỌNG] PHẦN XỬ LÝ LYRIC MỚI ---
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

        int activeIndex = _findActiveLineIndex(currentMs);

        // Logic 5s ẩn highlight (Giữ nguyên yêu cầu của bạn)
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
            // ... (Logic scroll user giữ nguyên)
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

              // --- LOGIC 1: ĐẾM NGƯỢC (Giữ nguyên) ---
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

              // --- LOGIC 2 [MỚI]: KIỂM TRA FAST FLOW ---
              // Kiểm tra xem dòng này và dòng sau có sát nhau quá không?
              bool isFastFlow = false;
              if (index < _lyrics.length - 1) {
                final nextLine = _lyrics[index + 1];
                final gap = nextLine.startTime - line.endTime;
                // Nếu khoảng cách < 600ms -> Là nhạc nhanh
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
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
                      GestureDetector(
                        onTap: _onPlayPause,
                        child: Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF00CC),
                            boxShadow: [BoxShadow(color: Color(0x66FF00CC), blurRadius: 15, spreadRadius: 2)],
                          ),
                          child: Icon(playIcon, color: Colors.white, size: 32),
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

// --- CLASS WIDGET MỚI: ĐỒNG BỘ LAYOUT ---
class KaraokeLineItem extends StatelessWidget {
  final LyricLine line;
  final int currentPositionMs;
  final int index;
  final int activeIndex;
  final bool highlightActiveLine;
  final int? countdownValue;
  final bool isFastFlow; // [MỚI] Nhận biết nhạc nhanh

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

    // --- TÍNH TOÁN SCALE & OPACITY (QUAY VỀ LOGIC CŨ) ---
    // Bỏ hoàn toàn việc giữ Active 500ms -> Chuyển dòng là thu nhỏ ngay lập tức.
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
      // Đã qua -> Nhỏ và mờ
      scale = 0.95;
      opacity = 0.3;
    }

    const double fixedFontSize = 16.0;
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4.0,
            runSpacing: 4.0,
            children: [
              if (countdownValue != null)
                Container(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    "$countdownValue",
                    style: const TextStyle(
                      color: Color(0xFFFF00CC),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Loop qua từng từ
              ...line.words.asMap().entries.map((entry) {
                final wordIndex = entry.key;
                final word = entry.value;
                // Kiểm tra xem đây có phải từ cuối cùng của dòng không
                final isLastWord = wordIndex == line.words.length - 1;

                return _buildWord(
                  word,
                  commonStyle,
                  isActive && highlightActiveLine,
                  index < activeIndex,
                  isLastWord, // Truyền thêm thông tin từ cuối
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWord(LyricWord word, TextStyle style, bool shouldKaraoke, bool isPastLine, bool isLastWord) {
    // 1. Nếu dòng đã qua -> Ép full hồng (Backup an toàn)
    if (isPastLine) {
      return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
    }

    if (!shouldKaraoke) {
      return Text(word.text, style: style);
    }

    // 2. Logic Karaoke
    if (currentPositionMs >= word.endTime) {
      return Text(word.text, style: style.copyWith(color: const Color(0xFFFF00CC)));
    }

    if (currentPositionMs < word.startTime) {
      return Text(word.text, style: style.copyWith(color: Colors.white));
    }

    // [LOGIC TĂNG TỐC ĐỔ MÀU]
    double effectiveEndTime = word.endTime.toDouble();

    // Nếu đây là từ cuối cùng VÀ bài hát đang đoạn nhanh (Fast Flow)
    if (isLastWord && isFastFlow) {
      // Ăn gian: Coi như từ này kết thúc sớm hơn 250ms so với thực tế
      // Để hiệu ứng tô màu chạy nhanh hơn và cán đích 100% trước khi hết giờ.
      // (Dùng clamp để không bị lỗi nếu từ quá ngắn)
      double fakeEnd = effectiveEndTime - 250;
      if (fakeEnd > word.startTime) {
        effectiveEndTime = fakeEnd;
      }
    }

    // Tính toán progress dựa trên thời gian kết thúc đã chỉnh sửa (effectiveEndTime)
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