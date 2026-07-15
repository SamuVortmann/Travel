// lib/screens/novo_registro_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chronicle/utils/photo_storage.dart';
import 'package:chronicle/database/database_helper.dart';

const _green = Color(0xFF2E9E50);
const _greenLight = Color(0xFFE6F4EC);
const _bg = Color(0xFFF2F2F7);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5EA);
const _t1 = Color(0xFF1C1C1E);
const _t2 = Color(0xFF6C6C70);
const _t3 = Color(0xFFAEAEB2);
const _moods = ['😊', '😄', '😐', '😢', '😍'];

/// Formulário responsável por criar e persistir um novo momento.
class NovoRegistroScreen extends StatefulWidget {
  final Album? albumPreSelecionado;
  const NovoRegistroScreen({super.key, this.albumPreSelecionado});
  @override
  State<NovoRegistroScreen> createState() => _NovoRegistroScreenState();
}

class _NovoRegistroScreenState extends State<NovoRegistroScreen> {
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _localCtrl = TextEditingController();

  int _humor = 1;
  DateTime _dt = DateTime.now();
  Album? _album;
  List<Album> _albuns = [];
  List<XFile> _fotos = [];
  bool _saving = false;
  bool _loading = true;
  bool _locating = false;
  double? _latitude;
  double? _longitude;

