// The Flutter 3.47.7 app template (`flutter create --platforms=android`).
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.apsiralabs.apsira_jobs_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (vendored, reached through apsira_notify
        // since the alarm scheduler, F1) needs Java library desugaring, as in
        // every app that consumes apsira_jobs (RELAY's and VIATICUM's android/app).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.apsiralabs.apsira_jobs_example"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Debug builds only: the example is a compile proof, never released.
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
    // RELAY's pin, as apsira_notify's example.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
