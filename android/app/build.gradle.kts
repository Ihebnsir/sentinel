import com.android.build.api.artifact.SingleArtifact
import java.util.Properties
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element

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
        // Une seule variante depuis la 1.1.0 (GitHub et, plus tard, Google Play).
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

// Play Protect (« protection renforcée contre la fraude ») bloque les APK
// installés hors Play Store qui déclarent ces accès. Le manifeste FUSIONNÉ
// (bibliothèques comprises) ne doit en contenir aucun : sinon assemble*,
// bundle* et les tests unitaires (testDebugUnitTest) échouent.
abstract class CheckPlayProtectManifest : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val mergedManifest: RegularFileProperty

    @get:OutputFile
    abstract val report: RegularFileProperty

    @TaskAction
    fun check() {
        val ns = "http://schemas.android.com/apk/res/android"
        val forbidden = setOf(
            "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
            "android.service.notification.NotificationListenerService",
            "android.permission.BIND_ACCESSIBILITY_SERVICE",
            "android.accessibilityservice.AccessibilityService",
            "android.permission.RECEIVE_SMS",
            "android.permission.READ_SMS",
            "android.permission.SEND_SMS",
            "android.permission.WRITE_SMS",
            "android.permission.RECEIVE_MMS",
            "android.permission.RECEIVE_WAP_PUSH",
            "android.permission.READ_CELL_BROADCASTS",
        )
        val doc = DocumentBuilderFactory.newInstance()
            .apply { isNamespaceAware = true }
            .newDocumentBuilder()
            .parse(mergedManifest.get().asFile)
        val all = doc.getElementsByTagName("*")
        val found = (0 until all.length)
            .map { all.item(it) as Element }
            .flatMap { e ->
                listOf("name", "permission").map { e.getAttributeNS(ns, it) }
                    .filter { it in forbidden }
                    .map { "<${e.tagName}> $it" }
            }
            .distinct()
        if (found.isNotEmpty()) {
            throw GradleException(
                "Accès bloqués par Play Protect dans le manifeste fusionné :\n" +
                    found.joinToString("\n") { "  - $it" },
            )
        }
        report.get().asFile.writeText("OK : aucun accès à risque pour Play Protect.\n")
    }
}

androidComponents {
    onVariants { variant ->
        val suffix = variant.name.replaceFirstChar { it.uppercase() }
        val checkTask = tasks.register<CheckPlayProtectManifest>("checkPlayProtect${suffix}") {
            group = "verification"
            description = "Vérifie que le manifeste fusionné de ${variant.name} passe Play Protect."
            mergedManifest.set(variant.artifacts.get(SingleArtifact.MERGED_MANIFEST))
            report.set(layout.buildDirectory.file("reports/playProtect/${variant.name}.txt"))
        }
        tasks.matching { it.name == "assemble$suffix" || it.name == "bundle$suffix" }
            .configureEach { dependsOn(checkTask) }
        // Les tests unitaires lisent son rapport (ManifestTest) : Flutter
        // déplace le dossier build, le chemin leur est donc transmis.
        tasks.withType<Test>().matching { it.name == "test${suffix}UnitTest" }.configureEach {
            dependsOn(checkTask)
            systemProperty(
                "sentinel.playProtectReport",
                layout.buildDirectory.file("reports/playProtect/${variant.name}.txt").get().asFile.path,
            )
        }
        tasks.matching { it.name == "check" }.configureEach { dependsOn(checkTask) }
    }
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

    // FileProvider (photo d'un document du coffre) ; version fixée plus haut.
    implementation("androidx.core:core:1.18.0")

    // Lecture des QR codes (Liens > Scanner un QR code). Apache 2.0.
    // Décodage ZXing sur le téléphone : ni réseau, ni modèle téléchargé.
    // ZXing core 3.5.3 (dernière version) au lieu du 3.4.1 tiré par défaut.
    implementation("com.journeyapps:zxing-android-embedded:4.3.0")
    implementation("com.google.zxing:core:3.5.3")

    // Tests unitaires JVM du pare-feu DNS (./gradlew testDebugUnitTest).
    testImplementation("junit:junit:4.13.2")
    // Vrai org.json pour les tests JVM (celui d'Android n'y existe pas).
    testImplementation("org.json:json:20250517")
}
