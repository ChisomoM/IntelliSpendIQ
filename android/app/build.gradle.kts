import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore =
    System.getenv("ANDROID_KEYSTORE_PATH") != null || keystorePropertiesFile.exists()

android {
    namespace = "com.intellispendiq.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.intellispendiq.app"
        // API 26 baseline (D12): Keystore + notification behaviour we rely
        // on. Revisit if a tester's device is older.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "IntelliSpendIQ"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                if (System.getenv("ANDROID_KEYSTORE_PATH") != null) {
                    storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
                    keyAlias = System.getenv("ANDROID_KEYSTORE_ALIAS")
                    keyPassword = System.getenv("ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD")
                    storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                } else {
                    keyAlias = keystoreProperties["keyAlias"] as String?
                    keyPassword = keystoreProperties["keyPassword"] as String?
                    storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                    storePassword = keystoreProperties["storePassword"] as String?
                }
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Sideload builds (D02) work without a release keystore by
            // falling back to debug signing, so an APK can be produced
            // on a fresh clone. Configure key.properties before sharing.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.2.10")
}
