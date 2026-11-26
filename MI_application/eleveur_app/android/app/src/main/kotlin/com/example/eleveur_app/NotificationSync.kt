package com.example.eleveur_app

import android.app.ActivityManager
import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeParseException

internal data class NotificationCandidate(
    val id: String,
    val type: String,
    val createdAtMillis: Long?,
)

internal data class NotificationSelection(
    val itemsToNotify: List<NotificationCandidate>,
    val currentIds: Set<String>,
    val silentIds: Set<String>,
)

internal object NotificationPolicy {
    fun select(
        role: String,
        currentItems: List<NotificationCandidate>,
        alreadyNotified: Set<String>,
        firstRun: Boolean,
        loginAtMillis: Long,
    ): NotificationSelection {
        val supported = currentItems.filter { role == "eleveur" }
        val currentIds = supported.mapTo(mutableSetOf()) { it.id }
        val newItems = supported.filter { candidate ->
            candidate.createdAtMillis?.let { it >= loginAtMillis } == true &&
                candidate.id !in alreadyNotified
        }
        val newIds = newItems.mapTo(mutableSetOf()) { it.id }
        val silentIds = if (firstRun) {
            supported.filter { it.id !in newIds }.mapTo(mutableSetOf()) { it.id }
        } else {
            emptySet()
        }
        return NotificationSelection(newItems, currentIds, silentIds)
    }
}

internal data class NativeSession(
    val token: String,
    val baseUrl: String,
    val role: String,
    val userId: String,
    val language: String,
)

internal enum class SyncOutcome {
    SUCCESS,
    RETRY,
    SESSION_EXPIRED,
}

internal object NotificationSyncPolicy {
    fun idsToPersist(
        currentIds: Set<String>,
        alreadyNotified: Set<String>,
        shownIds: Set<String>,
        silentIds: Set<String> = emptySet(),
    ): Set<String> = (alreadyNotified.intersect(currentIds) + shownIds + silentIds)
        .intersect(currentIds)

    fun onUnauthorized(clearSession: () -> Unit): SyncOutcome {
        clearSession()
        return SyncOutcome.SESSION_EXPIRED
    }
}

internal object SessionNatif {
    private const val PREFS_NAME = "native_notification_session"
    private const val TOKEN = "token"
    private const val BASE_URL = "base_url"
    private const val ROLE = "role"
    private const val USER_ID = "user_id"
    private const val LANGUAGE = "language"
    private const val IDENTITY = "identity"
    private const val IDS = "already_notified_ids"
    private const val INITIALIZED = "poll_initialized"
    private const val LOGIN_AT = "login_at"
    private const val ENABLED = "notifications_enabled"
    private const val PERMISSION_PROMPTED = "permission_prompted"
    private const val BATTERY_GUIDANCE_SHOWN = "battery_guidance_shown"
    private const val SESSION_EXPIRED = "notification_session_expired"
    const val WORK_NAME = "native_notification_poll"
    const val WORK_TAG = "native_notification_work"

