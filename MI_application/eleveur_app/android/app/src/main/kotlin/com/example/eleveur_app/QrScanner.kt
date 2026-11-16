package com.example.eleveur_app

import android.app.Activity
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class QrScanner(activity: Activity) : MethodChannel.MethodCallHandler {
    private val lock = Any()
    private var pendingResult: MethodChannel.Result? = null
    private val scanner = GmsBarcodeScanning.getClient(
        activity,
        GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build(),
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "scanner") {
            result.notImplemented()
            return
        }

        val accepted = synchronized(lock) {
            if (pendingResult != null) {
                false
            } else {
                pendingResult = result
                true
            }
        }
        if (!accepted) {
            result.error("DEJA_EN_COURS", "Un scan QR est déjà en cours.", null)
            return
        }

        try {
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    val text = barcode.rawValue
                    if (text == null) {
                        fail("SCAN_ECHEC", "Le code QR ne contient aucun texte.")
                    } else {
                        complete { it.success(text) }
                    }
                }
                .addOnCanceledListener {
                    complete { it.success(null) }
                }
                .addOnFailureListener { error ->
                    fail("SCAN_ECHEC", error.message ?: "Échec de la lecture QR.")
                }
        } catch (error: Exception) {
            fail("SCAN_ECHEC", error.message ?: "Impossible de démarrer le scanner QR.")
        }
    }

    private fun fail(code: String, message: String) {
        complete { it.error(code, message, null) }
    }

    private fun complete(reply: (MethodChannel.Result) -> Unit) {
        val result = synchronized(lock) {
            pendingResult.also { pendingResult = null }
        } ?: return
        reply(result)
    }
}
