import 'package:deadlines/notifications/alarm_external_wrapper/notify_wrapper.dart';
import 'package:deadlines/ui/widgets/controller.dart';
import 'package:deadlines/ui/widgets/months.dart';
import 'package:deadlines/ui/widgets/upcoming_list.dart';
import 'package:deadlines/ui/widgets/years.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.manageExternalStorage.request();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MainApp({super.key});

  @override State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final Future<void> notifyInit = staticNotify.init();
  final ParentController parent = ParentController();
  late final UpcomingDeadlinesListController upcomingController = UpcomingDeadlinesListController(parent);
  late final DeadlinesCalendarController calendarController = DeadlinesCalendarController(parent);
  late final DeadlinesInYearsController yearsController = DeadlinesInYearsController(parent);

  @override Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MainApp.navigatorKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en', 'GB'),],
      title: 'deadlines',
      theme: ThemeData(
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
                future: Future.wait([notifyInit, upcomingController.init(), calendarController.init(), yearsController.init()]),
                builder: (context, snapshot) {
                  if(snapshot.hasData) {
                    // const TestAlarmsScreen()
                    return PageView.builder(
                      controller: PageController(initialPage: 100000),
                      itemBuilder: (context, index) {
                        if (index % 2 == 0) {
                          return DeadlinesCalendar(calendarController);
                        } else {
                          return UpcomingDeadlinesList(upcomingController);
                        }
                      },
                    );
                  } else {
                    return Container();
                  }
                },
              );
            });
          case '/years':
            return MaterialPageRoute(builder: (context) {
              return YearsPage(yearsController, initialYear: settings.arguments as int,);
            });

          default:
            assert(false, 'Page ${settings.name} not found');
            return null;
        }
      },
    );
  }
}
