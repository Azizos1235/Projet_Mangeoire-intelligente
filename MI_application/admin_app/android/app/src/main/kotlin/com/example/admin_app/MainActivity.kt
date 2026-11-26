package com.example.admin_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var nfcLecteur: NfcLecteur
    private lateinit var notificationChannel: MethodChannel
    private var permissionResult: MethodChannel.Result? = null
    private var pendingAction: Map<String, Any?>? = null
    private var actionListenerReady = false

    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.d(TAG, "onCreate intent=${intentDescription(intent)}")
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine intent=${intentDescription(intent)}")
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        nfcLecteur = NfcLecteur(this)
        MethodChannel(messenger, "nfc/tag").setMethodCallHandler(nfcLecteur)
        Alertes.creerCanaux(this)
        notificationChannel = MethodChannel(messenger, "alerte/notifier")
        notificationChannel.setMethodCallHandler(::handleNotificationCall)
        MethodChannel(messenger, "sync/planifier").setMethodCallHandler { call, result ->
            when (call.method) {
                "planifier" -> {
                    VerificationWorker.planifier(this)
                    ServiceSurveillance.start(this)
                    result.success(null)
                }
                "maintenant" -> {
                    VerificationWorker.maintenant(this)
                    result.success(null)
                }
                "annuler" -> {
                    VerificationWorker.annuler(this)
                    result.success(null)
                }
                "serviceActif" -> result.success(ServiceSurveillance.isActive(this))
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "session/natif").setMethodCallHandler { call, result ->
            when (call.method) {
                "setSession" -> saveSession(call, result)
                "clearSession" -> {
                    SessionNatif.clear(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleNotificationCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "demanderPermission" -> demanderPermission(result)
            "autorisee" -> result.success(Alertes.autorisee(this))
            "notifier" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("invalid_arguments", "Notification data is required.", null)
                    return
                }
                val target = (args["target"] as? Map<*, *>)?.entries
                    ?.mapNotNull { (key, value) ->
                        (key as? String)?.let { it to (value as? String) }
                    }?.toMap().orEmpty()
                val shown = Alertes.afficher(
                    this,
                    args["id"]?.toString().orEmpty(),
                    args["type"]?.toString().orEmpty(),
                    args["titre"]?.toString().orEmpty(),
                    args["texte"]?.toString().orEmpty(),
                    target,
                )
                result.success(shown)
            }
            "actionInitiale" -> {
                val action = pendingAction ?: lireAction(intent)
                pendingAction = null
                Log.d(TAG, "actionInitiale returned=${action?.let(::intentActionDescription)}")
                result.success(action)
            }
            "ecouterActions" -> {
                actionListenerReady = true
                pendingAction?.let {
                    Log.d(TAG, "Invoking surAction action=${intentActionDescription(it)}")
                    notificationChannel.invokeMethod("surAction", it)
                    pendingAction = null
                }
                result.success(null)
            }
            "marquerCommeNotifie" -> {
                val ids = (call.arguments as? List<*>)?.mapNotNull { it as? String }.orEmpty()
                SessionNatif.markAlreadyNotified(this, ids.toSet())
                result.success(null)
            }
            "notificationsActivees" -> result.success(SessionNatif.notificationsEnabled(this))
            "consommerSessionExpiree" ->
                result.success(SessionNatif.consumeSessionExpired(this))
            "guiderOptimisationBatterie" ->
                result.success(SessionNatif.shouldShowBatteryGuidance(this))
            "ignoreOptimisationBatterie" -> {
                val powerManager = getSystemService(PowerManager::class.java)
                result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
            }
            "demanderIgnoreOptimisationBatterie" -> {
                val request = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    android.net.Uri.parse("package:$packageName"),
                )
                if (request.resolveActivity(packageManager) != null) {
                    startActivity(request)
                } else {
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(android.net.Uri.parse("package:$packageName")),
                    )
                }
                result.success(null)
            }
            "definirNotifications" -> {
                val enabled = call.argument<Boolean>("enabled")
                    ?: run {
                        result.error("invalid_arguments", "enabled is required.", null)
                        return
                    }
                SessionNatif.setNotificationsEnabled(this, enabled)
                    if (enabled) {
                        VerificationWorker.planifier(this)
                        ServiceSurveillance.start(this)
                    } else {
                        VerificationWorker.annuler(this)
                    }
                result.success(null)
            }
            "permissionDejaExpliquee" -> result.success(SessionNatif.permissionPrompted(this))
            "marquerPermissionExpliquee" -> {
                SessionNatif.setPermissionPrompted(this)
                result.success(null)
            }
            "ouvrirParametres" -> {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun saveSession(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")
        val baseUrl = call.argument<String>("baseUrl")
        val role = call.argument<String>("role")
        val userId = call.argument<String>("userId")
        val language = call.argument<String>("language") ?: "fr"
        if (token.isNullOrBlank() || baseUrl.isNullOrBlank() ||
            role != "admin" || userId.isNullOrBlank()
        ) {
            result.error("invalid_session", "A valid Admin session is required.", null)
            return
        }
        SessionNatif.save(this, token, baseUrl, role, userId, language)
        result.success(null)
    }

    private fun demanderPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(Alertes.autorisee(this))
            return
        }
        if (permissionResult != null) {
            result.error("permission_in_progress", "Notification permission is already requested.", null)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            permissionResult?.success(Alertes.autorisee(this))
            permissionResult = null
        }
    }

    private fun lireAction(sourceIntent: Intent?): Map<String, Any?>? {
        if (sourceIntent?.getStringExtra("action") != "voir") return null
        val action = mutableMapOf<String, Any?>(
            "action" to "voir",
            "titre" to sourceIntent.getStringExtra("titre"),
            "id" to sourceIntent.getStringExtra("id"),
            "type" to sourceIntent.getStringExtra("type"),
        )
        listOf("task_id", "alert_id", "cow_id", "scope").forEach { key ->
            sourceIntent.getStringExtra(key)?.let { action[key] = it }
        }
        sourceIntent.getIntExtra(Alertes.EXTRA_NOTIFICATION_ID, -1)
            .takeIf { it > 0 }?.let { Alertes.fermer(this, it) }
        sourceIntent.removeExtra("action")
        sourceIntent.removeExtra("titre")
        sourceIntent.removeExtra("id")
        sourceIntent.removeExtra("type")
        listOf("task_id", "alert_id", "cow_id", "scope", Alertes.EXTRA_NOTIFICATION_ID)
            .forEach(sourceIntent::removeExtra)
        setIntent(sourceIntent)
        return action
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "onNewIntent extras=${intentDescription(intent)}")
        lireAction(intent)?.let { action ->
            if (actionListenerReady) {
                Log.d(TAG, "Invoking surAction action=${intentActionDescription(action)}")
                notificationChannel.invokeMethod("surAction", action)
            } else {
                pendingAction = action
            }
        }
    }

    override fun onPause() {
        if (::nfcLecteur.isInitialized) nfcLecteur.liberer()
        super.onPause()
    }

    override fun onDestroy() {
        if (::nfcLecteur.isInitialized) nfcLecteur.liberer()
        super.onDestroy()
    }

    private fun intentDescription(source: Intent?): String {
        if (source == null) return "none"
        val keys = listOf("action", "id", "type", "task_id", "alert_id", "cow_id")
        return keys.mapNotNull { key ->
            source.getStringExtra(key)?.let { "$key=$it" }
        }.joinToString(prefix = "{", postfix = "}")
    }

    private fun intentActionDescription(action: Map<String, Any?>): String =
        "type=${action["type"]} id=${action["id"]} alert_id=${action["alert_id"]}"

    companion object {
        private const val TAG = "MI_NOTIF"
        private const val NOTIFICATION_PERMISSION_REQUEST = 761
    }
}
