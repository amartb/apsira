// The Android half of apsira_jobs: ZoneResync.kt (ZoneChangeReceiver and
// enqueueResync, from relay android/app/src/main/kotlin/com/apsiralabs/relay/
// ZoneModule.kt @ 09b28810) and the manifest that declares the receiver.
// The Kotlin setup follows android_alarm_manager_plus 5.1.2, a plugin RELAY and
// VIATICUM already build with AGP 9 and android.builtInKotlin=false.
group = "com.apsiralabs.apsira_jobs"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

// AGP 9 compiles Kotlin itself unless the app opts out with
// android.builtInKotlin=false, which `flutter create` writes (RELAY and
// VIATICUM do); then this module applies the Kotlin Gradle plugin.
val builtInKotlinEnabled =
    agpMajor >= 9 &&
        (providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() ?: true)

if (!builtInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.apsiralabs.apsira_jobs"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // workmanager_android's own minimum.
        minSdk = 23
    }
}

dependencies {
    // Nothing new reaches either APK: both artifacts are already in RELAY's and
    // VIATICUM's closure. ZoneResync.kt enqueues workmanager_android's own
    // BackgroundWorker, a project the app already builds; Flutter adds plugin
    // edges only for a plugin's direct dependencies, and apsira_jobs depends on
    // the app-facing `workmanager`, so the edge to its Android implementation is
    // named here. workmanager_android 0.10.9 declares androidx.work as an
    // `implementation` dependency, off its consumers' compile classpath, so the
    // same artifact at the version it pins is named too (as RELAY's and
    // VIATICUM's app build.gradle.kts did for ZoneModule.kt).
    implementation(project(":workmanager_android"))
    implementation("androidx.work:work-runtime:2.11.2")
}
