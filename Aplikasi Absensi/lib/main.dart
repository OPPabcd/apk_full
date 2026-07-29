import 'package:flutter/material.dart';
import 'package:scaled_app/scaled_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apk/firebase_options.dart';
import 'package:apk/register/page1.dart';
import 'package:apk/dashboard/a_admin/dashboard/class.dart';
import 'package:apk/dashboard/a_admin/dashboard/announcement.dart';
import 'package:apk/dashboard/a_admin/dashboard/add_person.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:apk/dashboard/a_admin/bottom_bar/main_screen.dart';
import 'package:apk/register/admin/login_screen.dart';
import 'package:apk/register/admin/signup_screen.dart';
import 'package:apk/session_timer/session_time.dart';
import 'package:apk/dashboard/a_admin/function/f_notif/notif_reddot.dart';
import 'package:apk/dashboard/d_c_murid/function/FCM_absen.dart/fcm_notif.dart' as fcm_absen;

double scaleFactorCallback(Size deviceSize) {
  const double widthOfDesign = 375;
  return deviceSize.width / widthOfDesign;
}

Future<void> main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized(
    scaleFactor: scaleFactorCallback,
  );

  await dotenv.load(fileName: "lib/.env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 1. Initialize Firebase FIRST dengan options yang benar (seperti apk2/apk3)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Initialized successfully');
  } catch (e) {
    debugPrint('[Firebase] Initialization error: $e');
  }

  // 2. Removed Entrig Initialization

  // 3. Initialize notification listeners
  try {
    await NotifRedDot.init();
    await fcm_absen.NotificationFCM.init();
  } catch (_) {
    // FCM tidak tersedia di platform ini (misal: Web)
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCMTokenRegistration();
  }

  /// Daftarkan perangkat ke Supabase secara persisten menggunakan FCM langsung
  void _setupFCMTokenRegistration() async {
    await _registerStoredUserDevice();

    // Listener Supabase Auth (khusus role Admin)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (session != null && userRole == 'admin') {
        final userId = session.user.id;
        await fcm_absen.NotificationFCM.saveTokenToSupabase(userId, 'admin');
      }
    });
  }

  Future<void> _registerStoredUserDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'admin') {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && userId.isNotEmpty) {
          await fcm_absen.NotificationFCM.saveTokenToSupabase(userId.trim(), 'admin');
        }
      } else if (userRole == 'guru') {
        final guruId = prefs.getString('guru_id_tabel');
        if (guruId != null && guruId.isNotEmpty) {
          await fcm_absen.NotificationFCM.saveTokenToSupabase(guruId.trim(), 'guru');
        }
      } else if (userRole == 'murid' || userRole == 'ortu') {
        final muridId = prefs.getString('murid_id_tabel');

        if (muridId != null && muridId.isNotEmpty) {
          await fcm_absen.NotificationFCM.saveTokenToSupabase(muridId.trim(), 'murid');
        }
      }
    } catch (e) {
      debugPrint('[FCM] Persistent token registration error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotifRedDot.navigatorKey,
      builder: (context, child) {
        final originalMediaQueryData = MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        );
        return SessionTimeManager(
          child: MediaQuery(
            data: originalMediaQueryData.scale(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const Home(),
        '/load_screen/login_screen': (context) => const LoginAdmin(),
        '/load_screen/signup_screen': (context) => const SignupAdmin(),
        '/page1': (context) => const Home(),
        '/load_screen': (context) => const MainScreen(),
        '/dashboard/class': (context) => const DaftarKelas(),
        '/dashboard/announcement': (context) => const Pengumuman(),
        '/dashboard/add_person': (context) => const TambahPengguna(),
      },
    );
  }
}