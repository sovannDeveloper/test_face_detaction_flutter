import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

part 'blink_detector.dart';
part 'detection_service.dart';
part 'detection_v2.dart';
part 'eye_blink.dart';
part 'func.dart';
part 'image_util.dart';
part 'recognition_service.dart';
part 'recognition_v2.dart';
part 'screen.dart';
part 'storage_util.dart';
part 'widget.dart';
