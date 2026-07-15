// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:chronicle/database/database_helper.dart';
import 'package:chronicle/screens/albuns_screen.dart';
import 'package:chronicle/screens/album_detail_screen.dart';
import 'package:chronicle/screens/novo_registro_screen.dart';
import 'package:chronicle/screens/registro_detail_screen.dart';
import 'package:chronicle/screens/locations_screen.dart';
import 'package:chronicle/screens/insights_screen.dart';

const _green = Color(0xFF2E9E50);
const _greenLight = Color(0xFFE6F4EC);
const _bg = Color(0xFFF2F2F7);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);

// ── Estrutura raiz: mantém a navegação inferior e alterna o conteúdo ─────────
/// Estrutura principal que coordena as abas e o botão de novo registro.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Aba ativa: 0=Início, 1=Álbuns, 2=botão central, 3=Mapa, 4=Análises.
  // O índice 2 é reservado ao botão; as abas reais são 0, 1, 3 e 4.
  int _tab = 0;
  final List<int> _revisions = List<int>.filled(5, 0);

  void _refreshTabAfterNavigation(int tab) {
    // Incrementa a revisão da aba para forçar uma nova consulta de dados.
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _revisions[tab]++);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  // Abre uma nova tela e recarrega os dados ao retornar.
  Future<void> _go(Widget page) async {
    if (!mounted) return;
    final sourceTab = _tab;
    final route = MaterialPageRoute<void>(builder: (_) => page);
    await Navigator.push(context, route);

    // No desktop, aguarda a remoção completa da rota antes de reconstruir a
    // tela inferior, evitando atualizações recursivas do rastreador do mouse.
    await route.completed;
    _refreshTabAfterNavigation(sourceTab);
  }

  Future<void> _openNovoRegistro() async {
    // Abre o formulário de momento e atualiza a aba inicial após o retorno.
    if (!mounted) return;
    final sourceTab = _tab;
    final route = MaterialPageRoute<void>(
      builder: (_) => const NovoRegistroScreen(),
    );
    await Navigator.push(context, route);
    await route.completed;
    _refreshTabAfterNavigation(sourceTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      // ── Corpo: alterna entre as abas ─────────────────────────────────────
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            key: ValueKey('home-${_revisions[0]}'),
            onNavigate: _go,
          ), // Aba 0.
          _AlbunsTab(
            key: ValueKey('albums-${_revisions[1]}'),
            onNavigate: _go,
          ), // Aba 1.
          const SizedBox.shrink(), // Espaço da aba 2, nunca exibido.
          LocationsScreen(
            key: ValueKey('locations-${_revisions[3]}'),
          ), // Aba 3.
          InsightsScreen(key: ValueKey('insights-${_revisions[4]}')), // Aba 4.
        ],
      ),

      // ── Botão central verde encaixado no recorte ────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _openNovoRegistro,
        backgroundColor: _green,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Barra de navegação inferior com recorte ─────────────────────────
      bottomNavigationBar: BottomAppBar(
        color: _card,
        elevation: 8,
        notchMargin: 8,
        shape:
            const CircularNotchedRectangle(), // Cria o recorte do botão central.
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Lado esquerdo: Início e Álbuns.
              _navItem(0, Icons.home_outlined, 'Home'),
              _navItem(1, Icons.photo_album_outlined, 'Álbuns'),
              // Espaço central reservado ao botão.
              const Expanded(child: SizedBox()),
              // Lado direito: Mapa e Análises.
              _navItem(3, Icons.map_outlined, 'Locais'),
              _navItem(4, Icons.show_chart, 'Insights'),
            ],
          ),
        ),
      ),
    );
  }

  // Monta um item de navegação usando GestureDetector para evitar falha no Windows.
  Widget _navItem(int index, IconData icon, String label) {
    // Converte o índice da aba em posição visual, ignorando o espaço central.
    // As abas 0 e 1 ficam à esquerda; 3 e 4 ficam à direita.
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _tab = index;
          _revisions[index]++;
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? _green : _t3),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? _green : _t3,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conteúdo da aba inicial ───────────────────────────────────────────────────
/// Conteúdo inicial com resumo dos álbuns e momentos mais recentes.
class _HomeTab extends StatefulWidget {
  final void Function(Widget) onNavigate;
  const _HomeTab({super.key, required this.onNavigate});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  // Preserva a posição de rolagem ao alternar entre as abas.
  @override
  bool get wantKeepAlive => true;

