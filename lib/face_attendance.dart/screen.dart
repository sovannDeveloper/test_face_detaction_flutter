part of 'main.dart';

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});

  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> {
  final _detection = FaceDetectionService();
  List<CameraDescription> _cameras = [];
  late CameraController _cameraController;
  late CameraDescription _camera;
  bool _isInitCamera = false;
  final ValueNotifier<Size?> _imageSize = ValueNotifier(null);

  Future<void> _initCameras() async {
    _isInitCamera = true;
    setState(() {});
    _cameras = await availableCameras();
    _camera = _cameras.first;
    _camera = _camera.lensDirection == CameraLensDirection.front
        ? _cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first)
        : _cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first);

    _cameraController = CameraController(
      _camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController.initialize();
    _detection.init(_camera);
    _cameraController.startImageStream(_detection.processCameraImage);
    _isInitCamera = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _initCameras();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _detection.dispose();
    _imageSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _isInitCamera
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  ValueListenableBuilder(
                      valueListenable: _imageSize,
                      builder: (_, s, w) {
                        return AspectRatio(
                            aspectRatio: s == null
                                ? _cameraController.value.aspectRatio
                                : s.width / s.height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController),
                                StreamBuilder(
                                    stream: _detection.onDetection.stream,
                                    builder: (_, s) {
                                      final face = s.data?.face;
                                      final size =
                                          s.data?.imageSize ?? Size.zero;
                                      final isVerify =
                                          s.data?.isVerify ?? false;

                                      if (face != null) {
                                        return CustomPaint(
                                            painter: FacePainter(
                                                face, size, isVerify));
                                      }

                                      return const SizedBox();
                                    }),
                                StreamBuilder(
                                    stream: _detection.onDetection.stream,
                                    builder: (_, s) {
                                      final isVerify =
                                          s.data?.isVerify ?? false;
                                      final isValidBlink =
                                          s.data?.blinkEvent?.type ==
                                              BlinkType.bothEyes;

                                      Color active = isVerify
                                          ? const Color.fromARGB(
                                              255, 33, 255, 41)
                                          : Colors.red;

                                      return Positioned.fill(
                                        child: Center(
                                          child: Stack(
                                            children: [
                                              AspectRatio(
                                                aspectRatio: 1 / 1,
                                                child: CustomPaint(
                                                  painter: Group6Painter(
                                                      Colors.blue, active),
                                                ),
                                              ),
                                              Positioned(
                                                  left: 0,
                                                  right: 0,
                                                  top: 16,
                                                  child: Center(
                                                      child: Text(
                                                    !isVerify
                                                        ? ''
                                                        : isValidBlink
                                                            ? 'Done'
                                                            : 'Please blink your eyes!',
                                                    style: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white),
                                                  )))
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                              ],
                            ));
                      }),
                  StreamBuilder(
                      stream: _detection.onDetection.stream,
                      builder: (_, s) {
                        Future.microtask(() {
                          _imageSize.value ??= s.data?.imageSize;
                        });

                        return Text('Verify: ${s.data?.isVerify} \n'
                            'EyeBlink: ${s.data?.blinkEvent} \n'
                            'FaceId: ${s.data?.face.trackingId}');
                      }),
                ],
              ),
      ),
    );
  }
}
