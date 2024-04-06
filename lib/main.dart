import 'package:deadlines/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/deadlines_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.manageExternalStorage.request();

  runApp(const MainApp());
}

// // overlay entry point
// @pragma("vm:entry-point")
// void overlayMain() {
//   runApp(const MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: AlarmBanner(),
//   ));
// }

class MainApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MainApp({super.key});

  @override State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final Future<void> notifyInit = staticNotify.init();

  @override Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MainApp.navigatorKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en', 'GB'),],
      title: 'deadlines',
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyanAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,


      initialRoute: '/',
      onGenerateRoute: (settings) {
        var route = staticNotify.handleRoute(settings.name, settings.arguments);
        if(route != null) return route;

        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (context) {
              return FutureBuilder(
                future: notifyInit,
                builder: (context, snapshot) {
                  if(snapshot.hasData) {
                    // const TestAlarmsScreen()
                    return const DeadlinesDisplay();
                  } else {
                    return Container();
                  }
                },
              );
            });

          default:
            assert(false, 'Page ${settings.name} not found');
            return null;
        }
      },
    );
  }
}
