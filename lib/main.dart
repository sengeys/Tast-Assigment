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
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'កម្មវិធីចាត់ព្រះសង្ឃទៅបុណ្យ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: appState.themeSeed,
        useMaterial3: true,
        fontFamily: 'NotoSansKhmer',
        filledButtonTheme: appState.usesCustomOrangeTheme
            ? FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7643),
                  foregroundColor: const Color(0xFFFFFFFF),
                ),
              )
            : null,
        elevatedButtonTheme: appState.usesCustomOrangeTheme
            ? ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7643),
                  foregroundColor: const Color(0xFFFFFFFF),
                ),
              )
            : null,
        chipTheme: appState.usesCustomOrangeTheme
            ? ChipThemeData(
                backgroundColor: const Color(0xFFFFECDF),
                selectedColor: const Color(0xFFFFECDF),
                labelStyle: const TextStyle(color: Color(0xFFFF7643)),
                secondaryLabelStyle: const TextStyle(color: Color(0xFFFF7643)),
                checkmarkColor: const Color(0xFFFF7643),
                side: const BorderSide(color: Color(0xFFFF7643)),
              )
            : null,
      ),
      home: const HomeScreen(),
    );
  }
}
