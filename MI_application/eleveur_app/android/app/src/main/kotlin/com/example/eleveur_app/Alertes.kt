package com.example.eleveur_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object Alertes {
    const val CHANNEL_TASKS = "taches_v2"
    const val CHANNEL_SURVEILLANCE = "surveillance"
    const val EXTRA_NOTIFICATION_ID = "notification_id"
    private const val TAG = "MI_NOTIF"
    private const val ID_PREFERENCES = "notification_request_codes"
    private val idLock = Any()

    fun creerCanaux(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel("taches")
        val tasksChannel = NotificationChannel(
            CHANNEL_TASKS,
            "Tâches",
            NotificationManager.IMPORTANCE_HIGH,
        )
        val serviceChannel = NotificationChannel(
            CHANNEL_SURVEILLANCE,
            "Surveillance des tâches",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(tasksChannel)
        manager.createNotificationChannel(serviceChannel)
    }

    fun autorisee(context: Context, channelId: String? = null): Boolean {
        val permissionGranted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        val manager = context.getSystemService(NotificationManager::class.java)
        val channels = if (channelId != null) {
            listOf(channelId)
        } else {
            listOf(CHANNEL_TASKS)
        }
        val importance = channels.map { id ->
            manager.getNotificationChannel(id)?.importance
                ?: NotificationManager.IMPORTANCE_NONE
        }
        val appEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        val allowed = permissionGranted && appEnabled &&
            importance.any { it != NotificationManager.IMPORTANCE_NONE }
        Log.d(
            TAG,
            "autorisee permission=$permissionGranted appEnabled=$appEnabled " +
                "channels=${channels.zip(importance)} allowed=$allowed",
        )
        return allowed
    }

    fun notificationId(context: Context, type: String, id: String): Int =
        synchronized(idLock) {
            val preferences = context.getSharedPreferences(ID_PREFERENCES, Context.MODE_PRIVATE)
            val key = "$type:$id"
            val existing = preferences.getInt(key, 0)
            if (existing > 0) return@synchronized existing
            val used = preferences.all.values.filterIsInstance<Int>().toHashSet()
            var candidate = key.hashCode().and(Int.MAX_VALUE).coerceAtLeast(1)
            while (candidate in used) {
                candidate = if (candidate == Int.MAX_VALUE) 1 else candidate + 1
            }
            preferences.edit().putInt(key, candidate).apply()
            candidate
        }

    fun afficher(
        context: Context,
        id: String,
        type: String,
        title: String,
        text: String,
        target: Map<String, String?> = emptyMap(),
        color: Int? = null,
        summary: Boolean = false,
    ): Boolean {
        creerCanaux(context)
        if (!autorisee(context, CHANNEL_TASKS)) {
            Log.w(TAG, "Notification skipped id=$id: permission or channel disabled")
            return false
        }
        val notificationId = notificationId(context, type, id)
        val openSpec = buildNotificationIntentSpec(
            context.packageName,
            "view",
            notificationId,
        )
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = openSpec.action
            putExtra("action", "voir")
            putExtra("titre", title)
            putExtra("id", id)
            putExtra("type", type)
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            target.forEach { (key, value) ->
                if (value != null) putExtra(key, value)
            }
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val openPendingIntent = PendingIntent.getActivity(
            context,
            openSpec.requestCode,
            openIntent,
            pendingFlags,
        )
        val ignoreSpec = buildNotificationIntentSpec(
            context.packageName,
            "ignore",
            notificationId,
        )
        val ignoreIntent = Intent(context, AlerteReceiver::class.java).apply {
            action = ignoreSpec.action
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
        }
        val ignorePendingIntent = PendingIntent.getBroadcast(
            context,
            ignoreSpec.requestCode,
            ignoreIntent,
            pendingFlags,
        )
        val builder = NotificationCompat.Builder(context, CHANNEL_TASKS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_view, "Voir", openPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Ignorer",
                ignorePendingIntent,
            )
        if (color != null) builder.setColor(color)
        if (summary) builder.setNumber(text.substringBefore(' ').toIntOrNull() ?: 0)
        return try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(
                TAG,
                "Notification shown type=$type id=$id notificationId=$notificationId " +
                    "channel=$CHANNEL_TASKS",
            )
            true
        } catch (_: SecurityException) {
            Log.w(TAG, "Notification skipped id=$id: notify() rejected by permission")
            false
        }
    }

    fun surveillanceNotification(context: Context): android.app.Notification {
        creerCanaux(context)
        return NotificationCompat.Builder(context, CHANNEL_SURVEILLANCE)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Surveillance active")
            .setContentText("Vérification des nouvelles tâches")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    fun fermer(context: Context, notificationId: Int) {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }
}

internal data class NotificationIntentSpec(
    val action: String,
    val requestCode: Int,
    val dataUri: String?,
)

internal fun buildNotificationIntentSpec(
    packageName: String,
    action: String,
    notificationId: Int,
): NotificationIntentSpec = NotificationIntentSpec(
    action = "$packageName.notification.$action.$notificationId",
    requestCode = notificationId,
    dataUri = null,
)

class AlerteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(Alertes.EXTRA_NOTIFICATION_ID, -1)
        if (notificationId > 0) Alertes.fermer(context, notificationId)
    }
}
