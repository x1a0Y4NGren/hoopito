import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val allowUnsignedRelease =
    providers.gradleProperty("allowUnsignedRelease").orNull?.toBoolean() == true ||
        System.getenv("HOOPITO_ALLOW_UNSIGNED_RELEASE")?.toBoolean() == true
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(hasReleaseSigning || allowUnsignedRelease) {
            "Release signing is not configured. Add android/key.properties for an " +
                "upstream release, or explicitly enable an unsigned build only " +
                "for F-Droid/reproducibility builds."
        }
    }
}

android {
    namespace = "io.github.x1a0y4ngren.hooptrace"
    compileSdk = 36
    buildToolsVersion = "36.1.0"
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.github.x1a0y4ngren.hooptrace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.11.2")
}

flutter {
    source = "../.."
}

tasks.register("exportReleaseRuntimeCoordinates") {
    val output = layout.buildDirectory.file("reports/release-runtime-coordinates.txt")
    outputs.file(output)
    doLast {
        val coordinates =
            configurations
                .getByName("releaseRuntimeClasspath")
                .incoming
                .resolutionResult
                .allComponents
                .mapNotNull { component ->
                    val id = component.id
                        as? org.gradle.api.artifacts.component.ModuleComponentIdentifier
                    id?.let { "${it.group}:${it.module}:${it.version}" }
                }
                .filterNot { it.startsWith("io.flutter:") }
                .distinct()
                .sorted()
        val file = output.get().asFile
        file.parentFile.mkdirs()
        file.writeText(coordinates.joinToString(separator = "\n", postfix = "\n"))
    }
}
