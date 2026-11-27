// ចំណុចចាប់ផ្តើមនៃ App
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/notification_inbox_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize(
    onNotificationTap: () {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const NotificationInboxScreen(),
        ),
      );
    },
  );
  await NotificationService.instance.rescheduleAll();
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) {
        final state = AppState();
        state.load();
        return state;
      },
      child: const TaskApp(),
    ),
  );
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = ColorScheme.fromSeed(seedColor: appState.themeSeed);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'កម្មវិធីចាត់ព្រះសង្ឃទៅបុណ្យ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        fontFamily: 'NotoSansKhmer',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(
            color: Color(0xFF9696A0),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          floatingLabelStyle: TextStyle(
            color: colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          hintStyle: TextStyle(
            color: Color(0xFF787885),
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.44,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFB4B4BB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFB4B4BB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFFB4B4BB)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
