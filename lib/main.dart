import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'package:flutter/services.dart';
import 'package:influxdb_client/api.dart';
import 'package:device_info_plus/device_info_plus.dart';

// final addressStringProvider = Provider(
//   (ref) => "http://192.168.1.72:8000/ciao.json",
// );

final InfluxDBClient influxDBClient = InfluxDBClient(
  url: 'http://informatica-iot.freeddns.org:8086',
  token:
      'qt5kHYb2Wwg19lbGEOe3BmVJhlMf6ZxfDu_Z7Lrhiiiv9FTEGKiD_pJzkDa_qSlUPLPm0zI-1yE6THb4kg-0kA==',
  org: 'uniurb',
  bucket: 'esercitazioni',
  debug: kDebugMode,
);

// Puoi definire un provider per il client InfluxDB se preferisci
final influxDBClientProvider = Provider<InfluxDBClient>(
  (ref) => influxDBClient,
);

final coordinatesProvider = StreamProvider((ref) {
  return _determinePositionStream();
});

final mobileSignalProvider = StreamProvider((ref) async* {
  final internetSignal = FlutterInternetSignal();
  while (true) {
    try {
      final mobileSignalStrength = await internetSignal
          .getMobileSignalStrength();
      yield mobileSignalStrength;
    } on PlatformException {
      if (kDebugMode) print('Error get mobile signal.');
    }
    await Future.delayed(const Duration(seconds: 2));
  }
});

final deviceIdProvider = FutureProvider((ref) {
  return _getDeviceId();
});

Future<String> _getDeviceId() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  return androidInfo.model; // e.g. "Moto G (4)"
}

Stream<Position> _determinePositionStream() async* {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    throw Exception('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      throw Exception('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    throw Exception(
      'Location permissions are permanently denied, we cannot request permissions.',
    );
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  await for (var position in Geolocator.getPositionStream()) {
    yield position;
  }
}

Point createDataPointGPS({
  required double latitude,
  required double longitude,
  required String location,
  required String room,
  required String deviceId,
}) {
  return Point('corso_IoT')
      .addTag('location', location)
      .addTag('room', room)
      .addTag('deviceId', deviceId)
      .addField('latitude', latitude)
      .addField('longitude', longitude);
}

Point createDataPointSignal({
  required int mobileSignal,
  required String location,
  required String room,
  required String deviceId,
}) {
  return Point('corso_IoT')
      .addTag('location', location)
      .addTag('room', room)
      .addTag('deviceId', deviceId)
      .addField('mobileSignal', mobileSignal);
}

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Signal Tracker'),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinates = ref.watch(coordinatesProvider);
    final mobileSignal = ref.watch(mobileSignalProvider);
    final influxDBClient = ref.watch(
      influxDBClientProvider,
    ); // Ottieni l'istanza del client
    final deviceIdAsyncValue = ref.watch(deviceIdProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            mobileSignal.when(
              data: (mobileSignal) {
                if (mobileSignal != null) {
                  final point = createDataPointSignal(
                    mobileSignal: mobileSignal,
                    location: 'Marche',
                    room: 'PesaroUrbino',
                    deviceId: deviceIdAsyncValue.value.toString(),
                  );
                  _sendDataToInfluxDB(influxDBClient, point);
                }
                return Column(
                  children: [
                    Text(
                      'Mobile signal: $mobileSignal [dBm]\n',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                );
              },
              error: (error, _) {
                return Text(
                  "Errore: $error \n",
                  style: const TextStyle(fontSize: 24),
                );
              },
              loading: () {
                // return const Text(
                //   "Caricamento... \n",
                //   style: TextStyle(fontSize: 24),
                // );
                return const CircularProgressIndicator();
              },
            ),
            coordinates.when(
              data: (position) {
                final currentPosition = coordinates.valueOrNull;
                if (currentPosition != null) {
                  final point = createDataPointGPS(
                    latitude: currentPosition.latitude,
                    longitude: currentPosition.longitude,
                    location: 'Marche',
                    room: 'PesaroUrbino',
                    deviceId: deviceIdAsyncValue.value.toString(),
                  );
                  _sendDataToInfluxDB(influxDBClient, point);
                }
                return Column(
                  children: [
                    Text(
                      "Latitude: ${position.latitude}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      "Longitude: ${position.longitude}\n",
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                );
              },
              error: (error, _) {
                return Text(
                  "Errore: $error \n",
                  style: const TextStyle(fontSize: 24),
                );
              },
              loading: () {
                // return const Text(
                //   "Caricamento...\n",
                //   style: TextStyle(fontSize: 24),
                // );
                return const CircularProgressIndicator();
              },
            ),
            deviceIdAsyncValue.when(
              data: (deviceId) {
                return Column(
                  children: [
                    Text(
                      'Device Info: $deviceId \n',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                );
              },
              error: (error, _) {
                return Text(
                  "Errore: $error \n",
                  style: const TextStyle(fontSize: 24),
                );
              },
              loading: () {
                // return const Text(
                //   "Caricamento...\n",
                //   style: TextStyle(fontSize: 24),
                // );
                return const CircularProgressIndicator();
              },
            ),
            // const SizedBox(height: 16),
            // ElevatedButton(
            //   onPressed: () {},
            //   child: const Text("Start Tracking"),
            // ),
          ],
        ),
      ),
    );
  }

  // Funzione per inviare i dati a InfluxDB
  void _sendDataToInfluxDB(InfluxDBClient client, Point point) async {
    var writeApi = WriteService(client);
    try {
      await writeApi.write(point);
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante l\'invio a InfluxDB: $e');
      }
    }
  }
}
