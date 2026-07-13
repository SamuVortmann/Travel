// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:travel/database/database_helper.dart';
import 'package:travel/screens/albuns_screen.dart';
import 'package:travel/screens/album_detail_screen.dart';
import 'package:travel/screens/novo_registro_screen.dart';
import 'package:travel/screens/registro_detail_screen.dart';
import 'package:travel/screens/locations_screen.dart';
import 'package:travel/screens/insights_screen.dart';

const _green = Color(0xFF2E9E50);
const _greenLight = Color(0xFFE6F4EC);
const _bg = Color(0xFFF2F2F7);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);

// ── Root shell: holds the bottom nav and swaps content ───────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Which tab is active: 0=Home, 1=Timeline(Albums), 2=fab, 3=Map, 4=Insights
  // We skip index 2 (the FAB slot) — real tabs are 0,1,3,4
  int _tab = 0;
  final List<int> _revisions = List<int>.filled(5, 0);

  void _refreshTabAfterNavigation(int tab) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _revisions[tab]++);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  // Navigate to a new screen and reload when back
  Future<void> _go(Widget page) async {
    if (!mounted) return;
    final sourceTab = _tab;
    final route = MaterialPageRoute<void>(builder: (_) => page);
    await Navigator.push(context, route);

    // Navigator.push completes when pop starts. On desktop, rebuilding the
    // page underneath during the reverse transition can recursively update
    // MouseTracker. Wait until the route is fully removed, then rebuild in a
    // fresh frame.
    await route.completed;
    _refreshTabAfterNavigation(sourceTab);
  }

  Future<void> _openNovoRegistro() async {
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

      // ── Body: swap between tabs ──────────────────────────────────────────
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            key: ValueKey('home-${_revisions[0]}'),
            onNavigate: _go,
          ), // tab 0
          _AlbunsTab(
            key: ValueKey('albums-${_revisions[1]}'),
            onNavigate: _go,
          ), // tab 1
          const SizedBox.shrink(), // tab 2 = FAB placeholder (never shown)
          LocationsScreen(key: ValueKey('locations-${_revisions[3]}')), // tab 3
          InsightsScreen(key: ValueKey('insights-${_revisions[4]}')), // tab 4
        ],
      ),

      // ── FAB: the green + button in the notch ────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _openNovoRegistro,
        backgroundColor: _green,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom navigation bar with notch ────────────────────────────────
      bottomNavigationBar: BottomAppBar(
        color: _card,
        elevation: 8,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(), // creates the notch for FAB
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Left side: Home + Timeline
              _navItem(0, Icons.home_outlined, 'Home'),
              _navItem(1, Icons.photo_album_outlined, 'Álbuns'),
              // Center gap for the FAB
              const Expanded(child: SizedBox()),
              // Right side: Map + Insights
              _navItem(3, Icons.map_outlined, 'Locais'),
              _navItem(4, Icons.show_chart, 'Insights'),
            ],
          ),
        ),
      ),
    );
  }

  // Builds one nav item. Uses GestureDetector to avoid Windows mouse bug.
  Widget _navItem(int index, IconData icon, String label) {
    // Map tab index to visual position (skipping the FAB slot at index 2)
    // Tabs 0,1 are left; tabs 3,4 are right
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

// ── Home tab content ──────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final void Function(Widget) onNavigate;
  const _HomeTab({super.key, required this.onNavigate});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  // Keep this tab's scroll position alive when switching tabs
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
                  // Albums header
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

                  // Album chips
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

                  // Recent moments header
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

// ── Albums tab (reuses AlbunsScreen inline) ───────────────────────────────────
class _AlbunsTab extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _AlbunsTab({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) => const AlbunsScreen();
}

// ── Album chip ────────────────────────────────────────────────────────────────
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

// ── Recent moment tile ────────────────────────────────────────────────────────
class _MomentTile extends StatelessWidget {
  final Registro registro;
  final VoidCallback onTap;
  const _MomentTile({required this.registro, required this.onTap});

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
