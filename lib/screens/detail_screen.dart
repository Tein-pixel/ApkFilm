import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/server_manager.dart';
import '../data/models/media_content.dart';
import '../data/repositories/catalog_repository.dart';
import '../features/library/library_cubit.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.content, this.resume = false});
  final MediaContent content;
  final bool resume;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String _quality = '1080p';
  String? _serverId;
  bool _starting = false;
  Future<Map<String, dynamic>?>? _providersFuture;
  Future<Map<String, dynamic>?>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    _setSuggestedQuality();
    if (widget.content.isTmdb) {
      final repository = context.read<CatalogRepository>();
      _providersFuture = repository.getWatchProviders(widget.content);
      _detailsFuture = repository.getTitleDetails(widget.content);
    }
    const serverIds = ['server1', 'server2', 'server3', 'server4', 'server5'];
    final readyServers = serverIds.where(_hasUsableSource).toList();
    _serverId = readyServers.isEmpty ? null : readyServers.first;
  }

  Future<void> _setSuggestedQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saver = prefs.getBool('data_saver') ?? false;
      final result = await Connectivity().checkConnectivity();
      final suggested = saver
          ? '480p'
          : result.contains(ConnectivityResult.wifi)
          ? '1080p'
          : result.contains(ConnectivityResult.mobile)
          ? '720p'
          : '480p';
      const qualityOrder = ['360p', '480p', '720p', '1080p', '4K'];
      final available = _availableQualities;
      final limit = qualityOrder.indexOf(suggested);
      final suitable = available
          .where((quality) => qualityOrder.indexOf(quality) <= limit)
          .toList();
      final selected = suitable.isNotEmpty
          ? suitable.last
          : available.isNotEmpty
          ? available.first
          : '480p';
      if (mounted) setState(() => _quality = selected);
    } catch (_) {
      if (mounted) setState(() => _quality = '480p');
    }
  }

  Future<void> _watch() async {
    if (_starting) return;
    setState(() => _starting = true);
    final manager = context.read<ServerManager>();
    try {
      final source = await manager.getBestSource(
        widget.content.id,
        _quality,
        preferredServer: _serverId,
        content: widget.content,
      );
      if (!mounted) return;
      if (source == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada sumber yang dapat dijangkau. Periksa internet atau konfigurasi server.',
            ),
          ),
        );
        return;
      }
      final savedSeconds =
          context.read<LibraryCubit>().progress[widget.content.id] ?? 0;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            content: widget.content,
            initialSource: source,
            preferredQuality: _quality,
            initialPosition: widget.resume
                ? Duration(seconds: savedSeconds)
                : Duration.zero,
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyiapkan stream: $error')),
        );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryCubit>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 270.h,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1A2E4A),
                          Color(0xFF50171E),
                          Colors.black,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  if ((widget.content.backdrop ?? widget.content.poster)
                          ?.trim()
                          .isNotEmpty ==
                      true)
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: (widget.content.backdrop ??
                                widget.content.poster!)
                            .trim(),
                        fit: BoxFit.cover,
                        memCacheHeight: 900,
                        errorWidget: (_, __, ___) =>
                            const SizedBox.expand(),
                      ),
                    ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        color: Colors.black.withValues(alpha: .22),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20.w,
                    bottom: 8.h,
                    child: Icon(
                      Icons.movie_creation_outlined,
                      size: 240.w,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  Positioned(
                    left: 20.w,
                    right: 20.w,
                    bottom: 22.h,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Hero(
                          tag: 'poster-${widget.content.id}',
                          child: Container(
                            width: 100.w,
                            height: 150.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF30435E), Color(0xFF792A32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: widget.content.poster?.trim().isNotEmpty ==
                                    true
                                ? CachedNetworkImage(
                                    imageUrl: widget.content.poster!.trim(),
                                    fit: BoxFit.cover,
                                    memCacheHeight: 900,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.movie_creation_outlined,
                                      size: 42,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Icon(
                                    Icons.movie_creation_outlined,
                                    size: 42,
                                    color: Colors.white70,
                                  ),
                          ),
                        ),
                        SizedBox(width: 15.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.content.title,
                                style: TextStyle(
                                  fontSize: 21.sp,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                              ),
                              SizedBox(height: 7.h),
                              Text(
                                '${widget.content.year} • ${widget.content.age} • ${widget.content.duration}',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.gold,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    widget.content.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 9.w),
                                  const Icon(
                                    Icons.high_quality_rounded,
                                    color: AppColors.green,
                                    size: 15,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    widget.content.isTmdb ? 'TMDB CATALOG' : 'OPEN CONTENT',
                                    style: TextStyle(
                                      color: AppColors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.content.synopsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.secondary,
                      height: 1.55,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  if (widget.content.isTmdb) _tmdbDetailsSection(),
                  if (widget.content.isTmdb) SizedBox(height: 18.h),
                  Wrap(
                    spacing: 7.w,
                    runSpacing: 7.h,
                    children: widget.content.categories
                        .map((c) => _tag(c))
                        .toList(),
                  ),
                  SizedBox(height: 22.h),
                  if (widget.content.isTmdb) ...[
                    _watchProvidersSection(),
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(13.w),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.surface3),
                      ),
                      child: Text(
                        'TMDB menyediakan informasi katalog, bukan file video. CineWave hanya dapat memutar judul yang memiliki sumber video resmi dan berizin.',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11.sp,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Text(
                          'STREAM SERVER',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_configuredSourceCount}/5 sources',
                          style: const TextStyle(color: AppColors.blue, fontSize: 10),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    ..._serverList(),
                    SizedBox(height: 18.h),
                    Text(
                      'QUALITY',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      children: _availableQualities.map((q) => ChoiceChip(
                        label: Text(q),
                        selected: _quality == q,
                        onSelected: (_) => setState(() => _quality = q),
                        selectedColor: AppColors.red.withValues(alpha: .25),
                        side: BorderSide(
                          color: _quality == q ? AppColors.red : AppColors.surface3,
                        ),
                        labelStyle: TextStyle(
                          color: _quality == q ? Colors.white : AppColors.secondary,
                          fontSize: 10,
                        ),
                      )).toList(),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _starting ? null : _watch,
                        icon: _starting
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(_starting ? 'Checking sources...' : 'Watch now'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 10.h),
                  OutlinedButton.icon(
                    onPressed: () => context.read<LibraryCubit>().toggleMyList(
                      widget.content.id,
                    ),
                    icon: Icon(
                      library.contains(widget.content.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    label: Text(
                      library.contains(widget.content.id)
                          ? 'Remove from My List'
                          : 'Add to My List',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.surface3),
                      minimumSize: Size(double.infinity, 44.h),
                    ),
                  ),
                  SizedBox(height: 22.h),
                  Text(
                    widget.content.isTmdb ? 'TMDB ATTRIBUTION' : 'LICENSE & ATTRIBUTION',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    widget.content.license,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.secondary,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    widget.content.attribution,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.tertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _tmdbDetailsSection() => FutureBuilder<Map<String, dynamic>?>(
    future: _detailsFuture,
    builder: (context, snapshot) {
      final details = snapshot.data;
      if (details == null || snapshot.hasError) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.red,
            ),
          );
        }
        return const SizedBox.shrink();
      }

      final runtimeValue = widget.content.isMovie
          ? details['runtime']
          : (details['episode_run_time'] is List &&
                  (details['episode_run_time'] as List).isNotEmpty)
              ? (details['episode_run_time'] as List).first
              : null;
      final runtime = runtimeValue is num ? runtimeValue.toInt() : 0;
      final seasons = (details['number_of_seasons'] as num?)?.toInt() ?? 0;
      final episodes = (details['number_of_episodes'] as num?)?.toInt() ?? 0;
      final certification = _tmdbCertification(details);

      final castData = details['credits'] is Map
          ? (details['credits'] as Map)['cast']
          : null;
      final cast = castData is List
          ? castData.whereType<Map>().take(10).toList(growable: false)
          : const <Map>[];

      final videosData = details['videos'] is Map
          ? (details['videos'] as Map)['results']
          : null;
      final videos = videosData is List
          ? videosData.whereType<Map>().toList(growable: false)
          : const <Map>[];
      Map? trailer;
      for (final video in videos) {
        if (video['site'] == 'YouTube' &&
            video['type'] == 'Trailer' &&
            video['key']?.toString().isNotEmpty == true) {
          trailer = video;
          if (video['official'] == true) break;
        }
      }

      final stats = <String>[];
      if (runtime > 0) {
        stats.add(widget.content.isMovie
            ? '${runtime} min'
            : '${runtime} min/episode');
      }
      if (seasons > 0) stats.add('${seasons} seasons');
      if (episodes > 0) stats.add('${episodes} episodes');
      if (certification.isNotEmpty) stats.add(certification);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats.isNotEmpty)
            Wrap(
              spacing: 7.w,
              runSpacing: 7.h,
              children: stats.map(_tag).toList(growable: false),
            ),
          if (trailer != null) ...[
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed: () => _openYoutubeTrailer(trailer!['key'].toString()),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Official trailer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.surface3),
              ),
            ),
          ],
          if (cast.isNotEmpty) ...[
            SizedBox(height: 18.h),
            Text(
              'CAST',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 146.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cast.length,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  final person = cast[index];
                  final name = person['name']?.toString() ?? 'Cast member';
                  final character = person['character']?.toString() ?? '';
                  final path = person['profile_path']?.toString();
                  final imageUrl = path == null || path.isEmpty
                      ? null
                      : 'https://image.tmdb.org/t/p/w185$path';
                  return SizedBox(
                    width: 86.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            width: 86.w,
                            height: 94.h,
                            color: AppColors.surface,
                            child: imageUrl == null
                                ? const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.secondary,
                                    size: 32,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    memCacheHeight: 320,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (character.isNotEmpty)
                          Text(
                            character,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 8.sp,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    },
  );

  String _tmdbCertification(Map<String, dynamic> details) {
    final key = widget.content.isMovie ? 'release_dates' : 'content_ratings';
    final collection = details[key];
    if (collection is! Map || collection['results'] is! List) return '';
    final rows = (collection['results'] as List).whereType<Map>();
    for (final row in rows) {
      if (row['iso_3166_1'] != 'ID') continue;
      if (widget.content.isMovie) {
        final dates = row['release_dates'];
        if (dates is! List) continue;
        for (final date in dates.whereType<Map>()) {
          final certification = date['certification']?.toString().trim() ?? '';
          if (certification.isNotEmpty) return certification;
        }
      } else {
        final rating = row['rating']?.toString().trim() ?? '';
        if (rating.isNotEmpty) return rating;
      }
    }
    return '';
  }

  Future<void> _openYoutubeTrailer(String key) async {
    final uri = Uri.https('www.youtube.com', '/watch', {'v': key});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _watchProvidersSection() => FutureBuilder<Map<String, dynamic>?>(
    future: _providersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.red),
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi penyedia streaming Indonesia belum tersedia.',
              style: TextStyle(color: AppColors.secondary, fontSize: 11.sp),
            ),
            TextButton(
              onPressed: () => _openProvider('https://www.justwatch.com/id'),
              child: const Text('JustWatch'),
            ),
          ],
        );
      }

      const groups = <String, String>{
        'flatrate': 'SUBSCRIPTION',
        'free': 'FREE',
        'ads': 'WITH ADS',
        'rent': 'RENT',
        'buy': 'BUY',
      };
      final providerWidgets = <Widget>[];
      for (final entry in groups.entries) {
        final rows = data[entry.key];
        if (rows is! List || rows.isEmpty) continue;
        providerWidgets.add(
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 7.h),
            child: Text(
              entry.value,
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
          ),
        );
        providerWidgets.add(
          Wrap(
            spacing: 7.w,
            runSpacing: 7.h,
            children: rows.whereType<Map>().map((row) {
              final name = row['provider_name']?.toString() ?? 'Streaming service';
              return Chip(
                label: Text(name, style: TextStyle(fontSize: 10.sp)),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.surface3),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        );
      }

      final link = data['link']?.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHERE TO WATCH • INDONESIA',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          SizedBox(height: 5.h),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.secondary,
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  'Availability data provided by JustWatch.',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 9.sp,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openProvider('https://www.justwatch.com/id'),
                child: const Text('JustWatch'),
              ),
            ],
          ),
          if (providerWidgets.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 9.h),
              child: Text(
                'Belum ada data penyedia resmi untuk judul ini di wilayah Indonesia.',
                style: TextStyle(color: AppColors.secondary, fontSize: 11.sp),
              ),
            )
          else
            ...providerWidgets,
          if (link != null && link.startsWith('https://'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openProvider(link),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('View official availability'),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _openProvider(String? value) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> get _availableQualities {
    const order = ['360p', '480p', '720p', '1080p', '4K'];
    return order.where((quality) {
      return widget.content.sources.values.any((source) {
        final raw = source[quality]?.trim() ?? '';
        final uri = Uri.tryParse(raw);
        return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
      });
    }).toList(growable: false);
  }

  int get _configuredSourceCount => [
    'server1',
    'server2',
    'server3',
    'server4',
    'server5',
  ].where(_hasUsableSource).length;

  bool _hasUsableSource(String id) {
    final source = widget.content.sources[id];
    if (source == null) return false;
    return ['360p', '480p', '720p', '1080p', '4K'].any((quality) {
      final value = source[quality]?.trim() ?? '';
      final uri = Uri.tryParse(value);
      return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    });
  }

  List<Widget> _serverList() {
    const ids = ['server1', 'server2', 'server3', 'server4', 'server5'];
    final names = {
      'server1': 'Primary • Adaptive Stream',
      'server2': 'Backup • MP4 Origin',
      'server3': 'Custom Origin 1',
      'server4': 'Custom Origin 2',
      'server5': 'Emergency Mirror',
    };
    final configured = ids.where(_hasUsableSource).toList(growable: false);
    if (configured.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(
            'Belum ada sumber streaming resmi yang dikonfigurasi.',
            style: TextStyle(color: AppColors.secondary, fontSize: 11.sp),
          ),
        ),
      ];
    }
    return configured.map((id) {
      final selected = _serverId == id;
      return Padding(
        padding: EdgeInsets.only(bottom: 7.h),
        child: InkWell(
          onTap: () => setState(() => _serverId = id),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.red.withValues(alpha: .11)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: selected ? AppColors.red : AppColors.surface3,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined, color: AppColors.blue, size: 17),
                SizedBox(width: 9.w),
                Expanded(
                  child: Text(
                    names[id]!,
                    style: TextStyle(fontSize: 12.sp, color: Colors.white),
                  ),
                ),
                const Text(
                  'AVAILABLE',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.red : AppColors.secondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _tag(String label) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Text(
      label,
      style: TextStyle(color: AppColors.secondary, fontSize: 12.sp),
    ),
  );
}
