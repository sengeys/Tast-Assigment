// អេក្រង់មើលសារ និង Copy
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// ---------------- 4. Preview & Copy ----------------
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final msg = s.buildMessage();
    return Scaffold(
      appBar: AppBar(title: const Text('មើលសារ')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                      child: SelectableText(msg,
                          style: const TextStyle(fontSize: 16, height: 1.3))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(s.editingId == null
                      ? 'Copy សារ និងរក្សាទុកប្រវត្តិ'
                      : 'Copy សារ និងរក្សាទុកការកែប្រែ'),
                  onPressed: () async {
                    if (s.preachDharma && s.selectedPreachers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'សូមជ្រើសរើសព្រះសង្ឃសម្រាប់សម្ដែងធម្មទេសនា',
                          ),
                        ),
                      );
                      return;
                    }
                    if (s.preceptsType != null &&
                        s.selectedPreceptGivers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'សូមជ្រើសរើសព្រះសង្ឃសម្រាប់ប្រទានសីល',
                          ),
                        ),
                      );
                      return;
                    }
                    final ok = await s.copyAndSave();
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                          'ព្រះសង្ឃ ឬអាចារ្យជាន់ពេលគ្នា — មិនបានរក្សាទុក',
                        ),
                      ));
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('បាន Copy និងរក្សាទុកប្រវត្តិរួចរាល់ ✔')));
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
