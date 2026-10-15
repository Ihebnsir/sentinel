package com.iheb.sentinel

import android.content.Context
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Réponse de l'IA Dart (voir lib/background/background_analyzer.dart). */
data class AnalysisResult(
    val verdict: String, // "arnaque", "suspect" ou "rien"
    val percent: Int,
    val mainReason: String,
    val alertTitle: String,
)

/**
 * Fait tourner la MÊME IA que l'app, en Dart, sans écran :
 * un moteur Flutter « headless » démarré au premier message à analyser,
 * puis gardé en cache pour les suivants.
 *
 * Toutes les fonctions s'appellent sur le thread principal.
 */
object BackgroundAnalyzer {
    private const val TAG = "SentinelAnalyzer"
    private const val ENGINE_ID = "sentinel_background_analyzer"

    // Mêmes noms que dans lib/background/background_analyzer.dart.
    private const val CHANNEL = "com.iheb.sentinel/background_analysis"
    private const val ENTRY_LIBRARY = "package:sentinel/background/background_analyzer.dart"
    private const val ENTRY_FUNCTION = "backgroundAnalyzerMain"

    // Messages en attente pendant le démarrage du moteur (borné).
    private const val MAX_PENDING = 10

    private class Request(
        val arguments: Map<String, Any>,
        val onResult: (AnalysisResult?) -> Unit,
    )

    private var channel: MethodChannel? = null
    private var dartReady = false
    private val pending = ArrayDeque<Request>()

    /** Analyse un message ; onResult reçoit null en cas d'échec. */
    fun analyze(
        context: Context,
        arguments: Map<String, Any>,
        onResult: (AnalysisResult?) -> Unit,
    ) {
        val request = Request(arguments, onResult)
        if (dartReady) {
            send(request)
            return
        }
        // Moteur pas encore prêt : on garde le message en mémoire (RAM seulement).
        if (pending.size >= MAX_PENDING) pending.removeFirst().onResult(null)
        pending.addLast(request)
        startEngineIfNeeded(context.applicationContext)
    }

    /** Arrête le moteur et oublie les messages en attente. */
    fun shutdown() {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.destroy()
        cache.remove(ENGINE_ID)
        channel = null
        dartReady = false
        while (pending.isNotEmpty()) pending.removeFirst().onResult(null)
    }

    private fun startEngineIfNeeded(context: Context) {
        if (channel != null) return // déjà en train de démarrer
        val engine = try {
            FlutterEngine(context)
        } catch (e: Exception) {
            Log.w(TAG, "Moteur Flutter impossible à démarrer", e)
            while (pending.isNotEmpty()) pending.removeFirst().onResult(null)
            return
        }
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        // Dart nous appelle avec « ready » quand il écoute le canal.
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    dartReady = true
                    result.success(null)
                    while (pending.isNotEmpty()) send(pending.removeFirst())
                } else {
                    result.notImplemented()
                }
            }
        }

        val bundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(bundlePath, ENTRY_LIBRARY, ENTRY_FUNCTION),
        )
    }

    private fun send(request: Request) {
        val current = channel ?: return request.onResult(null)
        current.invokeMethod("analyze", request.arguments, object : MethodChannel.Result {
            override fun success(result: Any?) {
                request.onResult(parse(result))
            }

            // Seul le code d'erreur est écrit : jamais le message analysé.
            override fun error(code: String, message: String?, details: Any?) {
                Log.w(TAG, "Analyse impossible ($code)")
                request.onResult(null)
            }

            override fun notImplemented() {
                request.onResult(null)
            }
        })
    }

    private fun parse(result: Any?): AnalysisResult? {
        val map = result as? Map<*, *> ?: return null
        return AnalysisResult(
            verdict = map["verdict"] as? String ?: return null,
            percent = (map["percent"] as? Number)?.toInt() ?: 0,
            mainReason = map["mainReason"] as? String ?: "",
            alertTitle = map["alertTitle"] as? String ?: "Arnaque probable",
        )
    }
}
