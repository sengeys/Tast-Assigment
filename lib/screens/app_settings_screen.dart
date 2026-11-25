import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  static const _themeNames = [
    'បៃតងខៀវ',
    'ខៀវ',
    'ស្វាយ',
    'ទឹកក្រូច',
    'ពណ៌ទឹកក្រូច',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedIndex = AppState.themeSeeds.indexOf(state.themeSeed);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('រូបរាង Theme'),
            subtitle: Text('ជ្រើសរើសពណ៌សម្រាប់កម្មវិធី'),
          ),
          for (var index = 0; index < AppState.themeSeeds.length; index++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppState.themeSeeds[index],
                radius: 14,
              ),
              title: Text(_themeNames[index]),
              trailing: selectedIndex == index
                  ? const Icon(Icons.check_circle)
                  : null,
              selected: selectedIndex == index,
              onTap: () => state.setThemeSeed(index),
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('ភាសា'),
            subtitle: Text('ខ្មែរ'),
          ),
        ],
      ),
    );
  }
}
