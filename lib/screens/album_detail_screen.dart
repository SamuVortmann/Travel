// lib/screens/album_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:chronicle/database/database_helper.dart';
import 'package:chronicle/screens/novo_registro_screen.dart';
import 'package:chronicle/screens/registro_detail_screen.dart';

const _green = Color(0xFF2E9E50);
const _greenLight = Color(0xFFE6F4EC);
const _bg = Color(0xFFF2F2F7);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);

Color _hex(String h) {
  try {
    return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return _green;
  }
}

const _icons = <String, IconData>{
  'photo_album': Icons.photo_album_outlined,
  'snowflake': Icons.ac_unit,
  'wb_sunny': Icons.wb_sunny_outlined,
  'eco': Icons.eco_outlined,
  'local_florist': Icons.local_florist_outlined,
  'flight': Icons.flight_outlined,
  'restaurant': Icons.restaurant_outlined,
  'favorite': Icons.favorite_outline,
  'camera': Icons.camera_alt_outlined,
  'home': Icons.home_outlined,
  'star': Icons.star_outline,
  'music_note': Icons.music_note_outlined,
};

/// Lista os momentos pertencentes a um álbum específico.
class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  const AlbumDetailScreen({super.key, required this.album});
  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Registro> _momentos = [];
  bool _loading = true;
  late Album _album;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _load();
  }

  Future<void> _load() async {
    // Atualiza o álbum e seus registros a partir do banco.
    setState(() => _loading = true);
    final id = _album.id;
    final list = id != null
        ? await DatabaseHelper.instance.listarRegistrosPorAlbum(id)
        : <Registro>[];
    if (mounted)
      setState(() {
        _momentos = list;
        _loading = false;
      });
  }

  void _addMomento() {
    // Abre o formulário já associado ao álbum atual e recarrega ao retornar.
    Future.microtask(() async {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovoRegistroScreen(albumPreSelecionado: _album),
        ),
      );
      if (mounted) _load();
    });
  }

  void _openMomento(Registro r) {
    // Abre os detalhes do momento e atualiza a lista após possíveis alterações.
    Future.microtask(() async {
      if (!mounted) return;
      final full = r.id == null
          ? r
          : await DatabaseHelper.instance.buscarRegistro(r.id!);
      if (!mounted || full == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RegistroDetailScreen(registro: full)),
      );
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _hex(_album.cor);
    final bg = Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _album.nome,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Novo momento',
            onPressed: _addMomento,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _momentos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _icons[_album.icone] ?? Icons.photo_album_outlined,
                      size: 36,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum momento ainda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _t1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toque em + para adicionar o primeiro.',
                    style: TextStyle(color: _t2),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _addMomento,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Adicionar momento',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _momentos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _MomentoCard(
                  registro: _momentos[i],
                  onTap: () => _openMomento(_momentos[i]),
                ),
              ),
            ),
    );
  }
}

// ── Cartão de momento ─────────────────────────────────────────────────────────
class _MomentoCard extends StatelessWidget {
  // Cartão compacto usado para representar um registro na grade do álbum.
  final Registro registro;
  final VoidCallback onTap;
  const _MomentoCard({required this.registro, required this.onTap});

  String _fmt(String iso) {
    // Formata a data ISO para uma data curta e legível.
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
    final r = registro;
    final hasPhoto = r.fotos.isNotEmpty;
    const moods = ['😊', '😄', '😐', '😢', '😍'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto exibida como destaque do momento.
            if (hasPhoto)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: Image.memory(
                  r.fotos.first,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.titulo,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _t1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        moods[r.humor.clamp(0, 4)],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmt(r.dataHora),
                    style: const TextStyle(fontSize: 12, color: _t3),
                  ),
                  if (r.local.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: _t3,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          r.local,
                          style: const TextStyle(fontSize: 12, color: _t2),
                        ),
                      ],
                    ),
                  ],
                  if (r.descricao.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r.descricao,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _t2,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
