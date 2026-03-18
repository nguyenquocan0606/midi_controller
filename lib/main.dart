import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'stores/connection_provider.dart';
import 'screens/mixer_page.dart';
import 'screens/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock landscape orientation cho iPad mixer
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Ẩn status bar cho immersive experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MidiControllerApp());
}

class MidiControllerApp extends StatelessWidget {
  const MidiControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ],
      child: MaterialApp(
        title: 'MIDI Controller',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const MixerPage(),
          '/settings': (context) => const SettingsPage(),
        },
      ),
    );
  }
}
