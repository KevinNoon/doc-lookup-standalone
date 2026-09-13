plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.knoon.doc_lookup_standalone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Distinct from com.knoon.doc_lookup so this can install side-by-side
        // with the cloud-synced app on the same device.
        applicationId = "com.knoon.doc_lookup_standalone"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: no dedicated signing key exists for this app yet — release
            // builds fall back to debug signing so `flutter build apk --release`
            // works out of the box. Generate a real upload keystore before
            // distributing/selling this build (see android/key.properties.example
            // for the pattern used by the original doc-lookup-app project).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
