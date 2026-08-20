import java.util.Base64
import java.util.Properties

val googleTestAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val googleTestAndroidInterstitialAdUnitId =
    "ca-app-pub-3940256099942544/1033173712"

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()

if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseAdMobAppId =
    providers.gradleProperty("ADMOB_ANDROID_APP_ID").orNull
        ?: System.getenv("ADMOB_ANDROID_APP_ID")
val releaseDartDefines =
    providers.gradleProperty("dart-defines").orNull
        ?.split(',')
        ?.mapNotNull { encodedDefine ->
            runCatching {
                String(Base64.getDecoder().decode(encodedDefine), Charsets.UTF_8)
            }.getOrNull()
        }
        ?.associate { define ->
            val separatorIndex = define.indexOf('=')
            require(separatorIndex > 0) { "Invalid Flutter dart-define: $define" }
            define.substring(0, separatorIndex) to define.substring(separatorIndex + 1)
        }
        .orEmpty()

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

    if (releaseAdMobAppId.isNullOrBlank()) {
        throw GradleException(
            "Release build requires ADMOB_ANDROID_APP_ID as a Gradle property " +
                "or environment variable.",
        )
    }
    if (releaseAdMobAppId == googleTestAdMobAppId) {
        throw GradleException(
            "Release build must not use the Google test AdMob App ID.",
        )
    }

    val releaseInterstitialAdUnitId =
        releaseDartDefines["ADMOB_INTERSTITIAL_AD_UNIT_ID"]
    if (releaseInterstitialAdUnitId.isNullOrBlank()) {
        throw GradleException(
            "Release build requires --dart-define=" +
                "ADMOB_INTERSTITIAL_AD_UNIT_ID=<production-ad-unit-id>.",
        )
    }
    if (releaseInterstitialAdUnitId == googleTestAndroidInterstitialAdUnitId) {
        throw GradleException(
            "Release build must not use the Google test interstitial Ad Unit ID.",
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
                googleTestAdMobAppId
        }
        release {
            signingConfig = signingConfigs.findByName("release")
            manifestPlaceholders["admobAppId"] = releaseAdMobAppId.orEmpty()
            proguardFiles("proguard-rules.pro")
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
