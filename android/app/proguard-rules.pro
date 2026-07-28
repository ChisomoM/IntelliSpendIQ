# SQLCipher / sqlite3 native bindings are reached via JNI, so R8 cannot
# see the references and would otherwise strip them from release builds.
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# The capture bridge classes are referenced from the manifest and by
# Flutter's platform-channel wiring rather than from Kotlin call sites.
-keep class com.intellispendiq.app.** { *; }