  List<Album> _albuns = [];
  List<Registro> _recentes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Carrega os resumos apresentados na página inicial.
    setState(() => _loading = true);
    try {
      final a = await DatabaseHelper.instance.listarAlbuns();
      if (mounted) setState(() => _albuns = a);
      final r = await DatabaseHelper.instance.listarRegistrosRecentes();
      if (mounted) {
        setState(() {
          _recentes = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        title: const Text(
          'Chronicle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // Cabeçalho dos álbuns.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Álbuns',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _t1,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigate(const AlbunsScreen()),
                        child: const Text(
                          'Gerenciar',
                          style: TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Atalhos dos álbuns.
                  if (_albuns.isEmpty)
                    _emptyCard(
                      'Nenhum álbum ainda',
                      'Toque em Gerenciar para criar o primeiro.',
                      icon: Icons.photo_album_outlined,
                      onTap: () => widget.onNavigate(const AlbunsScreen()),
                    )
                  else
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _albuns.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _AlbumChip(
                          album: _albuns[i],
                          onTap: () => widget.onNavigate(
                            AlbumDetailScreen(album: _albuns[i]),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Cabeçalho dos momentos recentes.
                  const Text(
                    'Momentos recentes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _t1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_recentes.isEmpty)
                    _emptyCard(
                      'Nenhum momento ainda',
                      'Toque no + para registrar seu primeiro momento.',
                      icon: Icons.camera_alt_outlined,
                    )
                  else
                    ...List.generate(
                      _recentes.length,
                      (i) => _MomentTile(
                        registro: _recentes[i],
                        onTap: () => widget.onNavigate(
                          RegistroDetailScreen(registro: _recentes[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _emptyCard(
    String title,
    String sub, {
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: _green, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _t1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(fontSize: 12, color: _t2)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _t3),
          ],
        ),
      ),
    );
  }
}

// ── Aba de álbuns: reutiliza AlbunsScreen no corpo ────────────────────────────
/// Adaptador que incorpora a tela de álbuns à navegação principal.
class _AlbunsTab extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _AlbunsTab({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) => const AlbunsScreen();
}

// ── Atalho de álbum ───────────────────────────────────────────────────────────
/// Atalho visual usado para abrir rapidamente um álbum.
class _AlbumChip extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  const _AlbumChip({required this.album, required this.onTap});

  static const _icons = <String, IconData>{
    'snowflake': Icons.ac_unit,
    'wb_sunny': Icons.wb_sunny_outlined,
    'eco': Icons.eco_outlined,
    'local_florist': Icons.local_florist_outlined,
    'flight': Icons.flight_outlined,
    'restaurant': Icons.restaurant_outlined,
    'favorite': Icons.favorite_outline,
    'camera': Icons.camera_alt_outlined,
    'photo_album': Icons.photo_album_outlined,
    'home': Icons.home_outlined,
    'star': Icons.star_outline,
    'music_note': Icons.music_note_outlined,
  };

  Color get _color {
    try {
      return Color(int.parse('FF${album.cor.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final bg = Color.alphaBlend(color.withOpacity(0.13), Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[album.icone] ?? Icons.photo_album_outlined,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                album.nome,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _t1,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item de momento recente ───────────────────────────────────────────────────
/// Linha de resumo de um momento recente.
class _MomentTile extends StatelessWidget {
  final Registro registro;
  final VoidCallback onTap;
  const _MomentTile({required this.registro, required this.onTap});

  String _fmt(String iso) {
    // Converte a data persistida para o formato curto exibido na linha.
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
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = registro.fotos.isNotEmpty;
    const moods = ['😊', '😄', '😐', '😢', '😍'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13),
              ),
              child: SizedBox(
                width: 64,
                height: 64,
                child: hasPhoto
                    ? Image.memory(registro.fotos.first, fit: BoxFit.cover)
                    : Container(
                        color: _greenLight,
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: _green,
                          size: 26,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registro.titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _t1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (registro.album.isNotEmpty) registro.album,
                        _fmt(registro.dataHora),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 12, color: _t2),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                moods[registro.humor.clamp(0, 4)],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
