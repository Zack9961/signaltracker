import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final addressStringProvider = Provider(
  (ref) => "http://192.168.1.72:8000/ciao.json",
);

final coordinatesProvider = StreamProvider((ref) {
  return _determinePositionStream();
});

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

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Scritta 1", style: TextStyle(fontSize: 24)),
            coordinates.when(
              data: (position) {
                return Column(
                  children: [
                    Text(
                      "Latitude: ${position.latitude}",
                      style: const TextStyle(fontSize: 24),
                    ),
                    Text(
                      "Longitude: ${position.longitude}",
                      style: const TextStyle(fontSize: 24),
                    ),
                  ],
                );
              },
              error: (error, _) {
                return Text(
                  "Errore: $error",
                  style: const TextStyle(fontSize: 24),
                );
              },
              loading: () {
                return const Text(
                  "Caricamento...",
                  style: TextStyle(fontSize: 24),
                );
              },
            ),
            const Text("Scritta 4", style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Start Tracking"),
            ),
          ],
        ),
      ),
    );
  }
}
