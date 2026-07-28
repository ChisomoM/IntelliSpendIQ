import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Opens the app database encrypted with SQLCipher from day one (D31,
/// D32). The passphrase comes from Keystore-backed secure storage —
/// never from source or shared preferences.
QueryExecutor openEncryptedConnection({required String passphrase}) {
  return LazyDatabase(() async {
    // Route sqlite3 loads to the bundled SQLCipher library on Android.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'intellispendiq.db'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Quotes in the passphrase would break the pragma; the generated
        // passphrase is hex so this is defensive only.
        final safe = passphrase.replaceAll("'", '');
        db.execute("PRAGMA key = '$safe';");
        // Fail fast if the key is wrong / library is not SQLCipher.
        final result = db.select('PRAGMA cipher_version;');
        if (result.isEmpty) {
          throw StateError(
            'SQLCipher is not available — refusing to open unencrypted DB',
          );
        }
      },
    );
  });
}
