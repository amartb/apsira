// The Flutter 3.47.7 plugin template (`flutter create --template=plugin`) as
// apsira_lock pins it (AGP 9.1.0, Kotlin 2.4.0, the versions RELAY, VIATICUM
// and LYCEUM already pin), with ATRIUM's test-only JUnit 4 and Robolectric
// 4.17: the trust core is proven by Robolectric through example/android
// (`./gradlew --offline :apsira_link:testDebugUnitTest`).
group = "com.apsiralabs.apsira_link"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.apsiralabs.apsira_link"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    // Robolectric sees the merged manifest (the <queries>, no DEV_LINK).
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Test-only (never in an APK): ATRIUM's pins, from the Gradle cache; the
    // android-all jar for robolectric.properties' sdk=34 is cached too.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
}
