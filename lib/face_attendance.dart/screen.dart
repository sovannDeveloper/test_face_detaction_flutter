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
                  Center(child: CameraPreview(_cameraController)),
                  StreamBuilder(
                      stream: _detection.onDetection.stream,
                      builder: (_, s) {
                        return Text('Hello ${s.data?.faces}');
                      }),
                ],
              ),
      ),
    );
  }
}
