# SQLCipher / sqlite3 native bindings are reached via JNI, so R8 cannot
# see the references and would otherwise strip them from release builds.
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# The capture bridge classes are referenced from the manifest and by
# Flutter's platform-channel wiring rather than from Kotlin call sites.
-keep class com.intellispendiq.app.** { *; }

# google_mlkit_text_recognition references optional language-specific
# recognizer classes (Chinese/Devanagari/Japanese/Korean) for scripts we
# don't bundle a model for, since we only depend on the Latin recognizer.
# These classes are intentionally absent at build time, so tell R8 not to
# fail on them rather than trying to keep classes that don't exist.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
