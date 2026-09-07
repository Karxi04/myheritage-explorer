plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    id("kotlin-android")

    // Flutter Gradle Plugin must be applied
    // after Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.myheritage_explorer"

    // Required by current Flutter plugins
    compileSdk = 36

    // Highest NDK version required by current plugins
    ndkVersion = "28.2.13676358"

    compileOptions {
        // ========================================================
        // REQUIRED FOR flutter_local_notifications
        // ========================================================
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.myheritage_explorer"

        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Recommended for notification/plugin compatibility
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ================================================================
// REQUIRED FOR flutter_local_notifications
// ================================================================

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}

flutter {
    source = "../.."
}