  // Uma única instância do ImagePicker é reutilizada pela câmera e pela galeria.
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _album = widget.albumPreSelecionado;
    _initAlbuns();
  }

  Future<void> _initAlbuns() async {
    // Carrega as opções de álbum e sincroniza uma seleção recebida pela tela.
    final a = await DatabaseHelper.instance.listarAlbuns();
    if (!mounted) return;
    setState(() {
      _albuns = a;
      _loading = false;
      if (_album != null && _album!.id != null) {
        _album = a.where((x) => x.id == _album!.id).firstOrNull ?? _album;
      }
    });
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _localCtrl.dispose();
    super.dispose();
  }

  // ── Câmera: captura uma única foto ───────────────────────────────────────
  Future<void> _pickCamera() async {
    // Em alguns aparelhos, pickImage pode falhar sem permissão para a câmera;
    // o bloco try/catch trata essa situação.
    try {
      final foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      // Confirma que o widget continua montado após a operação assíncrona.
      if (!mounted || foto == null) return;
      if (_fotos.length < 6) setState(() => _fotos.add(foto));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Câmera indisponível: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Galeria: seleciona uma ou várias fotos ───────────────────────────────
  Future<void> _pickGaleria() async {
    try {
      final fotos = await _picker.pickMultiImage(
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted) return;
      if (fotos.isNotEmpty) {
        // Preenche apenas as vagas restantes, respeitando o limite de seis fotos.
        setState(() => _fotos.addAll(fotos.take(6 - _fotos.length)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Galeria indisponível: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Painel de escolha da origem da foto ──────────────────────────────────
  // O contexto da tela é capturado antes da microtarefa. Dentro do painel,
  // usa-se seu próprio Navigator para fechá-lo sem remover a rota principal;
  // só depois é iniciada a seleção assíncrona da foto.
  void _showPhotoOptions() {
    final parentContext = context; // Preserva o contexto da tela principal.

    Future.microtask(() async {
      if (!parentContext.mounted) return;

      await showModalBottomSheet<void>(
        context: parentContext,
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),

              // Opção de câmera.
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: _green),
                title: const Text('Tirar foto com a câmera'),
                onTap: () {
                  // Fecha o painel usando o contexto de navegação do próprio painel.
                  Navigator.of(sheetCtx).pop();
                  // Abre a câmera somente depois que o painel foi fechado.
                  _pickCamera();
                },
              ),

              // Opção de galeria.
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _green,
                ),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickGaleria();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  // ── Painel de seleção do álbum ───────────────────────────────────────────
  void _showAlbumPicker() {
    final parentContext = context;

    Future.microtask(() async {
      if (!parentContext.mounted) return;

      await showModalBottomSheet<void>(
        context: parentContext,
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Escolher álbum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _t1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Exibe uma linha para cada álbum.
              ..._albuns.map(
                (a) => ListTile(
                  leading: const Icon(Icons.photo_album_outlined, color: _t3),
                  title: Text(a.nome),
                  trailing: _album?.id == a.id
                      ? const Icon(Icons.check, color: _green)
                      : null,
                  onTap: () {
                    setState(() => _album = a);
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  // ── Seletores de data e hora ─────────────────────────────────────────────
  void _pickDate() {
    Future.microtask(() async {
      if (!mounted) return;
      final d = await showDatePicker(
        context: context,
        initialDate: _dt,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        builder: (ctx, child) => Theme(
          data: Theme.of(
            ctx,
          ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
          child: child!,
        ),
      );
      if (!mounted || d == null) return;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dt),
        builder: (ctx, child) => Theme(
          data: Theme.of(
            ctx,
          ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
          child: child!,
        ),
      );
      if (!mounted) return;
      setState(
        () => _dt = DateTime(
          d.year,
          d.month,
          d.day,
          t?.hour ?? _dt.hour,
          t?.minute ?? _dt.minute,
        ),
      );
    });
  }

  Future<void> _useCurrentLocation() async {
    // Valida serviço e permissão antes de capturar as coordenadas atuais.
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Ative a localização do aparelho e tente novamente.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          permission == LocationPermission.deniedForever
              ? 'Permissão negada permanentemente. Libere-a nas configurações.'
              : 'Permissão de localização negada.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final label =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _localCtrl.text = label;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Salvamento ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    // Valida o formulário, converte as fotos e grava o registro no banco.
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione um título ao momento.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final album = _album;
    if (album == null || album.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um álbum para o momento.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final persistedPhotos = await PhotoStorage.readAll(
        _fotos,
      ).timeout(const Duration(seconds: 30));
      final r = Registro(
        albumId: album.id,
        titulo: titulo,
        descricao: _descCtrl.text.trim(),
        local: _localCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        dataHora: _dt.toIso8601String(),
        humor: _humor,
        tags: '',
        album: album.nome,
        fotos: persistedPhotos,
      );

      await DatabaseHelper.instance
          .inserirRegistro(r)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Momento salvo!'),
          backgroundColor: _green,
        ),
      );

      // Adia o retorno para fora do quadro atual do evento de ponteiro.
      Future.microtask(() {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = e is TimeoutException
          ? 'O salvamento demorou demais. Volte à tela inicial e confira o momento antes de tentar novamente.'
          : 'Erro ao salvar: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _fmtDt() {
    // Formata a data escolhida sem depender da configuração regional do aparelho.
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
    final h = _dt.hour.toString().padLeft(2, '0');
    final min = _dt.minute.toString().padLeft(2, '0');
    return '${_dt.day} ${m[_dt.month - 1]} ${_dt.year} · $h:$min';
  }

  // ── Construção da interface ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        // GestureDetector evita uma falha no rastreamento do mouse no Windows.
        leading: GestureDetector(
          onTap: () => Future.microtask(() {
            if (mounted) Navigator.maybePop(context);
          }),
          child: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text(
          'Novo momento',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          GestureDetector(
            onTap: _saving ? null : () => Future.microtask(_save),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Salvar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Área de fotos ──────────────────────────────────────
                  if (_fotos.isEmpty)
                    // Estado vazio: área ampla para adicionar fotos.
                    GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _green, width: 1.5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 32,
                              color: _green,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Adicionar fotos',
                              style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Miniaturas das fotos e botão para adicionar mais.
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _fotos.length + (_fotos.length < 6 ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          // A última posição contém o botão de adicionar.
                          if (i == _fotos.length) {
                            return GestureDetector(
                              onTap: _showPhotoOptions,
                              child: Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _green),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: _green,
                                  size: 28,
                                ),
                              ),
                            );
                          }
                          // Miniatura da foto com botão de remoção.
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: FutureBuilder(
                                  future: _fotos[i].readAsBytes(),
                                  builder: (context, snapshot) {
                                    final bytes = snapshot.data;
                                    if (bytes == null) {
                                      return const SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    return Image.memory(
                                      bytes,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _fotos.removeAt(i)),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Título ─────────────────────────────────────────────
                  TextField(
                    controller: _tituloCtrl,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _t1,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Título do momento...',
                      hintStyle: TextStyle(
                        color: _t3,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),

                  // ── Descrição ──────────────────────────────────────────
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    minLines: 2,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _t2,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Escreva sobre este momento...',
                      hintStyle: TextStyle(color: _t3, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),

                  const Divider(color: _border),
                  const SizedBox(height: 8),

                  // ── Seletor de humor ───────────────────────────────────
                  const Text(
                    'Como você se sentiu?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _t2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_moods.length, (i) {
                      final sel = _humor == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _humor = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? _greenLight : _card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel ? _green : _border,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _moods[i],
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // ── Localização ─────────────────────────────────────────
                  _metaRow(
                    icon: Icons.location_on_outlined,
                    child: TextField(
                      controller: _localCtrl,
                      style: const TextStyle(fontSize: 14, color: _t1),
                      decoration: const InputDecoration(
                        hintText: 'Local (opcional)',
                        hintStyle: TextStyle(color: _t3),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    trailing: GestureDetector(
                      onTap: _locating ? null : _useCurrentLocation,
                      child: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green,
                              ),
                            )
                          : const Tooltip(
                              message: 'Usar localização atual',
                              child: Icon(
                                Icons.my_location,
                                size: 20,
                                color: _green,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Data e hora ─────────────────────────────────────────
                  _metaRow(
                    icon: Icons.calendar_today_outlined,
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Text(
                        _fmtDt(),
                        style: const TextStyle(fontSize: 14, color: _t1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Álbum ───────────────────────────────────────────────
                  _metaRow(
                    icon: Icons.photo_album_outlined,
                    child: GestureDetector(
                      onTap: _showAlbumPicker,
                      child: Text(
                        _album?.nome ?? 'Selecionar álbum (obrigatório)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _album != null ? _t1 : _t3,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: _t3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Botão de salvamento ─────────────────────────────────
                  GestureDetector(
                    onTap: _saving ? null : () => Future.microtask(_save),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _saving ? _green.withOpacity(0.5) : _green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Salvar momento',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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

  Widget _metaRow({
    // Cria uma linha padronizada para os metadados do momento.
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _t3),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
