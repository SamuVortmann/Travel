import 'package:flutter/material.dart';
import 'package:travel/database/database_helper.dart';
import 'package:travel/utils/app_constants.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _loading = true;
  List<Registro> _records = [];
  List<Album> _albums = [];
  int _withPhotos = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await DatabaseHelper.instance.listarRegistros();
    final albums = await DatabaseHelper.instance.listarAlbuns();
    final withPhotos = await DatabaseHelper.instance.totalRegistrosComFotos();
    if (!mounted) return;
    setState(() {
      _records = records;
      _albums = albums;
      _withPhotos = withPhotos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final withLocation = _records
        .where((r) => r.local.trim().isNotEmpty)
        .length;
    final moodCounts = List<int>.filled(kMoods.length, 0);
    for (final r in _records) {
      if (r.humor >= 0 && r.humor < moodCounts.length) moodCounts[r.humor]++;
    }
    final maxMood = moodCounts.fold<int>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Insights',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : RefreshIndicator(
              onRefresh: _load,
              color: kGreen,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          'Momentos',
                          _records.length.toString(),
                          Icons.auto_stories_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _stat(
                          'Álbuns',
                          _albums.length.toString(),
                          Icons.photo_album_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          'Com fotos',
                          _withPhotos.toString(),
                          Icons.photo_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _stat(
                          'Com local',
                          withLocation.toString(),
                          Icons.place_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Humores registrados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: List.generate(kMoods.length, (i) {
                        final fraction = maxMood == 0
                            ? 0.0
                            : moodCounts[i] / maxMood;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                kMoods[i],
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 10,
                                    backgroundColor: kBorderLight,
                                    color: kGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 24,
                                child: Text('${moodCounts[i]}'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kGreen),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(color: kTextSecondary)),
      ],
    ),
  );
}
