// import 'package:influxdb_client/api.dart';

// class InfluxDBClient {
//   final String _url;
//   final String _token;
//   final String _org;
//   final String _bucket;

//   InfluxDBClient({
//     required String url,
//     required String token,
//     required String org,
//     required String bucket,
//   })  : _url = url,
//         _token = token,
//         _org = org,
//         _bucket = bucket;

//   Future<void> writeData(Point point) async {
//     final client = InfluxDBClientV2(
//       url: _url,
//       token: _token,
//     );

//     final writeApi = client.writeApiV2(
//       org: _org,
//       bucket: _bucket,
//     );

//     await writeApi.writePoint(point);
//   }
// }
