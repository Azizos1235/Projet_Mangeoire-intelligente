package com.example.eleveur_app

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.NdefRecord
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class NfcLecteur(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val adapter = NfcAdapter.getDefaultAdapter(activity)
    private val handler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var pendingResult: MethodChannel.Result? = null
    private var timeoutRunnable: Runnable? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "disponible" -> result.success(adapter?.isEnabled == true)
            "lire" -> startRead(call, result)
            "annuler" -> {
                completeSuccess(null)
                result.success(null)
            }
            "parametres" -> openSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun startRead(call: MethodCall, result: MethodChannel.Result) {
        val nfcAdapter = adapter
        if (nfcAdapter == null) {
            result.error("NFC_ABSENT", "Cet appareil ne possède pas de NFC.", null)
            return
        }
        if (!nfcAdapter.isEnabled) {
            result.error("NFC_DESACTIVE", "Le NFC est désactivé.", null)
            return
        }

        val arguments = call.arguments as? Map<*, *>
        val delayValue = arguments?.get("delai")
        if (delayValue != null && delayValue !is Int) {
            result.error("ARGUMENT_INVALIDE", "Le délai doit être un entier.", null)
            return
        }
        val delaySeconds = delayValue as? Int ?: 30
        if (delaySeconds <= 0) {
            result.error("ARGUMENT_INVALIDE", "Le délai doit être positif.", null)
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
            result.error("DEJA_EN_COURS", "Une lecture NFC est déjà en cours.", null)
            return
        }

        val timeout = Runnable {
            completeError("DELAI_DEPASSE", "Le délai de lecture NFC est dépassé.")
        }
        synchronized(lock) {
            if (pendingResult === result) {
                timeoutRunnable = timeout
                handler.postDelayed(timeout, delaySeconds * 1000L)
            }
        }

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V

        try {
            nfcAdapter.enableReaderMode(
                activity,
                { tag ->
                    val tagData = try {
                        tagData(tag)
                    } catch (error: Exception) {
                        activity.runOnUiThread {
                            completeError(
                                "NFC_ERREUR",
                                error.message ?: "Impossible de lire la puce NFC.",
                            )
                        }
                        return@enableReaderMode
                    }
                    activity.runOnUiThread { completeSuccess(tagData) }
                },
                flags,
                null,
            )
        } catch (error: Exception) {
            completeError("NFC_ERREUR", error.message ?: "Impossible de démarrer le NFC.")
        }
    }

    private fun tagData(tag: Tag): Map<String, Any?> {
        val uid = tag.id.joinToString(":") { byte ->
            (byte.toInt() and 0xFF).toString(16).padStart(2, '0').uppercase()
        }
        val techs = tag.techList.map { it.substringAfterLast('.') }
        return mapOf(
            "uid" to uid,
            "techs" to techs,
            "texte" to firstTextRecord(tag),
        )
    }

    private fun firstTextRecord(tag: Tag): String? {
        val records = Ndef.get(tag)?.cachedNdefMessage?.records ?: return null
        val record = records.firstOrNull {
            it.tnf == NdefRecord.TNF_WELL_KNOWN &&
                it.type.contentEquals(NdefRecord.RTD_TEXT)
        } ?: return null
        val payload = record.payload
        if (payload.isEmpty()) return null

        val status = payload[0].toInt() and 0xFF
        val languageLength = status and 0x3F
        val textOffset = 1 + languageLength
        if (textOffset > payload.size) return null
        val charset = if (status and 0x80 == 0) Charsets.UTF_8 else Charset.forName("UTF-16")
        return String(payload, textOffset, payload.size - textOffset, charset)
    }

    private fun openSettings(result: MethodChannel.Result) {
        try {
            activity.startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "NFC_PARAMETRES_ECHEC",
                error.message ?: "Impossible d'ouvrir les paramètres NFC.",
                null,
            )
        }
    }

    private fun completeSuccess(value: Any?) {
        complete { it.success(value) }
    }

    private fun completeError(code: String, message: String) {
        complete { it.error(code, message, null) }
    }

    private fun complete(reply: (MethodChannel.Result) -> Unit) {
        val result = synchronized(lock) {
            val current = pendingResult
            pendingResult = null
            timeoutRunnable?.let(handler::removeCallbacks)
            timeoutRunnable = null
            current
        }
        disableReaderMode()
        if (result != null) {
            activity.runOnUiThread { reply(result) }
        }
    }

    private fun disableReaderMode() {
        try {
            adapter?.disableReaderMode(activity)
        } catch (_: IllegalStateException) {
            // The Activity can already be detached while its NFC reader is released.
        }
    }

    fun liberer() {
        completeSuccess(null)
    }
}
