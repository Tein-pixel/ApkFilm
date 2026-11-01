import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/app_theme.dart';
import '../data/models/media_content.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.content, required this.onTap});
  final MediaContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 115.w,
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'poster-${content.id}',
          child:
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _poster(),
                    Positioned(
                      top: 7.h,
                      left: 7.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          content.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8.w,
                      right: 6.w,
                      bottom: 8.h,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '${content.year} • ${content.duration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().scale(
                begin: const Offset(.98, .98),
                end: const Offset(1, 1),
                duration: 160.ms,
                curve: Curves.easeOut,
              ),
        ),
      ),
    );
  }

  Widget _poster() {
    final url = content.poster?.trim() ?? '';
    if (url.isEmpty) return _posterPlaceholder();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheHeight: 900,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => _posterPlaceholder(),
      errorWidget: (_, __, ___) => _posterPlaceholder(),
    );
  }

  Widget _posterPlaceholder() => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF162B4D), Color(0xFF7A251E), Color(0xFF080808)],
          ),
        ),
      ),
      Opacity(
        opacity: .18,
        child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
      ),
      const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 38,
          color: Colors.white54,
        ),
      ),
    ],
  );
}
