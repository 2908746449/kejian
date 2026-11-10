plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.kejian.kejian"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.kejian.kejian"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Keep plugin libraries on the same ABIs as the Flutter engine and AOT app.
        // Otherwise --target-platform android-arm64 also advertises incomplete
        // armeabi-v7a/x86_64 payloads contributed by native dependencies.
        val flutterAbis = mapOf(
            "android-arm" to "armeabi-v7a",
            "android-arm64" to "arm64-v8a",
            "android-x64" to "x86_64",
        )
        if (providers.gradleProperty("split-per-abi").orNull != "true") {
            val targetPlatforms = providers.gradleProperty("target-platform").orNull
                ?.split(",") ?: flutterAbis.keys.toList()
            ndk {
                abiFilters.clear()
                abiFilters.addAll(targetPlatforms.map { platform ->
                    requireNotNull(flutterAbis[platform]) { "Unsupported Flutter platform: $platform" }
                })
            }
        }
    }

    signingConfigs {
        getByName("debug") {
            // Publish a JAR signature as well as the modern APK signatures for
            // installers that inspect the archive before delegating to Android.
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

dependencies {
    // Bundled Chinese recognizer: no network or model download at runtime.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
