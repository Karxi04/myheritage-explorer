part of '../traveler_pages.dart';

class WeatherReminderPage extends StatefulWidget {
  const WeatherReminderPage({super.key});

  @override
  State<WeatherReminderPage> createState() => _WeatherReminderPageState();
}

class _WeatherReminderPageState extends State<WeatherReminderPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? current;
  List<Map<String, dynamic>> hourly = const [];
  String reminder = 'Checking the local weather...';

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final position = await determinePosition();
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m,precipitation,rain,weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Weather service returned ${response.statusCode}.');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final currentData = Map<String, dynamic>.from(json['current'] as Map? ?? const {});
      final hourlyData = Map<String, dynamic>.from(json['hourly'] as Map? ?? const {});
      final times = List<dynamic>.from(hourlyData['time'] as List? ?? const []);
      final temperatures = List<dynamic>.from(hourlyData['temperature_2m'] as List? ?? const []);
      final precipitation = List<dynamic>.from(hourlyData['precipitation_probability'] as List? ?? const []);
      final codes = List<dynamic>.from(hourlyData['weather_code'] as List? ?? const []);
      final now = DateTime.now();
      final upcoming = <Map<String, dynamic>>[];
      for (var i = 0; i < times.length && upcoming.length < 8; i++) {
        final time = DateTime.tryParse(times[i].toString());
        if (time != null && time.isAfter(now.subtract(const Duration(minutes: 30)))) {
          upcoming.add({
            'time': time,
            'temperature': i < temperatures.length ? temperatures[i] : null,
            'precipitation': i < precipitation.length ? precipitation[i] : null,
            'weatherCode': i < codes.length ? codes[i] : null,
          });
        }
      }
      final maxRainChance = upcoming.fold<num>(0, (value, item) {
        final chance = item['precipitation'] is num ? item['precipitation'] as num : 0;
        return max(value, chance);
      });
      final temperature = currentData['temperature_2m'] is num ? currentData['temperature_2m'] as num : 0;
      final rain = currentData['rain'] is num ? currentData['rain'] as num : 0;
      final wind = currentData['wind_speed_10m'] is num ? currentData['wind_speed_10m'] as num : 0;
      String advice;
      if (rain > 0 || maxRainChance >= 60) {
        advice = 'Rain is likely. Bring an umbrella and consider indoor heritage stops.';
      } else if (temperature >= 33) {
        advice = 'Hot conditions detected. Carry water, use sun protection and take regular indoor breaks.';
      } else if (wind >= 35) {
        advice = 'Strong wind is possible. Avoid exposed areas and secure loose belongings.';
      } else {
        advice = 'Conditions look suitable for outdoor exploration. Check again before a long activity.';
      }
      if (!mounted) return;
      setState(() {
        current = currentData;
        hourly = upcoming;
        reminder = advice;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  String weatherLabel(dynamic code) {
    final value = code is num ? code.toInt() : -1;
    if (value == 0) return 'Clear';
    if ([1, 2, 3].contains(value)) return 'Cloudy';
    if ([45, 48].contains(value)) return 'Fog';
    if (value >= 51 && value <= 67) return 'Rain';
    if (value >= 71 && value <= 77) return 'Snow';
    if (value >= 80 && value <= 82) return 'Showers';
    if (value >= 95) return 'Thunderstorm';
    return 'Mixed conditions';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Weather Reminder',
              subtitle: 'Live conditions and travel advice for your current location.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: loading ? null : loadWeather,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ExplorerCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 30,
                                    backgroundColor: ExplorerColors.navySoft,
                                    foregroundColor: ExplorerColors.navy,
                                    child: Icon(Icons.cloud_off_outlined, size: 30),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: ExplorerColors.muted),
                                  ),
                                  const SizedBox(height: 15),
                                  FilledButton.icon(
                                    onPressed: loadWeather,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: ExplorerColors.navy,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          color: Color(0x26FFFFFF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.wb_cloudy_outlined,
                                          color: Colors.white,
                                          size: 38,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${current?['temperature_2m'] ?? '-'} °C',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 34,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              weatherLabel(current?['weather_code']),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const ExplorerStatusBadge(
                                        label: 'LIVE',
                                        tone: ExplorerStatusTone.warning,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _WeatherMetric(
                                          icon: Icons.water_drop_outlined,
                                          label: 'Humidity',
                                          value: '${current?['relative_humidity_2m'] ?? '-'}%',
                                        ),
                                      ),
                                      Expanded(
                                        child: _WeatherMetric(
                                          icon: Icons.umbrella_outlined,
                                          label: 'Rain',
                                          value: '${current?['rain'] ?? 0} mm',
                                        ),
                                      ),
                                      Expanded(
                                        child: _WeatherMetric(
                                          icon: Icons.air_rounded,
                                          label: 'Wind',
                                          value: '${current?['wind_speed_10m'] ?? '-'} km/h',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ExplorerCard(
                              backgroundColor: ExplorerColors.goldSoft,
                              borderColor: const Color(0xFFF0D894),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: ExplorerColors.gold,
                                    foregroundColor: ExplorerColors.navy,
                                    child: Icon(Icons.notifications_active_outlined),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Travel Reminder',
                                          style: TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          reminder,
                                          style: const TextStyle(
                                            color: ExplorerColors.text,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const ExplorerSectionTitle('Next Hours'),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 142,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: hourly.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = hourly[index];
                                  return SizedBox(
                                    width: 112,
                                    child: ExplorerCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            DateFormat.jm().format(item['time'] as DateTime),
                                            style: const TextStyle(
                                              color: ExplorerColors.navy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          const Icon(
                                            Icons.cloud_outlined,
                                            color: ExplorerColors.navy,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${item['temperature'] ?? '-'} °C',
                                            style: const TextStyle(
                                              color: ExplorerColors.text,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${item['precipitation'] ?? 0}% rain',
                                            style: const TextStyle(
                                              color: ExplorerColors.muted,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Weather data provided by Open-Meteo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ExplorerColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 9),
        ),
      ],
    );
  }
}
