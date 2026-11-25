import 'package:material_ui/material_ui.dart';

import 'core/theme/stageline_theme.dart';
import 'features/setlists/setlist_list_screen.dart';

class StageLineApp extends StatelessWidget {
  const StageLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StageLine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: StageLineTheme.buildDarkTheme(),
      home: const SetlistListScreen(),
    );
  }
}
