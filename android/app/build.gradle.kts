import java.util.Properties

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()

if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseBuildRequested) {
    if (!releaseSigningPropertiesFile.exists()) {
        throw GradleException(
            "Release signing requires android/key.properties. " +
                "Create it locally with storePassword, keyPassword, keyAlias, and storeFile.",
        )
    }

    val missingReleaseSigningProperties =
        listOf("storePassword", "keyPassword", "keyAlias", "storeFile").filter {
            releaseSigningProperties.getProperty(it).isNullOrBlank()
        }
    if (missingReleaseSigningProperties.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing: " +
                missingReleaseSigningProperties.joinToString(", "),
        )
    }

    val releaseKeystoreFile = rootProject.file(
        requireNotNull(releaseSigningProperties.getProperty("storeFile")),
    )
    if (!releaseKeystoreFile.isFile) {
        throw GradleException(
            "Release keystore was not found at: ${releaseKeystoreFile.path}",
        )
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.veles.kelimo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.veles.kelimo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningPropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(
                    requireNotNull(releaseSigningProperties.getProperty("storeFile")),
                )
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            signingConfig = signingConfigs.findByName("release")
            manifestPlaceholders["admobAppId"] =
                providers.gradleProperty("ADMOB_ANDROID_APP_ID").orNull
                    ?: System.getenv("ADMOB_ANDROID_APP_ID")
                    ?: "ca-app-pub-3940256099942544~3347511713"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