    private fun preferences(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(
        context: Context,
        token: String,
        baseUrl: String,
        role: String,
        userId: String,
        language: String,
    ) {
        val prefs = preferences(context)
        val identity = "$role:$userId:${baseUrl.trimEnd('/')}"
        val editor = prefs.edit()
        if (prefs.getString(IDENTITY, null) != identity ||
            !prefs.contains(LOGIN_AT)
        ) {
            editor.remove(IDS)
                .putBoolean(INITIALIZED, false)
                .putLong(LOGIN_AT, System.currentTimeMillis())
        }
        editor.putString(TOKEN, token)
            .putString(BASE_URL, baseUrl.trimEnd('/'))
            .putString(ROLE, role)
            .putString(USER_ID, userId)
            .putString(LANGUAGE, language)
            .putString(IDENTITY, identity)
            .putBoolean(SESSION_EXPIRED, false)
            .apply()
        Log.d(NotificationSync.TAG, "Native session saved role=$role userId=$userId")
    }

    fun read(context: Context): NativeSession? {
        val prefs = preferences(context)
        val token = prefs.getString(TOKEN, null)?.takeIf(String::isNotBlank) ?: return null
        val baseUrl = prefs.getString(BASE_URL, null)?.takeIf(String::isNotBlank) ?: return null
        val role = prefs.getString(ROLE, null)?.takeIf { it == "admin" || it == "eleveur" }
            ?: return null
        val userId = prefs.getString(USER_ID, null)?.takeIf(String::isNotBlank) ?: return null
        return NativeSession(
            token,
            baseUrl,
            role,
            userId,
            prefs.getString(LANGUAGE, "fr") ?: "fr",
        )
    }

    fun loginAtMillis(context: Context): Long =
        preferences(context).getLong(LOGIN_AT, 0L)

    fun alreadyNotified(context: Context): Set<String> =
        preferences(context).getStringSet(IDS, emptySet())?.toSet() ?: emptySet()

    fun replaceAlreadyNotified(context: Context, ids: Set<String>) {
        preferences(context).edit().putStringSet(IDS, HashSet(ids)).apply()
    }

    fun markAlreadyNotified(context: Context, ids: Set<String>) {
        val processInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(processInfo)
        if (processInfo.importance > ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
            Log.d(NotificationSync.TAG, "Ignoring foreground-seen ids while app is background ids=$ids")
            return
        }
        val combined = alreadyNotified(context).toMutableSet()
        combined.addAll(ids)
        replaceAlreadyNotified(context, combined)
        Log.d(NotificationSync.TAG, "Foreground UI marked visible ids=$ids")
    }

    fun isInitialized(context: Context): Boolean =
        preferences(context).getBoolean(INITIALIZED, false)

    fun setInitialized(context: Context) {
        preferences(context).edit().putBoolean(INITIALIZED, true).apply()
    }

    fun notificationsEnabled(context: Context): Boolean =
        preferences(context).getBoolean(ENABLED, true)

    fun setNotificationsEnabled(context: Context, enabled: Boolean) {
        preferences(context).edit().putBoolean(ENABLED, enabled).apply()
    }

    fun permissionPrompted(context: Context): Boolean =
        preferences(context).getBoolean(PERMISSION_PROMPTED, false)

    fun setPermissionPrompted(context: Context) {
        preferences(context).edit().putBoolean(PERMISSION_PROMPTED, true).apply()
    }

    fun shouldShowBatteryGuidance(context: Context): Boolean {
        val prefs = preferences(context)
        if (prefs.getBoolean(BATTERY_GUIDANCE_SHOWN, false)) return false
        prefs.edit().putBoolean(BATTERY_GUIDANCE_SHOWN, true).apply()
        return true
    }

    fun consumeSessionExpired(context: Context): Boolean {
        val prefs = preferences(context)
        val expired = prefs.getBoolean(SESSION_EXPIRED, false)
        if (expired) prefs.edit().putBoolean(SESSION_EXPIRED, false).apply()
        return expired
    }

    fun clear(context: Context, expired: Boolean = false) {
        val prefs = preferences(context)
        prefs.edit()
            .remove(TOKEN)
            .remove(BASE_URL)
            .remove(ROLE)
            .remove(USER_ID)
            .remove(LANGUAGE)
            .remove(IDENTITY)
            .remove(IDS)
            .remove(INITIALIZED)
            .remove(LOGIN_AT)
            .putBoolean(SESSION_EXPIRED, expired)
            .apply()
        VerificationWorker.annuler(context)
        Log.w(NotificationSync.TAG, "Native session cleared expired=$expired")
    }
}

internal object NotificationSync {
    const val TAG = "MI_NOTIF"
    private val mutex = Mutex()
    private val acceptedTypes = setOf(
        "check_weight",
        "sell",
        "vet",
        "butcher",
        "custom",
    )

    suspend fun synchronize(context: Context): SyncOutcome = mutex.withLock {
        withContext(Dispatchers.IO) {
            pollBlocking(context.applicationContext)
        }
    }

    fun networkConnected(context: Context): Boolean {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun pollBlocking(context: Context): SyncOutcome {
        val startedAt = System.currentTimeMillis()
        Log.d(TAG, "Worker/service sync startAt=$startedAt")
        val session = SessionNatif.read(context)
        if (session == null) {
            Log.w(TAG, "Sync skipped: native session missing; result=success")
            return SyncOutcome.SUCCESS
        }
        Log.d(TAG, "Sync session present role=${session.role} userId=${session.userId}")
        if (!SessionNatif.notificationsEnabled(context)) {
            Log.d(TAG, "Sync skipped: notifications disabled; result=success")
            return SyncOutcome.SUCCESS
        }
        if (!networkConnected(context)) {
            Log.d(TAG, "Sync skipped: no validated network; result=success")
            return SyncOutcome.SUCCESS
        }

        val path = if (session.role == "eleveur") {
            "/tasks/mine"
        } else {
            "/alerts?status=unread&limit=50"
        }
        val url = session.baseUrl + path
        Log.d(TAG, "HTTP GET url=$url role=${session.role}")
        return try {
            val (status, body) = get(url, session.token)
            Log.d(TAG, "HTTP status=$status responseBytes=${body.length}")
            when {
                status == HttpURLConnection.HTTP_UNAUTHORIZED -> {
                    Log.e(TAG, "HTTP 401: token expired; clearing native session")
                    NotificationSyncPolicy.onUnauthorized {
                        SessionNatif.clear(context, expired = true)
                    }
                }
                status in 500..599 -> {
                    Log.w(TAG, "HTTP $status; result=retry")
                    SyncOutcome.RETRY
                }
                status !in 200..299 -> {
                    Log.w(TAG, "HTTP $status; no notification state changed")
                    SyncOutcome.SUCCESS
                }
                else -> processResponse(context, session, body, startedAt)
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: IOException) {
            Log.e(TAG, "Network error; result=retry", error)
            SyncOutcome.RETRY
        } catch (error: JSONException) {
            Log.e(TAG, "Invalid notification response; result=retry", error)
            SyncOutcome.RETRY
        } catch (error: Exception) {
            Log.e(TAG, "Unexpected sync error; result=retry", error)
            SyncOutcome.RETRY
        }
    }

    private fun processResponse(
        context: Context,
        session: NativeSession,
        body: String,
        startedAt: Long,
    ): SyncOutcome {
        val records = parseRecords(session, body)
        Log.d(TAG, "Items received=${records.size} ids=${records.map { it.id }}")
        val already = SessionNatif.alreadyNotified(context)
        val firstRun = !SessionNatif.isInitialized(context)
        val selection = NotificationPolicy.select(
            session.role,
            records.map { NotificationCandidate(it.id, it.type, it.createdAtMillis) },
            already,
            firstRun,
            SessionNatif.loginAtMillis(context),
        )
        Log.d(
            TAG,
            "Already notified ids=$already; ids to notify=" +
                selection.itemsToNotify.map { it.id } +
                " silent first-run ids=${selection.silentIds}",
        )
        val shownIds = showNewItems(
            context,
            session,
            records,
            selection.itemsToNotify.mapTo(mutableSetOf()) { it.id },
        )
        val retainedIds = NotificationSyncPolicy.idsToPersist(
            selection.currentIds,
            already,
            shownIds,
            selection.silentIds,
        )
        SessionNatif.replaceAlreadyNotified(context, retainedIds)
        SessionNatif.setInitialized(context)
        Log.d(
            TAG,
            "Sync finished durationMs=${System.currentTimeMillis() - startedAt} " +
                "shownIds=$shownIds savedIds=$retainedIds result=success",
        )
        return SyncOutcome.SUCCESS
    }

    private fun get(url: String, token: String): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Accept", "application/json")
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            return status to response
        } finally {
            connection.disconnect()
        }
    }

