import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../core/app_theme.dart';
import '../core/server_manager.dart';
import '../data/models/media_content.dart';
import '../features/library/library_cubit.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.content,
    required this.initialSource,
    required this.preferredQuality,
    this.initialPosition = Duration.zero,
  });
  final MediaContent content;
  final PlaybackSource initialSource;
  final String preferredQuality;
  final Duration initialPosition;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  List<PlaybackSource> _candidates = const [];
  List<VideoTrack> _tracks = const [];
  int _candidateIndex = 0;
  String _quality = 'Auto';
  String _serverLabel = 'Connecting...';
  String? _error;
  bool _loading = true;
  bool _showControls = true;
  bool _switching = false;
  bool _playbackHasStarted = false;
  bool _userPaused = false;
  DateTime? _bufferStartedAt;
  Timer? _monitorTimer;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  late final LibraryCubit _libraryCubit;
  late final ServerManager _serverManager;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _serverManager = context.read<ServerManager>();
    _libraryCubit = context.read<LibraryCubit>();
    unawaited(_libraryCubit.addToHistory(widget.content.id));
    _progressTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final position = _controller?.value.position.inSeconds ?? 0;
      if (position > 0)
        unawaited(_libraryCubit.saveProgress(widget.content.id, position));
    });
    _start();
  }

  Future<void> _start() async {
    try {
      final manager = _manager;
      _candidates = await manager.getCandidates(
        widget.content,
        widget.preferredQuality,
        preferredServer: widget.initialSource.serverId,
      );
      final first = _candidates.indexWhere(
        (e) => e.url == widget.initialSource.url,
      );
      _candidateIndex = first < 0 ? 0 : first;
      await _openCandidate(
        _candidateIndex,
        position: widget.initialPosition,
        resume: true,
      );
      _monitorTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _monitorBuffer(),
      );
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Could not prepare this stream: $error';
        });
    }
  }

  ServerManager get _manager => _serverManager;

  Future<void> _openCandidate(
    int index, {
    required Duration position,
    required bool resume,
  }) async {
    if (index < 0 || index >= _candidates.length || _switching) return;
    _switching = true;
    _bufferStartedAt = null;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    final candidate = _candidates[index];
    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(
        candidate.url,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await next.initialize().timeout(const Duration(seconds: 30));
      await next.setLooping(false);
      if (position > Duration.zero && next.value.duration > position)
        await next.seekTo(position);
      if (resume) {
        await next.play();
        _playbackHasStarted = true;
        _userPaused = false;
      }
      final tracks = next.isVideoTrackSupportAvailable()
          ? await next.getVideoTracks()
          : <VideoTrack>[];
      final selectedTrack = await _applyPreferredTrack(next, tracks);
      final previous = _controller;
      _controller = next;
      _candidateIndex = index;
      _tracks = List<VideoTrack>.from(tracks)
        ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
      _serverLabel = candidate.serverName;
      _quality = selectedTrack != null
          ? _qualityLabel(selectedTrack.height ?? 0)
          : 'Auto';
      previous?.removeListener(_onVideoChanged);
      await previous?.dispose();
      _controller?.addListener(_onVideoChanged);
      if (mounted)
        setState(() {
          _loading = false;
          _error = null;
        });
      _resetHideTimer();
    } catch (error) {
      await next?.dispose();
      if (index + 1 < _candidates.length) {
        _candidateIndex = index;
        _switching = false;
        await _switchServer(position: position);
        return;
      }
      if (mounted)
        setState(() {
          _loading = false;
          _error =
              'Stream tidak dapat diputar. Periksa sumber atau koneksi internet.';
        });
    } finally {
      _switching = false;
    }
  }

  Future<VideoTrack?> _applyPreferredTrack(
    VideoPlayerController controller,
    List<VideoTrack> tracks,
  ) async {
    if (tracks.isEmpty || !controller.isVideoTrackSupportAvailable())
      return null;
    final requestedHeight = switch (widget.preferredQuality) {
      '4K' => 2160,
      '1080p' => 1080,
      '720p' => 720,
      '480p' => 480,
      _ => 2160,
    };
    final eligible =
        tracks.where((track) => (track.height ?? 0) <= requestedHeight).toList()
          ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    final selected = eligible.isNotEmpty ? eligible.first : tracks.last;
    try {
      await controller.selectVideoTrack(selected);
      return selected;
    } catch (_) {
      return null; /* Keep ExoPlayer's automatic selection. */
    }
  }

  void _onVideoChanged() {
    if (!mounted || _controller == null) return;
    if (_controller!.value.hasError && !_switching) {
      unawaited(_switchServer(position: _controller!.value.position));
    }
    setState(() {});
  }

  void _monitorBuffer() {
    if (!mounted ||
        _controller == null ||
        _switching ||
        !_controller!.value.isInitialized)
      return;
    final value = _controller!.value;
    if (value.isBuffering && _playbackHasStarted && !_userPaused) {
      _bufferStartedAt ??= DateTime.now();
      if (DateTime.now().difference(_bufferStartedAt!) >=
          const Duration(seconds: 4)) {
        _bufferStartedAt = null;
        unawaited(_downgradeOrSwitch());
      }
    } else {
      _bufferStartedAt = null;
    }
  }

  Future<void> _downgradeOrSwitch() async {
    if (_switching || _controller == null) return;
    final currentHeight = switch (_quality) {
      '4K' => 2160,
      '1080p' => 1080,
      '720p' => 720,
      '480p' => 480,
      _ => _tracks.isNotEmpty ? (_tracks.first.height ?? 0) : 0,
    };
    final lower = _tracks.where((t) => (t.height ?? 0) < currentHeight).toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    if (lower.isNotEmpty) {
      try {
        await _controller!.selectVideoTrack(lower.first);
        if (mounted)
          setState(() => _quality = _qualityLabel(lower.first.height ?? 0));
        return;
      } catch (_) {
        // If the stream does not support a track override, continue to the next source.
      }
    }
    await _switchServer(position: _controller!.value.position);
  }

  Future<void> _switchServer({required Duration position}) async {
    if (_switching) return;
    final nextIndex = _candidateIndex + 1;
    if (nextIndex >= _candidates.length) {
      if (mounted)
        setState(() {
          _error =
              'Semua sumber untuk judul ini sedang gagal atau belum dikonfigurasi.';
          _loading = false;
        });
      return;
    }
    final oldName = _candidates[_candidateIndex].serverName;
    final newName = _candidates[nextIndex].serverName;
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$oldName bermasalah, mencoba $newName.')),
      );
    await _openCandidate(nextIndex, position: position, resume: true);
  }

  Future<void> _selectTrack(VideoTrack? track) async {
    final controller = _controller;
    if (controller == null || !controller.isVideoTrackSupportAvailable()) {
      _message(
        'Stream ini memakai kualitas tetap; pilihan manual tidak tersedia.',
      );
      return;
    }
    try {
      await controller.selectVideoTrack(track);
      if (mounted)
        setState(
          () => _quality = track == null
              ? 'Auto'
              : _qualityLabel(track.height ?? 0),
        );
    } catch (_) {
      _message('Kualitas tersebut tidak didukung oleh stream ini.');
    }
  }

  String _qualityLabel(int height) {
    if (height >= 2160) return '4K';
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    if (height >= 480) return '480p';
    return '${height}p';
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (_controller?.value.isPlaying == true) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      _userPaused = true;
      await controller.pause();
      _hideControlsTimer?.cancel();
    } else {
      _userPaused = false;
      await controller.play();
      _resetHideTimer();
    }
    if (mounted) setState(() => _showControls = true);
  }

  Future<void> _seek(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final target = controller.value.position + offset;
    final safe = target < Duration.zero
        ? Duration.zero
        : target > controller.value.duration
        ? controller.value.duration
        : target;
    await controller.seekTo(safe);
    if (mounted) setState(() => _showControls = true);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _hideControlsTimer?.cancel();
    _progressTimer?.cancel();
    final finalPosition = _controller?.value.position.inSeconds ?? 0;
    if (finalPosition > 0)
      unawaited(_libraryCubit.saveProgress(widget.content.id, finalPosition));
    _controller?.removeListener(_onVideoChanged);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) _resetHideTimer();
          },
          onDoubleTapDown: (details) {
            final width = MediaQuery.sizeOf(context).width;
            unawaited(
              _seek(
                details.localPosition.dx < width / 2
                    ? const Duration(seconds: -10)
                    : const Duration(seconds: 10),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: controller != null && controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : const CircularProgressIndicator(color: AppColors.red),
              ),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              if (_error != null)
                Center(
                  child: Container(
                    margin: EdgeInsets.all(24.w),
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.secondary,
                          size: 34,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        SizedBox(height: 14.h),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showControls && _error == null) _controls(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(VideoPlayerController? controller) => Stack(
    children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black87,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0, .28, .62, 1],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 8.h,
        left: 10.w,
        right: 14.w,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            Expanded(
              child: Text(
                widget.content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                _serverLabel,
                style: const TextStyle(fontSize: 8, color: AppColors.blue),
              ),
            ),
          ],
        ),
      ),
      if (controller != null && controller.value.isInitialized)
        Positioned.fill(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _seek(const Duration(seconds: -10)),
                  icon: const Icon(
                    Icons.replay_10,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                SizedBox(width: 24.w),
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
                SizedBox(width: 24.w),
                IconButton(
                  onPressed: () => _seek(const Duration(seconds: 10)),
                  icon: const Icon(
                    Icons.forward_10,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      Positioned(
        left: 16.w,
        right: 16.w,
        bottom: 15.h,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller != null && controller.value.isInitialized)
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.red,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  _format(controller?.value.position ?? Duration.zero),
                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  _format(controller?.value.duration ?? Duration.zero),
                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _qualityChip(
                    'Auto',
                    selected: _quality == 'Auto',
                    enabled: true,
                    onTap: () => _selectTrack(null),
                  ),
                  for (final track in _tracks)
                    _qualityChip(
                      _qualityLabel(track.height ?? 0),
                      selected: _quality == _qualityLabel(track.height ?? 0),
                      enabled: true,
                      onTap: () => _selectTrack(track),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _qualityChip(
    String label, {
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) => Padding(
    padding: EdgeInsets.only(right: 6.w),
    child: ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          color: selected ? Colors.white : AppColors.secondary,
        ),
      ),
      onPressed: enabled ? onTap : null,
      backgroundColor: selected ? AppColors.red : AppColors.surface2,
      side: BorderSide(color: selected ? AppColors.red : AppColors.surface3),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    ),
  );

  String _format(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final hours = duration.inHours;
    return hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  Future<void> _retry() async {
    if (_candidates.isEmpty) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    await _openCandidate(
      _candidateIndex,
      position: widget.initialPosition,
      resume: true,
    );
  }
}
