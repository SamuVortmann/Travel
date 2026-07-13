import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:travel/database/database_helper.dart';

const _green = Color(0xFF2E9E50);
const _bg = Color(0xFFF2F2F7);
const _card = Colors.white;
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);
const _red = Color(0xFFFF3B30);
const _moods = ['😊', '😄', '😐', '😢', '😍'];

class RegistroDetailScreen extends StatefulWidget {
  final Registro registro;
  const RegistroDetailScreen({super.key, required this.registro});

  @override
  State<RegistroDetailScreen> createState() => _RegistroDetailScreenState();
}

class _RegistroDetailScreenState extends State<RegistroDetailScreen> {
  late final PageController _pageController;
  int _photoIndex = 0;

  Registro get r => widget.registro;
  List<Uint8List> get photos => r.fotos;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const m = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${m[dt.month - 1]} ${dt.year} · $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final availablePhotos = photos;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          r.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (availablePhotos.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.black,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: availablePhotos.length,
                        onPageChanged: (index) =>
                            setState(() => _photoIndex = index),
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => _openFullscreen(index),
                          child: Hero(
                            tag: 'registro-${r.id}-foto-$index',
                            child: Image.memory(
                              availablePhotos[index],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (availablePhotos.length > 1)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_photoIndex + 1}/${availablePhotos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (availablePhotos.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 66,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availablePhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: EdgeInsets.all(_photoIndex == index ? 2 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _photoIndex == index
                              ? _green
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          availablePhotos[index],
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.titulo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _t1,
                  ),
                ),
              ),
              Text(
                _moods[r.humor.clamp(0, 4)],
                style: const TextStyle(fontSize: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chip(Icons.calendar_today_outlined, _fmt(r.dataHora)),
          if (r.local.isNotEmpty) _chip(Icons.location_on_outlined, r.local),
          if (r.album.isNotEmpty) _chip(Icons.photo_album_outlined, r.album),
          const SizedBox(height: 12),
          if (r.descricao.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Text(
                r.descricao,
                style: const TextStyle(fontSize: 15, color: _t2, height: 1.6),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullscreen(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenGallery(
          photos: photos,
          initialIndex: initialIndex,
          heroPrefix: 'registro-${r.id}-foto-',
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 15, color: _t3),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: _t2)),
        ),
      ],
    ),
  );

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir momento'),
        content: const Text('Deseja excluir este momento permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok == true && r.id != null) {
      await DatabaseHelper.instance.deletarRegistro(r.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<Uint8List> photos;
  final int initialIndex;
  final String heroPrefix;
  const _FullscreenGallery({
    required this.photos,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} de ${widget.photos.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.photos.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (_, index) => Center(
        child: Hero(
          tag: '${widget.heroPrefix}$index',
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(widget.photos[index], fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}
