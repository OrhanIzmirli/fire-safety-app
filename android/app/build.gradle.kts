plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase için gerekli
}

android {
    namespace = "com.example.firesafetapp_fixed_new" // ✅ AndroidManifest ile uyumlu
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.firesafetapp_fixed_new"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        // 🔑 AndroidManifest.xml içinde ${MAPS_API_KEY} placeholder'ını doldurur.
        // Key'i güvenli şekilde local.properties veya ortam değişkeninden okuyabilirsin.
        // local.properties örneği:
        //   MAPS_API_KEY=AIza....
        val mapsKey: String =
            (project.findProperty("MAPS_API_KEY") as String?)
                ?: System.getenv("MAPS_API_KEY")
                ?: ""

        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
