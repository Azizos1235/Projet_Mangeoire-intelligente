package com.example.eleveur_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var nfcLecteur: NfcLecteur

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        nfcLecteur = NfcLecteur(this)
        MethodChannel(messenger, "qr/scanner").setMethodCallHandler(QrScanner(this))
        MethodChannel(messenger, "nfc/tag").setMethodCallHandler(nfcLecteur)
    }

    override fun onPause() {
        if (::nfcLecteur.isInitialized) nfcLecteur.liberer()
        super.onPause()
    }

    override fun onDestroy() {
        if (::nfcLecteur.isInitialized) nfcLecteur.liberer()
        super.onDestroy()
    }
}
