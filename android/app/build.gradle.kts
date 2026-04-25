plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.continuum.rider"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "in.continuum.rider"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("CONTINUUM_KEYSTORE_PATH") ?: "debug"
            if (keystorePath != "debug") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("CONTINUUM_KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("CONTINUUM_KEY_ALIAS") ?: "continuum"
                keyPassword = System.getenv("CONTINUUM_KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            val hasKeystore = System.getenv("CONTINUUM_KEYSTORE_PATH") != null
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
