import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/main_page.dart';
import 'injection_container.dart' as di;

import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/stock/presentation/bloc/stock_bloc.dart';
import 'features/pos/presentation/bloc/pos_bloc.dart';
import 'features/receivable/presentation/bloc/receivable_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/notification/presentation/bloc/notification_bloc.dart';
import 'features/notification/presentation/bloc/notification_event.dart';
import 'features/history/presentation/pages/history_page.dart';
import 'features/splash/presentation/pages/splash_page.dart'; // Import Splash

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'core/services/printer_service.dart'; // Import PrinterService
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppStarter());
}

class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. System UI
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    // 2. Database for Desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 3. Env
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Error loading .env file: $e");
      dotenv.testLoad(fileInput: '');
    }

    // 4. Dependency Injection (Crucial)
    try {
      await di.init();
      // Auto-reconnect Bluetooth printer on startup without awaiting to prevent blocking
      di.sl<PrinterService>().ensureConnected();
    } catch (e) {
      debugPrint("DI Init Error: $e");
    }

    // 5. Locale
    await initializeDateFormatting('id_ID', null);

    // 6. Firebase & Notifications
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService().initialize();
    } catch (e) {
      debugPrint("Firebase/Notification initialization failed: $e");
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider(
          create: (_) => di.sl<ProductBloc>(),
        ),
        BlocProvider(
          create: (_) => di.sl<StockBloc>(),
        ),
        BlocProvider(
          create: (_) => di.sl<PosBloc>(),
        ),
        BlocProvider(
          create: (_) => di.sl<ReceivableBloc>(),
        ),
        BlocProvider(
          create: (_) => di.sl<DashboardBloc>(),
        ),
        BlocProvider(
          create: (_) => di.sl<NotificationBloc>()..add(LoadNotifications()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Kasir App Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'),
        ],
        home: const AuthWrapper(),
        routes: {
          '/history': (context) => const HistoryPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const MainPage();
        }
        return const LoginPage();
      },
    );
  }
}
