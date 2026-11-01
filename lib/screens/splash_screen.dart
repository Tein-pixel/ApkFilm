import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2500), _openHome);
  }

  void _openHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/app_logo.png', width: 140.w, height: 140.w)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1200.ms,
              )
              .fade(begin: .9, end: 1, duration: 1200.ms),
          SizedBox(height: 26.h),
          Image.asset(
                'assets/images/splash_reel.png',
                width: 112.w,
                height: 82.h,
              )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 5000.ms),
          SizedBox(height: 18.h),
          const Text(
            'Loading Open Movies...',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          SizedBox(height: 14.h),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.w,
            children: List.generate(
              5,
              (index) =>
                  Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fade(
                        begin: .22,
                        end: 1,
                        delay: (index * 140).ms,
                        duration: 750.ms,
                      ),
            ),
          ),
        ],
      ),
    ),
  );
}
