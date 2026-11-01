import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../data/models/media_content.dart';
import '../data/repositories/catalog_repository.dart';
import '../features/library/library_cubit.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _heroController = PageController(viewportFraction: .92);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<MediaContent>? _searchResults;
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchHasMore = true;
  int _searchPage = 1;
  String _selectedExploreFilter = 'All';
  Timer? _autoSlide;
  late Future<List<MediaContent>> _catalogFuture;
  int _selectedTab = 0;
  bool _dataSaver = false;
  int _heroCount = 1;

  @override
  void initState() {
    super.initState();
    _catalogFuture = context.read<CatalogRepository>().loadCatalog();
    _loadSettings();
    _autoSlide = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_selectedTab != 0 || !_heroController.hasClients) return;
      final next = ((_heroController.page ?? 0).round() + 1) % _heroCount;
      await _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _dataSaver = prefs.getBool('data_saver') ?? false);
  }

  Future<void> _setDataSaver(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_saver', value);
    if (mounted) setState(() => _dataSaver = value);
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: FutureBuilder<List<MediaContent>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return _errorState(
              onRetry: () => setState(
                () => _catalogFuture = context
                    .read<CatalogRepository>()
                    .loadCatalog(),
              ),
            );
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppColors.red),
            );
          final items = snapshot.data!;
          _heroCount = items.length.clamp(1, 10000).toInt();
          if (items.isEmpty)
            return const Center(
              child: Text('No titles in the local catalogue.'),
            );
          return _selectedTab == 0 ? _home(items) : _otherTab(items);
        },
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 62.h,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.red.withValues(alpha: .15),
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
      destinations: [
        NavigationDestination(
          icon: _navIcon('home', false),
          selectedIcon: _navIcon('home', true),
          label: 'Home',
        ),
        NavigationDestination(
          icon: _navIcon('explore', false),
          selectedIcon: _navIcon('explore', true),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: _navIcon('list', false),
          selectedIcon: _navIcon('list', true),
          label: 'My List',
        ),
        NavigationDestination(
          icon: _navIcon('profile', false),
          selectedIcon: _navIcon('profile', true),
          label: 'Profile',
        ),
      ],
    ),
  );

  Widget _navIcon(String name, bool selected) => SvgPicture.asset(
    'assets/icons/nav_$name.svg',
    width: 23.w,
    height: 23.w,
    colorFilter: ColorFilter.mode(
      selected ? AppColors.red : AppColors.secondary,
      BlendMode.srcIn,
    ),
  );

  Widget _home(List<MediaContent> items) {
    final library = context.watch<LibraryCubit>();
    final saved = items.where((item) => library.contains(item.id)).toList();
    final historyItems = <MediaContent>[];
    for (final id in library.history) {
      for (final item in items) {
        if (item.id == id) {
          historyItems.add(item);
          break;
        }
      }
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar()),
        SliverToBoxAdapter(child: _hero(items)),
        SliverToBoxAdapter(
          child: _sectionHeader('Continue Watching', 'Resume'),
        ),
        SliverToBoxAdapter(
          child: historyItems.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 14.h),
                  child: Text(
                    'Your watch history will appear here.',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10.sp,
                    ),
                  ),
                )
              : SizedBox(
                  height: 104.h,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    scrollDirection: Axis.horizontal,
                    itemCount: historyItems.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (_, index) =>
                        _continueCard(historyItems[index]),
                  ),
                ),
        ),
        SliverToBoxAdapter(
          child: _sectionHeader(
            'Movies & Series',
            '${items.length} titles',
          ),
        ),
        SliverToBoxAdapter(child: _movieRow(items)),
        SliverToBoxAdapter(
          child: _sectionHeader('My List', '${saved.length} saved'),
        ),
        SliverToBoxAdapter(
          child: saved.isEmpty
              ? Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 25.h),
                  child: Text(
                    'Save a title from its detail page to see it here.',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11.sp,
                    ),
                  ),
                )
              : _movieRow(saved),
        ),
        SliverToBoxAdapter(child: _footerNote()),
      ],
    );
  }

  Widget _otherTab(List<MediaContent> items) {
    if (_selectedTab == 2) {
      final savedIds = context.watch<LibraryCubit>().myList.toSet();
      final saved = items.where((item) => savedIds.contains(item.id)).toList();
      return _catalogTab(
        'My List',
        saved,
        emptyMessage: 'Your saved titles will appear here.',
      );
    }
    if (_selectedTab == 3) return _profileTab();
    return _catalogTab('Explore', items, isExplore: true);
  }

  Widget _catalogTab(
    String title,
    List<MediaContent> items, {
    String emptyMessage = 'No titles available.',
    bool isExplore = false,
  }) {
    final displayed = isExplore ? _filteredExploreItems(items) : items;
    const filters = [
      'All', 'Movies', 'Series', 'Drama', 'Anime',
      'K-Drama', 'C-Drama', 'Thai Drama', 'Taiwanese Drama',
      'Indonesian Drama', 'Filipino Drama', 'Indian Drama', 'Japanese Drama',
    ];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 23.sp, fontWeight: FontWeight.w800)),
                if (isExplore) ...[
                  SizedBox(height: 14.h),
                  TextField(
                    controller: _searchController,
                    onChanged: _onExploreSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search movies, series, anime, drama...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onExploreSearchChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 11.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((filter) {
                        final selected = _selectedExploreFilter == filter;
                        return Padding(
                          padding: EdgeInsets.only(right: 7.w),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedExploreFilter = filter),
                            selectedColor: AppColors.red.withValues(alpha: .25),
                            side: BorderSide(color: selected ? AppColors.red : AppColors.surface3),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.secondary,
                              fontSize: 10.sp,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_searchLoading)
                    Padding(
                      padding: EdgeInsets.only(top: 10.h),
                      child: const LinearProgressIndicator(minHeight: 2, color: AppColors.red),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (displayed.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                isExplore && _searchController.text.trim().isNotEmpty
                    ? (_searchLoading ? 'Searching TMDB...' : 'No results found.')
                    : emptyMessage,
                style: const TextStyle(color: AppColors.secondary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 24.h),
            sliver: SliverGrid.builder(
              itemCount: displayed.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 115 / 170,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 12.h,
              ),
              itemBuilder: (_, index) => MovieCard(
                content: displayed[index],
                onTap: () => _openDetail(displayed[index]),
              ),
            ),
          ),
        if (isExplore && _searchController.text.trim().isNotEmpty && _searchHasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 22.h),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _searchLoadingMore ? null : _loadMoreSearchResults,
                  icon: _searchLoadingMore
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_searchLoadingMore ? 'Loading...' : 'Load more results'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<MediaContent> _filteredExploreItems(List<MediaContent> items) {
    final source = _searchController.text.trim().isEmpty
        ? items
        : (_searchResults ?? const <MediaContent>[]);
    switch (_selectedExploreFilter) {
      case 'Movies':
        return source.where((item) => item.type == 'movie').toList();
      case 'Series':
        return source.where((item) => item.type == 'tv').toList();
      case 'Drama':
        return source.where((item) => item.categories.any(
          (category) => category.toLowerCase() == 'drama',
        )).toList();
      case 'Anime':
      case 'K-Drama':
      case 'C-Drama':
      case 'Thai Drama':
      case 'Taiwanese Drama':
      case 'Indonesian Drama':
      case 'Filipino Drama':
      case 'Indian Drama':
      case 'Japanese Drama':
        return source.where((item) => item.categories.contains(_selectedExploreFilter)).toList();
      default:
        return source;
    }
  }

  void _onExploreSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _searchPage = 1;
        _searchHasMore = true;
        _searchLoading = false;
        _searchLoadingMore = false;
      });
      return;
    }
    setState(() {
      _searchResults = null;
      _searchPage = 1;
      _searchHasMore = true;
      _searchLoading = true;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _performExploreSearch(query, page: 1),
    );
  }

  Future<void> _performExploreSearch(String query, {required int page}) async {
    try {
      final results = await context.read<CatalogRepository>().searchCatalog(
        query,
        page: page,
      );
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        if (page == 1) {
          _searchResults = results;
        } else {
          final merged = <String, MediaContent>{
            for (final item in (_searchResults ?? const <MediaContent>[]))
              item.id: item,
          };
          for (final item in results) {
            merged[item.id] = item;
          }
          _searchResults = merged.values.toList(growable: false);
        }
        _searchPage = page;
        _searchHasMore = results.isNotEmpty && page < 500;
        _searchLoading = false;
        _searchLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        if (page == 1) _searchResults = const [];
        _searchHasMore = false;
        _searchLoading = false;
        _searchLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (_searchLoadingMore || !_searchHasMore) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searchLoadingMore = true);
    await _performExploreSearch(query, page: _searchPage + 1);
  }

  Widget _profileTab() => ListView(
    padding: EdgeInsets.all(20.w),
    children: [
      SizedBox(height: 10.h),
      Image.asset('assets/images/app_logo.png', width: 84.w, height: 84.w),
      SizedBox(height: 14.h),
      Text(
        'CINEWAVE',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
      ),
      Text(
        'Version 7.1.0 • Movies & Series',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.sp, color: AppColors.secondary),
      ),
      SizedBox(height: 24.h),
      SwitchListTile(
        title: const Text('Data Saver'),
        subtitle: const Text('Prefer 480p on mobile networks'),
        value: _dataSaver,
        activeColor: AppColors.red,
        onChanged: _setDataSaver,
      ),
      const Divider(),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('About this build'),
        subtitle: Text(
          'Five server slots are included. Only sources with an authorized URL in the catalogue can play.',
        ),
      ),
      const ListTile(
        leading: Icon(Icons.copyright_outlined),
        title: Text('Content credits'),
        subtitle: Text(
          'Big Buck Bunny, Tears of Steel, Sintel, Spring and Sprite Fright are Blender open-movie projects. Check each source licence before redistribution.',
        ),
      ),
      Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.surface3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SvgPicture.network(
                'https://www.themoviedb.org/assets/2/v4/logos/v2/blue_square_2-d537fb228cf3ded904ef09b136fe3fec72548ebc1fea3fbbd1ad9e36364db38b.svg',
                width: 42.w,
                height: 42.w,
                placeholderBuilder: (_) => SizedBox(
                  width: 42.w,
                  height: 42.w,
                  child: const Center(child: Icon(Icons.movie_outlined)),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            const Text(
              'This product uses the TMDB API but is not endorsed or certified by TMDB.',
              style: TextStyle(color: AppColors.secondary, fontSize: 11, height: 1.45),
            ),
            SizedBox(height: 5.h),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.themoviedb.org'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('The Movie Database'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const ListTile(
        leading: Icon(Icons.link_rounded),
        title: Text('JustWatch attribution'),
        subtitle: Text(
          'Streaming availability data is provided by JustWatch through TMDB.',
        ),
      ),
      const ListTile(
        leading: Icon(Icons.security_outlined),
        title: Text('Privacy'),
        subtitle: Text(
          'No account is required. Playback progress and My List are stored locally on this device.',
        ),
      ),
    ],
  );

  Widget _topBar() => Padding(
    padding: EdgeInsets.fromLTRB(18.w, 13.h, 18.w, 12.h),
    child: Row(
      children: [
        Image.asset('assets/images/app_logo.png', width: 34.w, height: 34.w),
        SizedBox(width: 9.w),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'CINE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              TextSpan(
                text: 'WAVE',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => _selectedTab = 1),
          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 23),
        ),
        IconButton(
          onPressed: () => setState(() => _selectedTab = 3),
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    ),
  );

  Widget _hero(List<MediaContent> items) => Column(
    children: [
      SizedBox(
        height: 220.h,
        child: PageView.builder(
          controller: _heroController,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final imageUrl = item.backdrop?.trim().isNotEmpty == true
                ? item.backdrop!.trim()
                : item.poster?.trim() ?? '';
            return GestureDetector(
              onTap: () => _openDetail(item),
              child: Container(
                margin: EdgeInsets.only(right: 9.w),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1B2235),
                      Color(0xFF251015),
                      Color(0xFF060606),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: .14),
                      blurRadius: 22,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheHeight: 900,
                          placeholder: (_, __) => const SizedBox.expand(),
                          errorWidget: (_, __, ___) => const SizedBox.expand(),
                        ),
                      ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.black12,
                              Color(0xAA07090D),
                              Color(0xF507090D),
                            ],
                            stops: [0, .42, 1],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black26,
                              Colors.transparent,
                              Colors.black87,
                            ],
                            stops: [0, .4, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -28.w,
                      top: -15.h,
                      child: Icon(
                        Icons.movie_filter_outlined,
                        size: 230.w,
                        color: Colors.white.withValues(alpha: .045),
                      ),
                    ),
                    Positioned(
                      left: 20.w,
                      right: 20.w,
                      bottom: 18.h,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              'FEATURED TITLE',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 23.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            '${item.year}  •  ${item.duration}  •  ${item.categories.isNotEmpty ? item.categories.first : 'Open Movie'}',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10.sp,
                            ),
                          ),
                          SizedBox(height: 13.h),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () => _openDetail(item),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: const Text('Watch now'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 15.w,
                                    vertical: 9.h,
                                  ),
                                ),
                              ),
                              SizedBox(width: 9.w),
                              Text(
                                item.isTmdb ? 'TMDB • Metadata' : 'Open Content',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 9.sp,
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
            );
          },
        ),
      ),
      SizedBox(height: 12.h),
      SmoothPageIndicator(
        controller: _heroController,
        count: items.length,
        effect: ExpandingDotsEffect(
          activeDotColor: AppColors.red,
          dotColor: Colors.white24,
          dotHeight: 5.h,
          dotWidth: 5.w,
          expansionFactor: 3,
        ),
      ),
      SizedBox(height: 19.h),
    ],
  );

  Widget _sectionHeader(String title, String trailing) => Padding(
    padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 12.h),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(color: AppColors.secondary, fontSize: 9.sp),
        ),
      ],
    ),
  );

  Widget _movieRow(List<MediaContent> items) => SizedBox(
    height: 190.h,
    child: ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(width: 10.w),
      itemBuilder: (_, index) => MovieCard(
        content: items[index],
        onTap: () => _openDetail(items[index]),
      ),
    ),
  );

  Widget _continueCard(MediaContent item) {
    final seconds = context.watch<LibraryCubit>().progress[item.id] ?? 0;
    return GestureDetector(
      onTap: () => _openDetail(item, resume: true),
      child: Container(
        width: 205.w,
        padding: EdgeInsets.all(11.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(5.r),
              child: LinearProgressIndicator(
                value: seconds > 0
                    ? (seconds / 600).clamp(0.0, .98).toDouble()
                    : 0,
                minHeight: 3.h,
                backgroundColor: AppColors.surface3,
                color: AppColors.red,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              seconds > 0
                  ? 'Resume at ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                  : 'Not started',
              style: TextStyle(fontSize: 8.sp, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerNote() => Padding(
    padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 24.h),
    child: Text(
      'Discover movies, TV series, anime and regional dramas. Playback requires an authorized video source. This product uses the TMDB API but is not endorsed or certified by TMDB.',
      style: TextStyle(fontSize: 9.sp, color: AppColors.tertiary, height: 1.4),
    ),
  );
  Widget _errorState({required VoidCallback onRetry}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          color: AppColors.secondary,
          size: 42,
        ),
        const SizedBox(height: 12),
        const Text('Could not load the catalogue.'),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
  void _openDetail(MediaContent item, {bool resume = false}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailScreen(content: item, resume: resume),
        ),
      );
}
