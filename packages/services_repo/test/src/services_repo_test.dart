// ignore_for_file: prefer_const_constructors
import 'package:local_data/local_data.dart';
import 'package:net_source/net_source.dart';
import 'package:services_repo/services_repo.dart';
import 'package:test/test.dart';

void main() {
  group('ServicesRepo', () {
    test('can be instantiated', () async {
      final prefs = await SharedPrefs.init();
      final db = await LocalData.init(dbName: '', initialScript: []);
      final net = NetSource(baseUrl: '', host: '');
      expect(
        ServicesRepo(prefs: prefs, db: db, net: net),
        isNotNull,
      );
    });
  });
}
