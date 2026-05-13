import 'dart:io';

import 'package:flu_wake_lock/flu_wake_lock.dart';
import 'package:flutter/material.dart';

import 'face_attendance.dart/main.dart';
import 'face_detection_screen_testing.dart';
import 'multi_faces/main.dart';

final spoofingDetector = FaceAntiSpoofingDetector();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FluWakeLock().enable();
  runApp(const MyApp());
}

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0F);
const _kSurface = Color(0xFF1C1C1E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kText2 = Color(0xFF8E8E93);
const _kBorder = Color(0xFF2C2C2E);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _kBg,
        colorScheme: const ColorScheme.dark(
          primary: _kPrimary,
          surface: _kSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _kBg,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const MyMainScreen(),
    );
  }
}

class MyMainScreen extends StatefulWidget {
  const MyMainScreen({super.key});

  @override
  State<MyMainScreen> createState() => _MyMainScreenState();
}

class _MyMainScreenState extends State<MyMainScreen> {
  bool _modelsLoaded = false;
  bool _loadingFaces = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    await Future.wait([
      FaceRecognitionService.loadModel(),
      spoofingDetector.loadModel(),
    ]);
    if (mounted) setState(() => _modelsLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFeatureSection()),
            SliverToBoxAdapter(child: _buildRegisteredSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Row(
        children: [
          _AppIcon(),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Face AI Lab',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Detection & recognition testing',
                style: TextStyle(fontSize: 12, color: _kText2),
              ),
            ],
          ),
          const Spacer(),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (!_modelsLoaded) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: _kGreen),
          SizedBox(width: 5),
          Text(
            'Ready',
            style: TextStyle(
              fontSize: 11,
              color: _kGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature section ────────────────────────────────────────────────────────

  Widget _buildFeatureSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Features'),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.face_retouching_natural_rounded,
            iconColor: _kPrimary,
            title: 'Live Face Detection',
            subtitle:
                'Real-time camera with anti-spoofing & blink verification',
            trailing: _loadingFaces
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                  )
                : null,
            enabled: _modelsLoaded && !_loadingFaces,
            onTap: () async {
              setState(() => _loadingFaces = true);
              final images = await ImageStorageUtil.loadAllImages();
              await FaceRecognitionService.loadRegisterFaces(images);
              setState(() => _loadingFaces = false);
              if (mounted) _go(const FaceDetectionPage());
            },
          ),
          const SizedBox(height: 10),
          _FeatureCard(
            icon: Icons.people_alt_rounded,
            iconColor: _kOrange,
            title: 'Multi-Face Detection',
            subtitle:
                'Detect & embed multiple faces from group photos with isolate',
            onTap: () => _go(const MultiFaceScreen()),
          ),
        ],
      ),
    );
  }

  // ── Registered faces section ───────────────────────────────────────────────

  Widget _buildRegisteredSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel('Registered Faces'),
              const Spacer(),
              _AddButton(onAdded: () => setState(() {})),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<File>>(
            future: ImageStorageUtil.loadAllImages(),
            builder: (_, snap) {
              final images = snap.data ?? [];
              if (images.isEmpty) return _EmptyFaces();
              return _FacesGrid(
                images: images,
                onChanged: () => setState(() {}),
              );
            },
          ),
        ],
      ),
    );
  }

  void _go(Widget child) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => child));
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9F97FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.face_retouching_natural,
        color: Colors.white,
        size: 25,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _kText2,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kText2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF48484A),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onAdded;
  const _AddButton({required this.onAdded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await ImageStorageUtil.pickFromGallery();
        if (picked != null) {
          await ImageStorageUtil.saveImage(picked);
          onAdded();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: _kPrimary),
            SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                color: _kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFaces extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_outlined, size: 38, color: Color(0xFF48484A)),
          SizedBox(height: 10),
          Text(
            'No faces registered',
            style: TextStyle(color: _kText2, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "Add" to register a face for recognition',
            style: TextStyle(color: Color(0xFF48484A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FacesGrid extends StatelessWidget {
  final List<File> images;
  final VoidCallback onChanged;

  const _FacesGrid({required this.images, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) => _FaceTile(image: images[i], onDelete: onChanged),
    );
  }
}

class _FaceTile extends StatelessWidget {
  final File image;
  final VoidCallback onDelete;

  const _FaceTile({required this.image, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(image, fit: BoxFit.cover),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                await ImageStorageUtil.deleteImage(image.path);
                onDelete();
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
