import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/app_theme.dart';
import 'core/server_manager.dart';
import 'data/repositories/catalog_repository.dart';
import 'features/library/library_cubit.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<dynamic>('cineflix_library');
  runApp(CineflixApp(libraryBox: box));
}

class CineflixApp extends StatelessWidget {
  const CineflixApp({super.key, required this.libraryBox});
  final Box<dynamic> libraryBox;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider(create: (_) => CatalogRepository()),
      RepositoryProvider<ServerManager>(
        create: (_) => ServerManager(),
        dispose: (manager) => manager.dispose(),
      ),
    ],
    child: BlocProvider(
      create: (_) => LibraryCubit(libraryBox),
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, child) => MaterialApp(
          title: 'CINEFLIX Ultra Premium',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: child,
        ),
        child: const SplashScreen(),
      ),
    ),
  );
}
