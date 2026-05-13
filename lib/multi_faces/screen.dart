part of 'main.dart';

// ── Design tokens (local) ──────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0F);
const _kSurface = Color(0xFF1C1C1E);
const _kBorder = Color(0xFF2C2C2E);
const _kPrimary = Color(0xFF6C63FF);
const _kOrange = Color(0xFFFF9F0A);
const _kText2 = Color(0xFF8E8E93);

class MultiFaceScreen extends StatefulWidget {
  const MultiFaceScreen({super.key});

  @override
  State<MultiFaceScreen> createState() => _MultiFaceScreenState();
}

class _MultiFaceScreenState extends State<MultiFaceScreen> {
  final _detector = _Detector();

  String _imagePath = '';
  List<String> _extractFaces = [];
  int _elapsedMs = 0;
  bool _isProcessing = false;
  int? _selectedSample;
  Map<String, Object?>? _latestProgress;

  @override
  void initState() {
    super.initState();
    MyRecognition.initModel();
    IsolateManager.initialize();
  }

  @override
  void dispose() {
    _detector.dispose();
    IsolateManager.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Multi-Face Detection',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePreview(),
          const SizedBox(height: 12),
          _buildSampleSelector(),
          const SizedBox(height: 12),
          _buildStatsRow(),
          if (_isProcessing) ...[
            const SizedBox(height: 10),
            _buildProgressBar(),
          ],
          const SizedBox(height: 4),
          Expanded(child: _buildFaceGrid()),
        ],
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 190,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _imagePath.isEmpty
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 40, color: Color(0xFF48484A)),
                  SizedBox(height: 8),
                  Text(
                    'Select a sample group below',
                    style: TextStyle(fontSize: 13, color: _kText2),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imagePath), fit: BoxFit.cover),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: CircularProgressIndicator(color: _kPrimary),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ── Sample selector ───────────────────────────────────────────────────────

  Widget _buildSampleSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(4, (i) {
          final selected = _selectedSample == i;
          return Expanded(
            child: GestureDetector(
              onTap: _isProcessing ? null : () => _process(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? _kPrimary : _kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _kPrimary : _kBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Group $i',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _kText2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Chip(
            icon: Icons.face_rounded,
            label: '${_extractFaces.length} faces',
            color: _kPrimary,
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.timer_outlined,
            label: '$_elapsedMs ms',
            color: _kOrange,
          ),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final current = (_latestProgress?['current'] as int?) ?? 0;
    final total = (_latestProgress?['total'] as int?) ?? 1;
    final pct = total > 0 ? current / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Computing embeddings…',
                style: TextStyle(fontSize: 11, color: _kText2),
              ),
              Text(
                '$current / $total',
                style: const TextStyle(fontSize: 11, color: _kText2),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _kBorder,
              color: _kPrimary,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Face grid ─────────────────────────────────────────────────────────────

  Widget _buildFaceGrid() {
    if (_extractFaces.isEmpty && !_isProcessing) {
      return const Center(
        child: Text(
          'No faces detected yet',
          style: TextStyle(color: Color(0xFF48484A), fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _extractFaces.length,
      itemBuilder: (_, i) {
        final id = _extractFaces[i].split('/').last.split('-').first;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(_extractFaces[i]), fit: BoxFit.cover),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Text(
                    'ID $id',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  void _process(int num) async {
    setState(() {
      _isProcessing = true;
      _selectedSample = num;
      _extractFaces = [];
      _latestProgress = null;
      _elapsedMs = 0;
    });

    final assetName = 'assets/images/group$num.jpg';
    final path = await _getImageSizeFromAsset(assetName);
    setState(() => _imagePath = path);

    final faces = await _detector.process(path);

    final stopwatch = Stopwatch()..start();
    _extractFaces = await cropFacesFromImage(_imagePath, faces);
    setState(() {});

    final sub = IsolateManager.progressStream.listen((data) {
      setState(() => _latestProgress = data);
    });

    await IsolateManager.processEmbeddings(_extractFaces);
    await sub.cancel();

    stopwatch.stop();
    setState(() {
      _elapsedMs = stopwatch.elapsedMilliseconds;
      _isProcessing = false;
    });
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
