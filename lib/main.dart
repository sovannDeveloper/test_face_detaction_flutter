import 'package:flu_wake_lock/flu_wake_lock.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'face_attendance.dart/main.dart';
import 'face_detection_screen_testing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FluWakeLock().enable();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyMainScreen());
  }
}

class MyMainScreen extends StatefulWidget {
  const MyMainScreen({super.key});

  @override
  State<MyMainScreen> createState() => _MyMainScreenState();
}

class _MyMainScreenState extends State<MyMainScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String _text = '';

  @override
  void initState() {
    super.initState();

    Future.microtask(FaceRecognitionService.loadModel);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Face Detection'),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Result: $_text'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () async {
                        _text = 'Loading...';
                        _loading = true;
                        setState(() {});
                        if (FaceRecognitionService.registeredFaces.isEmpty) {
                          final images = await ImageStorageUtil.loadAllImages();

                          await FaceRecognitionService.loadRegisterFaces(
                            images,
                            onProgress: (current, total) {
                              print('--==> $total: $current');
                            },
                          );
                        }

                        _loading = false;
                        setState(() {});

                        _go(const FaceDetectionPage());
                      },
                      child: Text('Face detection ${_loading ? '...' : ''}')),
                  ElevatedButton(
                      onPressed: () async {
                        // await FaceRecognitionService.loadRegisterFaces();
                        // _go(const FaceScreen());
                      },
                      child: const Text('Go to face detection')),
                  const Divider(),
                  ElevatedButton(
                      onPressed: () async {
                        final img = await ImageStorageUtil.pickFromGallery();
                        if (img != null) {
                          await ImageStorageUtil.saveImage(img);
                          setState(() {});
                        }
                      },
                      child: const Text('Register Faces')),
                  FutureBuilder(
                      future: ImageStorageUtil.loadAllImages(),
                      builder: (_, s) {
                        final images = s.data ?? [];

                        return images.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image,
                                        size: 100, color: Colors.grey),
                                    SizedBox(height: 20),
                                    Text('No images',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                primary: false,
                                padding: const EdgeInsets.all(8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: images.length,
                                itemBuilder: (context, index) {
                                  final image = images[index];
                                  return GestureDetector(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(image, fit: BoxFit.cover),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 20),
                                            onPressed: () async {
                                              final deleted =
                                                  await ImageStorageUtil
                                                      .deleteImage(image.path);
                                              if (deleted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Image deleted')),
                                                );
                                                setState(() {});
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                      })
                ],
              ),
            ),
            // Positioned.fill(child: CustomPaint(painter: RPSCustomPainter())),
          ],
        ),
      ),
    );
  }

  void _go(Widget child) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => child));
  }
}
