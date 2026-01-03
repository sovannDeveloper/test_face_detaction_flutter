import 'package:camera/camera.dart';
import 'package:flu_wake_lock/flu_wake_lock.dart';
import 'package:flutter/material.dart';

import 'main_screen.dart';
import 'services/face_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FluWakeLock().enable();
 await FaceDetectionService.initCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FaceDetectionPage(),
      // home: FaceRecognitionScreen(),
      // home: FaceRecognitionScreen(),
    );
  }
}
