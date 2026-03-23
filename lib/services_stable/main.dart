import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:remixicon/remixicon.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

part 'crop_face.dart';
part 'detection_service.dart';
part 'eye_blink.dart';
part 'func.dart';
part 'recognition_service.dart';
part 'widget.dart';
