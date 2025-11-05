import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ApiTestApp());
}

class ApiTestApp extends StatelessWidget {
  const ApiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Prayer Time Finder',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const PrayerFinderPage(),
    );
  }
}

class PrayerFinderPage extends StatefulWidget {
  const PrayerFinderPage({super.key});

  @override
  State<PrayerFinderPage> createState() => _PrayerFinderPageState();
}

class _PrayerFinderPageState extends State<PrayerFinderPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final String _geoKey = '2bbc738942944f4aaa163b7a8adcf2d8'; // OpenCage key
  final String _islamicKey = 'Si7D19vBuwTguHghVzhoLT9xYgv4yI5HilgF5MNMymLXBpr1'; // IslamicAPI key

  bool _loading = false;
  String? _error;
  Map<String, String>? _prayerTimes;
  double? _selectedLat;
  double? _selectedLon;

  Timer? _debounce;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _dropdownEntry;
  List<Map<String, dynamic>> _items = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onCityChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchCities(query);
    });
  }

  Future<void> _searchCities(String query) async {
    if (query.trim().length < 2) {
      _removeOverlay();
      return;
    }

    final url =
        'https://api.opencagedata.com/geocode/v1/json?q=$query&key=$_geoKey&limit=12';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final results = (data['results'] as List?) ?? [];
      _items = results
          .map((r) => {
                'formatted': r['formatted'],
                'lat': r['geometry']['lat'],
                'lon': r['geometry']['lng'],
              })
          .toList();

      if (_items.isEmpty) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
    } catch (_) {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);

    double width;
    try {
      final box =
          _textFieldKey.currentContext!.findRenderObject() as RenderBox;
      width = box.size.width;
    } catch (_) {
      width = MediaQuery.of(context).size.width - 32;
    }

    _dropdownEntry = OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 48),
        child: Material(
          elevation: 4,
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _items.map((s) {
                return InkWell(
                  onTap: () {
                    _controller.text = s['formatted'];
                    _selectedLat = (s['lat'] as num).toDouble();
                    _selectedLon = (s['lon'] as num).toDouble();

                    Future.delayed(const Duration(milliseconds: 100), () {
                      _removeOverlay();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    });
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['formatted'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_dropdownEntry!);
  }

  void _removeOverlay() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
  }

  Future<void> _fetchPrayerTimes() async {
    if (_selectedLat == null || _selectedLon == null) {
      setState(() => _error = 'Please select a city first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _prayerTimes = null;
    });

    try {
      final url =
          'https://islamicapi.com/api/v1/prayer-time/?lat=$_selectedLat&lon=$_selectedLon&method=3&school=1&api_key=$_islamicKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('Prayer API failed');
      final body = jsonDecode(res.body);
      if (body['status'] != 'success') throw Exception('API error');
      final times = Map<String, String>.from(body['data']['times']);
      setState(() => _prayerTimes = times);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Prayer Time Checker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                key: _textFieldKey,
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  labelText: 'Enter city name',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
                onChanged: _onCityChanged,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _fetchPrayerTimes,
              icon: const Icon(Icons.search),
              label: const Text('Find Prayer Times'),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_prayerTimes != null)
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(top: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prayer Times for ${_controller.text}',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Divider(),
                        ..._prayerTimes!.entries.map(
                          (e) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text(
                                  e.value,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
