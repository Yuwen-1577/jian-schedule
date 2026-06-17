import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystoreFile = file("key.properties")
if (keystoreFile.exists()) {
    keystoreFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.suda.yzune.class_schedule"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.suda.yzune.class_schedule"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = (keystoreProperties["storePassword"] as? String) ?: System.getenv("STORE_PASSWORD") ?: ""
            keyAlias = (keystoreProperties["keyAlias"] as? String) ?: System.getenv("KEY_ALIAS") ?: "release"
            keyPassword = (keystoreProperties["keyPassword"] as? String) ?: System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    lint {
        checkReleaseBuilds = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    applicationVariants.all {
        val variantVersion = versionName
        outputs.all {
            val outputImpl = this as? com.android.build.gradle.internal.api.BaseVariantOutputImpl
            if (outputImpl != null) {
                outputImpl.outputFileName = "JianSchedule_v${variantVersion}.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
