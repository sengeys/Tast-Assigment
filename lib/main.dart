// ចំណុចចាប់ផ្តើមនៃ App
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'កម្មវិធីចាត់ព្រះសង្ឃទៅបុណ្យ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal, 
        useMaterial3: true,
        fontFamily: 'NotoSansKhmer',
      ),
      home: const HomeScreen(),
    );
  }
}
