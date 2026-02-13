import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:chatlytica/analytic_service.dart';
import 'package:chatlytica/firebase_options.dart';
import 'package:chatlytica/model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool loading = false;
  AnalyticsResult? analyticsResult;
  String? path;

  StreamSubscription? _sub;

  Future<void> analysisFile(String path) async {
    try {
      FirebaseCrashlytics.instance.log("Mulai analisis");
      final file = File(path);
      if (path.toLowerCase().split('.').last == 'zip') {
        FirebaseCrashlytics.instance.log("Mulai extract file");
        final extractPath = await extractZip(file);
        logger.info('Extracted to path: $extractPath');
        FirebaseCrashlytics.instance.log("File di extract ke $extractPath");
        final txtfile = File(extractPath);
        if (await txtfile.exists()) {
          FirebaseCrashlytics.instance.log("Mulai baca file text");
          final content = await txtfile.readAsString();
          FirebaseCrashlytics.instance.log("Selesai baca file text");
          FirebaseCrashlytics.instance.log("Mulai Parsing");
          final lines = parseChat(content);
          FirebaseCrashlytics.instance.log("selesai Parsing");
          if (lines.isEmpty) {
            setState(() {
              path = "It is not a chat file";
            });
            logger.warning('No chat messages found in the file.');
            FirebaseCrashlytics.instance.log("No chat messages found in the file.");
            return;
          }
          FirebaseCrashlytics.instance.log("Mulai Analisis Service");

          final analyticResult = AnalyticsService(lines.firstWhere((element) => element.sender != null).sender!);
          FirebaseCrashlytics.instance.log("Selesai Analisis Service");
          final analyseResult = analyticResult.analyze(lines);
          FirebaseCrashlytics.instance.log("Selesai Analisis Service variabel");
          setState(() {
            path = extractPath;
            analyticsResult = analyseResult;
          });
          logger.info('Analysis Result: ${analyseResult.stability}');
          FirebaseCrashlytics.instance.log("Analisis berhasil");
          return;
        } else {
          setState(() {
            path = "No text file found in the extracted zip.";
          });
          return;
        }
      } else {
        // kalau filenya txt
        logger.info('Selected path: ${file.path}');
        FirebaseCrashlytics.instance.log("File TXT dibaca");
        final content = await file.readAsString();
        FirebaseCrashlytics.instance.log("File TXT selesai dibaca");
        FirebaseCrashlytics.instance.log("File TXT mulai di parsing");
        final lines = parseChat(content);
        FirebaseCrashlytics.instance.log("File TXT selesai di parsing");
        if (lines.isEmpty) {
          setState(() {
            path = "It is not a chat file";
          });
          logger.warning('No chat messages found in the file.');
          FirebaseCrashlytics.instance.log("File TXT tidak ditemukan chat");

          return;
        }
        FirebaseCrashlytics.instance.log("File TXT muali analisis service");
        final analyticResult = AnalyticsService(lines.firstWhere((element) => element.sender != null).sender!);
        FirebaseCrashlytics.instance.log("File TXT selesai analisis service");
        FirebaseCrashlytics.instance.log("File TXT mulai analisis service variabel");
        final analyseResult = analyticResult.analyze(lines);
        FirebaseCrashlytics.instance.log("File TXT selesai analisis service variabel");
        setState(() {
          path = file.path;
          analyticsResult = analyseResult;
        });
        logger.info('Analysis Result: ${analyseResult.stability}');
        FirebaseCrashlytics.instance.log("File TXT selesai analisis service variabel dengan result");
        return;
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      return;
    }
  }

  void _incrementCounter() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'zip']);
      setState(() {
        loading = true;
      });
      if (result != null) {
        final file = result.files.first;
        // Do something with the selected file
        // kalau filenya zip
        await analysisFile(file.path!);
      }
      return;
    } catch (e, stack) {
      logger.severe('Error picking or extracting file: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      return;
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  initState() {
    _sub = ShareService.stream.listen(
      (String filePath) async {
        logger.info('Received shared file: $filePath');
        setState(() {
          loading = true;
        });

        await analysisFile(filePath);

        setState(() {
          loading = false;
        });
      },
      onError: (err, stack) {
        logger.severe('Error receiving shared file: $err');
        FirebaseCrashlytics.instance.recordError(err, stack);
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("Versi 1.0.4+5"),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: loading
            ? Text('Data is loading...')
            : analyticsResult != null
            ? WidgetAnalytic(analyticsResult: analyticsResult)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('Pick a file'),
                  CupertinoButton(
                    child: Text('Open Whatsaap'),
                    onPressed: () async {
                      try {
                        final url = "https://wa.me/+6285213978468";
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        return;
                      } catch (e, stack) {
                        FirebaseCrashlytics.instance.recordError(e, stack);
                        return;
                      }
                    },
                  ),
                  SizedBox(height: 20),
                  CupertinoButton(
                    child: Text('Instant Crash'),
                    onPressed: () {
                      FirebaseCrashlytics.instance.crash();
                    },
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _incrementCounter, tooltip: 'Increment', child: const Icon(Icons.add)),
    );
  }
}

class WidgetAnalytic extends StatelessWidget {
  const WidgetAnalytic({super.key, required this.analyticsResult});

  final AnalyticsResult? analyticsResult;

  @override
  Widget build(BuildContext context) {
    final result = analyticsResult;
    if (result == null) {
      return const Text('No analytics result');
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.3,
          child: RadarChart(
            RadarChartData(
              dataSets: [
                RadarDataSet(
                  fillColor: Colors.blue.withValues(alpha: 0.5),
                  borderColor: Colors.blue,
                  entryRadius: 0,
                  dataEntries: [
                    RadarEntry(value: result.responsiveness),
                    RadarEntry(value: result.effortBalance),
                    RadarEntry(value: result.engagement),
                    RadarEntry(value: result.stability),
                    RadarEntry(value: result.consistency),
                  ],
                ),
              ],
              getTitle: (index, angle) => switch (index) {
                0 => const RadarChartTitle(text: 'Responsiveness', angle: 0),
                1 => const RadarChartTitle(text: 'Effort Balance', angle: 40),
                2 => const RadarChartTitle(text: 'Engagement', angle: 0),
                3 => const RadarChartTitle(text: 'Stability', angle: 0),
                4 => const RadarChartTitle(text: 'Consistency', angle: -40),
                _ => const RadarChartTitle(text: '', angle: 0),
              },
              radarBackgroundColor: Colors.transparent,
              radarShape: RadarShape.polygon,
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey)),
              radarBorderData: const BorderSide(color: Colors.grey, width: 2, style: BorderStyle.solid, strokeAlign: BorderSide.strokeAlignCenter),
              titlePositionPercentageOffset: 0.1,
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 14),
              tickCount: 1,
              ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
              tickBorderData: const BorderSide(color: Colors.transparent),
              gridBorderData: BorderSide(color: Colors.grey, width: 2),
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Column(children: [Text('Responsiveness'), Text(result.responsiveness.toStringAsFixed(2))])),
                Expanded(child: Column(children: [Text('Effort Balance'), Text(result.effortBalance.toStringAsFixed(2))])),
                Expanded(child: Column(children: [Text('Engagement'), Text(result.engagement.toStringAsFixed(2))])),
                Expanded(child: Column(children: [Text('Stability'), Text(result.stability.toStringAsFixed(2))])),
                Expanded(child: Column(children: [Text('Consistency'), Text(result.consistency.toStringAsFixed(2))])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ShareService {
  static const MethodChannel _channel = MethodChannel('share_channel');

  static Future<List<String>> getSharedFiles() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getSharedFiles');
    return result?.map((e) => e.toString()).toList() ?? [];
  }

  static Future<void> clearSharedFiles() async {
    await _channel.invokeMethod('clearSharedFiles');
  }

  static const EventChannel _eventChannel = EventChannel('share_event_channel');

  static Stream<String> get stream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return event as String;
    });
  }
}

Future<String> extractZip(File zipFile) async {
  // Baca file zip sebagai bytes
  final bytes = await zipFile.readAsBytes();

  // Decode zip
  final archive = ZipDecoder().decodeBytes(bytes);

  // Tentukan folder tujuan (misalnya temporary directory)
  final tempDir = await getApplicationDocumentsDirectory();
  final extractPath = tempDir.path;
  String fName = "";

  for (final file in archive) {
    FirebaseCrashlytics.instance.log("nama filenya : ${file.name}");
    final filename = '$extractPath/${file.name}';
    logger.info('Extracting: $filename');

    // Skip macOS metadata
    if (filename.contains('__MACOSX') || filename.split('/').last.startsWith('._') || filename.split('/').last.startsWith('_')) {
      continue;
    }
    if (filename.endsWith('.txt')) {
      final outFile = File(filename);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
      fName = filename;
    }
  }

  logger.info('Extract selesai di: $extractPath');
  return fName;
}

final logger = SimpleLogger()..mode = LoggerMode.log;
