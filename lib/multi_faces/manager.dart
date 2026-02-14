part of 'main.dart';

class IsolateManager {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static ReceivePort? _mainReceivePort;
  static final _responses = <int, Completer>{};
  static int _nextId = 0;

  // Stream controller for UI updates
  static final _progressController =
      StreamController<Map<String, Object?>>.broadcast();
  static Stream<Map<String, Object?>> get progressStream =>
      _progressController.stream;

  static Future<void> initialize() async {
    if (_isolate != null) return;

    _mainReceivePort = ReceivePort();

    _isolate = await Isolate.spawn(_isolateEntry, _mainReceivePort!.sendPort);

    _mainReceivePort!.listen((message) {
      final response = message as Map<String, dynamic>;

      if (response.containsKey('sendPort')) {
        _sendPort = response['sendPort'] as SendPort;
        return;
      }

      if (response.containsKey('progress')) {
        _progressController.add(response);
        return;
      }

      // Final result
      final id = response['id'] as int;
      final result = response['result'];
      _responses[id]?.complete(result);
      _responses.remove(id);
    });

    // Wait for isolate to be ready
    await Future.delayed(const Duration(milliseconds: 100));
  }

  static Future<List<dynamic>> processEmbeddings(List<String> paths) async {
    if (_sendPort == null) await initialize();

    final completer = Completer<List<dynamic>>();
    final id = _nextId++;

    _responses[id] = completer;
    _sendPort!.send({
      'id': id,
      'paths': paths,
      'modelPath': MyRecognition.modelPath,
    });

    return completer.future;
  }

  static void _isolateEntry(SendPort mainSendPort) async {
    final isolateReceivePort = ReceivePort();

    mainSendPort.send({'sendPort': isolateReceivePort.sendPort});

    MyRecognition? isolateRecognition;

    await for (final message in isolateReceivePort) {
      final data = message as Map<String, dynamic>;
      final isDispose = data['isDispose'] as bool?;

      if (isDispose ?? false) {
        isolateRecognition?.dispose();
        isolateReceivePort.close();
        return;
      }

      final modelPath = data['modelPath'] as String;
      final paths = data['paths'] as List<String>;

      isolateRecognition ??= MyRecognition(modelPath);

      for (int i = 0; i < paths.length; i++) {
        final path = paths[i];
        final file = File(path).readAsBytesSync();
        await isolateRecognition.getEmbedding(file);

        mainSendPort.send({
          'progress': true,
          'current': i + 1,
          'total': paths.length,
        });
      }
    }
  }

  static Future<void> dispose() async {
    if (_sendPort != null) {
      _sendPort!.send({'isDispose': true});
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _progressController.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
  }
}
