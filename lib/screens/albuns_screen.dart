// lib/screens/albuns_screen.dart
import 'package:flutter/material.dart';
import 'package:chronicle/database/database_helper.dart';
import 'package:chronicle/screens/album_detail_screen.dart';

const _green = Color(0xFF2E9E50);
const _bg = Color(0xFFF2F2F7);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);
const _red = Color(0xFFFF3B30);

const _allIcons = <String, IconData>{
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

const _allColors = [
  '#2E9E50',
  '#5B8DEF',
  '#F5A623',
  '#E07B39',
  '#9B59B6',
  '#E74C3C',
  '#1ABC9C',
  '#34495E',
];

Color _hex(String h) {
  try {
    return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return _green;
  }
}

/// Gerencia a listagem, criação, edição e exclusão dos álbuns.
class AlbunsScreen extends StatefulWidget {
  const AlbunsScreen({super.key});
  @override
  State<AlbunsScreen> createState() => _AlbunsScreenState();
}

class _AlbunsScreenState extends State<AlbunsScreen> {
  List<Album> _albuns = [];
  Map<int, int> _contagens = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Busca os álbuns e a quantidade de registros de cada um.
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final a = await db.listarAlbuns();
    final c = await db.contagemRegistrosPorAlbum();
    if (mounted)
      setState(() {
        _albuns = a;
        _contagens = c;
        _loading = false;
      });
  }

  void _openCreate() {
    // Abre o formulário vazio e recarrega a lista quando ele for fechado.
    Future.microtask(() async {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AlbumFormSheet(onSaved: _load),
      );
    });
  }

  void _openEdit(Album a) {
    // Abre o formulário preenchido com os dados do álbum selecionado.
    Future.microtask(() async {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AlbumFormSheet(album: a, onSaved: _load),
      );
    });
  }

  void _delete(Album a) {
    // Solicita confirmação antes de remover permanentemente o álbum.
    Future.microtask(() async {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Excluir álbum'),
          content: Text('Excluir "${a.nome}"? Os momentos não serão apagados.'),
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
      if (ok == true) {
        await DatabaseHelper.instance.deletarAlbum(a.id!);
        if (mounted) _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Álbuns',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _albuns.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_album_outlined, size: 56, color: _t3),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum álbum ainda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _t1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toque em + para criar o primeiro.',
                    style: TextStyle(color: _t2),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _albuns.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _AlbumRow(
                  album: _albuns[i],
                  totalMomentos: _contagens[_albuns[i].id] ?? 0,
                  onTap: () => Future.microtask(() async {
                    if (!mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumDetailScreen(album: _albuns[i]),
                      ),
                    );
                    if (mounted) _load();
                  }),
                  onEdit: () => _openEdit(_albuns[i]),
                  onDelete: () => _delete(_albuns[i]),
                ),
              ),
            ),
    );
  }
}

// ── Linha de álbum ────────────────────────────────────────────────────────────
class _AlbumRow extends StatelessWidget {
  // Linha reutilizável com dados e ações de um álbum.
  final Album album;
  final int totalMomentos;
  final VoidCallback onTap, onEdit, onDelete;
  const _AlbumRow({
    required this.album,
    required this.totalMomentos,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hex(album.cor);
    final bg = Color.alphaBlend(color.withOpacity(0.12), Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _allIcons[album.icone] ?? Icons.photo_album_outlined,
                color: color,
                size: 26,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.nome,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _t1,
                    ),
                  ),
                  Text(
                    totalMomentos == 1
                        ? '1 momento'
                        : '$totalMomentos momentos',
                    style: const TextStyle(fontSize: 12, color: _t2),
                  ),
                  if (album.descricao.isNotEmpty)
                    Text(
                      album.descricao,
                      style: const TextStyle(fontSize: 12, color: _t2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: _t3),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: _red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painel do formulário de álbum ─────────────────────────────────────────────
class _AlbumFormSheet extends StatefulWidget {
  // Painel inferior compartilhado pelos fluxos de criação e edição.
  final Album? album;
  final VoidCallback onSaved;
  const _AlbumFormSheet({this.album, required this.onSaved});
  @override
  State<_AlbumFormSheet> createState() => _AlbumFormSheetState();
}

class _AlbumFormSheetState extends State<_AlbumFormSheet> {
  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _icon = 'photo_album';
  String _cor = '#2E9E50';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.album != null) {
      _nomeCtrl.text = widget.album!.nome;
      _descCtrl.text = widget.album!.descricao;
      _icon = widget.album!.icone;
      _cor = widget.album!.cor;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Valida os campos e decide entre inserir ou atualizar o álbum.
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    setState(() => _saving = true);
    final a = Album(
      id: widget.album?.id,
      nome: nome,
      descricao: _descCtrl.text.trim(),
      icone: _icon,
      cor: _cor,
      criadoEm: widget.album?.criadoEm ?? DateTime.now().toIso8601String(),
    );
    if (widget.album == null) {
      await DatabaseHelper.instance.inserirAlbum(a);
    } else {
      await DatabaseHelper.instance.atualizarAlbum(a);
    }
    if (mounted) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hex(_cor);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.album == null ? 'Novo álbum' : 'Editar álbum',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _t1,
              ),
            ),
            const SizedBox(height: 16),

            // Prévia do ícone selecionado.
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    color.withOpacity(0.15),
                    Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Icon(
                  _allIcons[_icon] ?? Icons.photo_album_outlined,
                  size: 32,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nome
            const Text(
              'NOME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _t3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _nomeCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Viagem para Paris',
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Descrição
            const Text(
              'DESCRIÇÃO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _t3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Opcional...',
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Seletor de ícone.
            const Text(
              'ÍCONE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _t3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allIcons.entries.map((e) {
                final sel = _icon == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.15) : _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? color : _border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(e.value, size: 22, color: sel ? color : _t3),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Seletor de cor.
            const Text(
              'COR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _t3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _allColors.map((c) {
                final sel = _cor == c;
                final col = _hex(c);
                return GestureDetector(
                  onTap: () => setState(() => _cor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: col.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Botão para salvar o álbum.
            GestureDetector(
              onTap: _saving ? null : () => Future.microtask(_save),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _saving ? _green.withOpacity(0.5) : _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.album == null ? 'Criar álbum' : 'Salvar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
