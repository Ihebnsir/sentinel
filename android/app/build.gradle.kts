import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// SEN-01 : signature release lue dans android/key.properties (ignoré par git).
// Le keystore est HORS du dépôt ; les mots de passe peuvent venir des
// variables d'environnement (tools/release/build_release.ps1 les demande).
// Voir docs/RELEASE.md.
val keyPropertiesFile: File = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.isFile) keyPropertiesFile.inputStream().use { load(it) }
}

fun releaseSecret(key: String, env: String): String? =
    keyProperties.getProperty(key)?.takeIf { it.isNotEmpty() } ?: System.getenv(env)

// Arrête tout build release incomplet : plus jamais de repli sur la clé debug.
fun checkReleaseSigning() {
    fun fail(reason: String): Nothing =
        throw GradleException("Signature release impossible : $reason Voir docs/RELEASE.md.")
    if (!keyPropertiesFile.isFile) fail("android/key.properties est absent.")
    val path = keyProperties.getProperty("storeFile") ?: fail("storeFile manque dans key.properties.")
    val store = file(path).canonicalFile
    val repository = rootProject.rootDir.parentFile.canonicalFile
    if (store.startsWith(repository)) fail("le keystore doit être HORS du dépôt ($store).")
    if (!store.isFile) fail("keystore introuvable ($store).")
    if (keyProperties.getProperty("keyAlias").isNullOrEmpty()) fail("keyAlias manque dans key.properties.")
    if (releaseSecret("storePassword", "SENTINEL_STORE_PASSWORD").isNullOrEmpty()) {
        fail("mot de passe du keystore absent (SENTINEL_STORE_PASSWORD).")
    }
    if (releaseSecret("keyPassword", "SENTINEL_KEY_PASSWORD").isNullOrEmpty()) {
        fail("mot de passe de la clé absent (SENTINEL_KEY_PASSWORD).")
    }
}

android {
    namespace = "com.iheb.sentinel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.iheb.sentinel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyProperties.getProperty("storeFile")?.let { storeFile = file(it) }
            storePassword = releaseSecret("storePassword", "SENTINEL_STORE_PASSWORD")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = releaseSecret("keyPassword", "SENTINEL_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // SEN-01 : clé de publication uniquement (jamais la clé debug).
            signingConfig = signingConfigs.getByName("release")
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

// Vérifié au début de chaque build release (APK ou bundle), pas en debug.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst { checkReleaseSigning() }
}

dependencies {
    // SEN-08 : versions plus récentes que celles tirées par le moteur Flutter.
    // Stables, publiées depuis plus de 2 semaines (vérifié le 24/10/2026).
    // Les bibliothèques d'un même groupe AndroidX s'alignent entre elles.
    // core reste en 1.18.0 : 1.19 exige compileSdk 37 (Flutter fournit 36).
    implementation(platform("org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.11.0"))
    constraints {
        implementation("androidx.core:core:1.18.0")
        implementation("androidx.core:core-ktx:1.18.0")
        implementation("androidx.lifecycle:lifecycle-runtime:2.11.0")
        implementation("androidx.activity:activity:1.13.0")
        implementation("androidx.fragment:fragment:1.9.1")
        implementation("androidx.window:window:1.5.1")
        implementation("androidx.window:window-java:1.5.1")
        implementation("androidx.annotation:annotation:1.11.0")
        implementation("androidx.profileinstaller:profileinstaller:1.4.1")
        implementation("androidx.startup:startup-runtime:1.2.0")
        implementation("androidx.exifinterface:exifinterface:1.4.2")
        implementation("androidx.savedstate:savedstate:1.5.0")
        implementation("androidx.tracing:tracing:2.0.3")
        // Anciens modules vides, alignés sur la bibliothèque standard.
        implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.4.0")
        implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.4.0")
    }

    // Tests unitaires JVM du pare-feu DNS (./gradlew testDebugUnitTest).
    testImplementation("junit:junit:4.13.2")
    // Vrai org.json pour les tests JVM (celui d'Android n'y existe pas).
    testImplementation("org.json:json:20250517")
}
