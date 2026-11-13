
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.streamia.streamia_player"
    compileSdk = 36
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.streamia.streamia_player"
        minSdk = 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val permanentDebugKeystore = file(
        "${System.getProperty("user.home")}/.android/debug.keystore"
    )

    val isDebugBuildRequested = gradle.startParameter.taskNames.any { task ->
        task.contains("debug", ignoreCase = true)
    }

    if (isDebugBuildRequested) {
        require(permanentDebugKeystore.isFile) {
            "Permanent Streamia debug keystore missing: $permanentDebugKeystore"
        }
    }

    val signingVars = listOf("KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")
    val hasReleaseSigning = signingVars.all { !System.getenv(it).isNullOrBlank() } &&
        file("upload-keystore.jks").isFile

    signingConfigs {
        getByName("debug") {
            storeFile = permanentDebugKeystore
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        if (hasReleaseSigning) {
            create("release") {
                storeFile = file("upload-keystore.jks")
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs["debug"]
        }

        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
