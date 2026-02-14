part of 'main.dart';

class MultiFaceScreen extends StatefulWidget {
  const MultiFaceScreen({super.key});

  @override
  State<MultiFaceScreen> createState() => _MultiFaceScreenState();
}

class _MultiFaceScreenState extends State<MultiFaceScreen> {
  final _detector = _Detector();
  String _imagePath = '';
  List<String> _extractFaces = [];
  String _time = '0';
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    MyRecognition.initModel();
    IsolateManager.initialize();
    _timer = Timer.periodic(Duration(milliseconds: 250), (t) {
      _count++;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _detector.dispose();
    _timer?.cancel();
    IsolateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = MediaQuery.of(context).size;

    return SafeArea(
      child: Scaffold(
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              onPressed: () async {
                _process(0);
              },
              child: Text('0'),
            ),

            SizedBox(width: 6),
            FloatingActionButton(
              onPressed: () async {
                _process(1);
              },
              child: Text('1'),
            ),
            SizedBox(width: 6),
            FloatingActionButton(
              onPressed: () async {
                _process(2);
              },
              child: Text('2'),
            ),
            SizedBox(width: 6),
            FloatingActionButton(
              onPressed: () async {
                _process(3);
              },
              child: Text('3'),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(width: q.width, child: Image.file(File(_imagePath))),
            Text('$_time\m $_count'),
            StreamBuilder(
              stream: IsolateManager.progressStream,
              builder: (_, s) {
                return Text('${s.data}');
              },
            ),
            Expanded(
              child: GridView.count(
                padding: EdgeInsets.all(10),
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: List.generate(_extractFaces.length, (i) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(_extractFaces[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${_extractFaces[i].split('/').last.split('-').first}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _process(int num) async {
    final name = 'assets/images/group$num.jpg';
    final path = await _getImageSizeFromAsset(name);

    _imagePath = path;
    setState(() {});

    final detect = await _detector.process(path);

    final stopwatch = Stopwatch()..start();
    _extractFaces = await cropFacesFromImage(_imagePath, detect);
    await IsolateManager.processEmbeddings(_extractFaces);

    setState(() {});
  }
}
