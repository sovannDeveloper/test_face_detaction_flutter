part of 'main.dart';

class LiveDetectionScreen extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionService recognition;
  final FaceDetectionService detection;

  const LiveDetectionScreen({
    super.key,
    required this.camera,
    required this.detection,
    required this.recognition,
  });

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  late final _detector = widget.detection;
  late final _recognition = widget.recognition..reset();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _trackingId = 0;
  bool _isFaceRecognized = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream((image) {
        _detector.processCameraImage(image);
        _recognition.processCameraImage(image);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return StreamBuilder(
                    stream: _detector.stream,
                    builder: (_, s) {
                      final face = getSingleFace(s.data);

                      if (face?.trackingId != _trackingId) {
                        _trackingId = face?.trackingId ?? 0;
                        Future.microtask(_recognition.reset);
                      }

                      return Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.previewSize!.height /
                              _controller.value.previewSize!.width,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_controller),
                              if (face != null)
                                CustomPaint(
                                  painter: FacePainter(
                                      face,
                                      Size(
                                        _controller.value.previewSize!.height,
                                        _controller.value.previewSize!.width,
                                      ),
                                      true),
                                ),
                            ],
                          ),
                        ),
                      );
                    });
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          StreamBuilder(
              stream: _recognition.stream,
              builder: (_, s) {
                final d = s.data;
                final isVerify = d?.isVerify ?? false;

                Future.microtask(() => _isFaceRecognized = isVerify);

                return Positioned.fill(
                    child: CustomPaint(
                        painter: RPSCustomPainter(
                  borderColor: isVerify ? Colors.green : null,
                  backgroundColor:
                      Theme.of(context).appBarTheme.backgroundColor,
                  topText: isVerify ? 'Please blink your eyes' : null,
                  bottomText: '03:00',
                )));
              }),
        ],
      ),
    );
  }
}