    private fun parseRecords(session: NativeSession, body: String): List<NotificationRecord> {
        val array = JSONArray(body)
        Log.d(TAG, "API returned arrayCount=${array.length()}")
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val id = item.optString("id").takeIf(String::isNotBlank)
                ?: item.optString("_id").takeIf(String::isNotBlank)
                ?: return@mapNotNull null
            val type = if (session.role == "eleveur") {
                item.optString("task_type", "custom")
                    .takeIf { it in acceptedTypes } ?: "custom"
            } else {
                item.optString("type")
            }
            if (session.role == "admin") return@mapNotNull null
            val createdAt = parseTimestamp(item)
            val cowId = item.optString("cow_id").takeIf(String::isNotBlank)
            val title = item.optString("title", "Tâche")
            val text = if (session.language == "ar") {
                if (cowId == null) title else "$title — البقرة $cowId"
            } else {
                if (cowId == null) title else "$title – vache $cowId"
            }
            NotificationRecord(
                id = id,
                type = type,
                title = if (session.language == "ar") "مهمة جديدة" else "Nouvelle tâche",
                text = text,
                createdAtMillis = createdAt,
                target = mapOf("task_id" to id, "cow_id" to cowId),
            )
        }
    }

    private fun parseTimestamp(item: JSONObject): Long? {
        val raw = item.optString("created_at").takeIf(String::isNotBlank) ?: return null
        return try {
            Instant.parse(raw).toEpochMilli()
        } catch (_: DateTimeParseException) {
            try {
                OffsetDateTime.parse(raw).toInstant().toEpochMilli()
            } catch (_: DateTimeParseException) {
                Log.w(TAG, "Invalid created_at=$raw itemId=${item.optString("id")}")
                null
            }
        }
    }

    private fun showNewItems(
        context: Context,
        session: NativeSession,
        records: List<NotificationRecord>,
        newIds: Set<String>,
    ): Set<String> {
        val newRecords = records.filter { it.id in newIds }
        if (newRecords.isEmpty()) return emptySet()
        if (newRecords.size > 3) {
            val summaryId = newRecords.map { it.id }.sorted().joinToString(",")
            val count = newRecords.size
            val title = if (session.language == "ar") "مهام جديدة" else "Nouvelles tâches"
            val text = if (session.language == "ar") {
                "$count مهام جديدة"
            } else {
                "$count nouvelles tâches"
            }
            val shown = Alertes.afficher(
                context,
                "summary:$summaryId",
                "summary_tasks",
                title,
                text,
                target = mapOf("scope" to "tasks"),
                color = 0xFF2E7D32.toInt(),
                summary = true,
            )
            Log.d(
                TAG,
                "Summary notification shown=$shown itemIds=${newRecords.map { it.id }}",
            )
            return if (shown) newRecords.mapTo(mutableSetOf()) { it.id } else emptySet()
        }
        val shownIds = mutableSetOf<String>()
        newRecords.forEach { record ->
            val shown = Alertes.afficher(
                context,
                record.id,
                record.type,
                record.title,
                record.text,
                record.target,
            )
            Log.d(
                TAG,
                "Item notification id=${record.id} shown=$shown " +
                    "reason=${if (shown) "notify() succeeded" else "permission/channel unavailable"}",
            )
            if (shown) shownIds += record.id
        }
        return shownIds
    }

    private data class NotificationRecord(
        val id: String,
        val type: String,
        val title: String,
        val text: String,
        val createdAtMillis: Long?,
        val target: Map<String, String?>,
    )
}
