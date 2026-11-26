package com.example.eleveur_app

import android.app.ActivityManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class ServiceSurveillance : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var pollingJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        Alertes.creerCanaux(this)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(
            this,
            SERVICE_NOTIFICATION_ID,
            Alertes.surveillanceNotification(this),
            type,
        )
        Log.d(NotificationSync.TAG, "ServiceSurveillance created and foreground")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!SessionNatif.notificationsEnabled(this) || SessionNatif.read(this) == null) {
            Log.w(NotificationSync.TAG, "ServiceSurveillance stopped: disabled or session missing")
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (pollingJob?.isActive != true) {
            pollingJob = serviceScope.launch { pollingLoop() }
        }
        return START_STICKY
    }

    private suspend fun pollingLoop() {
        var consecutiveFailures = 0
        while (serviceScope.isActive) {
            if (!SessionNatif.notificationsEnabled(this) || SessionNatif.read(this) == null) {
                Log.d(NotificationSync.TAG, "ServiceSurveillance stopping: session unavailable")
                stopSelf()
                return
            }
            val waitSeconds = if (!NotificationSync.networkConnected(this)) {
                Log.d(NotificationSync.TAG, "ServiceSurveillance skipped poll: no network")
                20L
            } else {
                when (NotificationSync.synchronize(this)) {
                    SyncOutcome.SUCCESS -> {
                        consecutiveFailures = 0
                        20L
                    }
                    SyncOutcome.RETRY -> {
                        consecutiveFailures++
                        when (consecutiveFailures) {
                            1 -> 60L
                            else -> 300L
                        }
                    }
                    SyncOutcome.SESSION_EXPIRED -> {
                        Log.w(NotificationSync.TAG, "ServiceSurveillance stopped after HTTP 401")
                        stopSelf()
                        return
                    }
                }
            }
            Log.d(NotificationSync.TAG, "ServiceSurveillance next poll in ${waitSeconds}s")
            try {
                delay(waitSeconds * 1_000)
            } catch (cancelled: CancellationException) {
                throw cancelled
            }
        }
    }

    override fun onDestroy() {
        Log.d(NotificationSync.TAG, "ServiceSurveillance destroyed")
        pollingJob?.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val SERVICE_NOTIFICATION_ID = 9101

        fun start(context: Context) {
            if (!SessionNatif.notificationsEnabled(context) || SessionNatif.read(context) == null) {
                Log.w(NotificationSync.TAG, "ServiceSurveillance start skipped: disabled or no session")
                return
            }
            Log.d(NotificationSync.TAG, "ServiceSurveillance start requested")
            androidx.core.content.ContextCompat.startForegroundService(
                context,
                Intent(context, ServiceSurveillance::class.java),
            )
        }

        fun stop(context: Context) {
            Log.d(NotificationSync.TAG, "ServiceSurveillance stop requested")
            context.stopService(Intent(context, ServiceSurveillance::class.java))
        }

        fun isActive(context: Context): Boolean {
            val manager = context.getSystemService(ActivityManager::class.java)
            val running = manager.getRunningServices(Int.MAX_VALUE)
                .any { it.service.className == ServiceSurveillance::class.java.name }
            Log.d(NotificationSync.TAG, "ServiceSurveillance estActif=$running")
            return running
        }
    }
}
