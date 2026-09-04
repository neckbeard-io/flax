import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties, which is gitignored and
// absent from a fresh clone. CI materialises it from repository secrets (see
// .github/workflows/release.yml). When it is missing we fall back to the debug
// keystore so `flutter build apk --release` still works for a casual clone —
// but those APKs are NOT upgrade-compatible with the shared test builds,
// because the debug keystore is generated per machine.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.flaxplayer.flax"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flaxplayer.flax"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        val gitVersionName = try {
            val process = ProcessBuilder("git", "describe", "--tags", "--abbrev=0", "--match", "v*")
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .start()
            val tag = process.inputStream.bufferedReader().readText().trim()
            if (tag.startsWith("v")) tag.substring(1) else tag
        } catch (_: Exception) {
            "0.1.0"
        }

        val gitVersionCode = try {
            val process = ProcessBuilder("git", "rev-list", "--count", "HEAD")
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .start()
            process.inputStream.bufferedReader().readText().trim().toIntOrNull() ?: 1
        } catch (_: Exception) {
            1
        }

        val resolvedVersionName = if (flutter.versionName != null && flutter.versionName != "0.1.0" && flutter.versionName != "1.0.0") {
            flutter.versionName
        } else if (gitVersionName.isNotEmpty()) {
            gitVersionName
        } else {
            "0.1.0"
        }

        val resolvedVersionCode = if (flutter.versionCode != null && flutter.versionCode > 1) {
            flutter.versionCode
        } else {
            gitVersionCode
        }

        versionCode = resolvedVersionCode
        versionName = resolvedVersionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
