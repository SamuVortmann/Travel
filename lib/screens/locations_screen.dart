import 'package:flutter/material.dart';
import 'package:chronicle/database/database_helper.dart';
import 'package:chronicle/screens/registro_detail_screen.dart';
import 'package:chronicle/utils/app_constants.dart';

/// Agrupa e apresenta os momentos de acordo com o local informado.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});
  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  // Mantém os registros carregados e o estado visual da consulta.
  bool _loading = true;
  List<Registro> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Filtra os registros sem localização antes de atualizar a tela.
    final all = await DatabaseHelper.instance.listarRegistros();
    if (!mounted) return;
    setState(() {
      _records = all.where((r) => r.local.trim().isNotEmpty).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Registro>>{};
    for (final r in _records) {
      grouped.putIfAbsent(r.local.trim(), () => []).add(r);
    }
    final locations = grouped.keys.toList()
      ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Locais',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : locations.isEmpty
          ? const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Nenhum local registrado',
              subtitle: 'Use o GPS ou escreva um local ao criar um momento.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: kGreen,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: locations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final name = locations[i];
                  final items = grouped[name]!;
                  return ExpansionTile(
                    collapsedBackgroundColor: kCard,
                    backgroundColor: kCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: kBorder),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: kBorder),
                    ),
                    leading: const Icon(Icons.place_outlined, color: kGreen),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${items.length} momento${items.length == 1 ? '' : 's'}',
                    ),
                    children: items
                        .map(
                          (r) => ListTile(
                            title: Text(r.titulo),
                            subtitle: Text(formatDate(r.dataHora)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final full = r.id == null
                                  ? r
                                  : await DatabaseHelper.instance
                                        .buscarRegistro(r.id!);
                              if (!context.mounted || full == null) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RegistroDetailScreen(registro: full),
                                ),
                              );
                              _load();
                            },
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
    );
  }
}
