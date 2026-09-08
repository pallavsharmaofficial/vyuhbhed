import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties, which is git-ignored and
// created on the release machine (see docs/RELEASE.md). Local `flutter run
// --release` still works without it: we fall back to the debug keystore.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "in.vickysolutions.vyuhbhed"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "in.vickysolutions.vyuhbhed"
        // Android 10+. The on-device LiteRT-LM runtime needs API 29 GPU delegates.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP 9 API. Keeps only the locales we actually translate out of the APK.
    androidResources {
        localeFilters += setOf("en", "hi")
    }

    // Qualcomm NPU delegate libraries, shipped by flutter_gemma for four chip
    // generations at once. Measured on this app:
    //
    //   with QNN     134 MB APK   (124.7 MB of native libraries)
    //   without QNN   ~80 MB APK  (54.4 MB saved)
    //
    // Any given phone uses at most one of the four, so most of that 54 MB is
    // dead weight on any individual device — but there is no way to pick at
    // build time, and dropping them means CPU/GPU inference on Snapdragon,
    // which is most of the Indian market.
    //
    // Left ON by default: a counsellor that answers slowly is a worse product
    // than a larger download, and the 584 MB model dwarfs this either way.
    // Flip it for a smaller build to share directly:
    //
    //   flutter build apk --release --target-platform android-arm64 \
    //     -PsaathExcludeQnn=true
    //
    // Measure tokens/sec on real hardware before making this permanent.
    if (project.findProperty("saathExcludeQnn") == "true") {
        packaging {
            jniLibs {
                excludes += setOf("**/libQnn*.so")
            }
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        // NOTE: ABI selection is NOT set here. The Flutter Gradle plugin
        // overwrites `ndk.abiFilters` from the tool's own --target-platform,
        // so a filter in this file is a silent no-op (verified: it changed
        // nothing in the built bundle). Release builds must pass
        //   flutter build appbundle --release --target-platform android-arm64
        // and docs/RELEASE.md and CI both do. Why arm64 only: flutter_gemma
        // ships LiteRT-LM native libraries for arm64-v8a alone, so an
        // armeabi-v7a or x86_64 build installs fine and then cannot load a
        // model at all.
        release {

            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
