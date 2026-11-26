package com.example.admin_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VerificationWorkerTest {
    @Test
    fun notificationIntentSpecsDoNotSetData() {
        val view = buildNotificationIntentSpec("com.example.admin_app", "view", 1486)
        val ignore = buildNotificationIntentSpec("com.example.admin_app", "ignore", 1486)

        assertNull(view.dataUri)
        assertNull(ignore.dataUri)
        assertEquals(1486, view.requestCode)
        assertNotEquals(view.action, ignore.action)
    }

    @Test
    fun firstRunNotifiesOnlyAlertsCreatedAfterThisLogin() {
        val selection = NotificationPolicy.select(
            role = "admin",
            currentItems = listOf(
                NotificationCandidate("old", "appetite_low", 900L),
                NotificationCandidate("new", "appetite_high", 1_001L),
            ),
            alreadyNotified = emptySet(),
            firstRun = true,
            loginAtMillis = 1_000L,
        )

        assertEquals(listOf("new"), selection.itemsToNotify.map { it.id })
        assertEquals(setOf("old", "new"), selection.currentIds)
        assertEquals(setOf("old"), selection.silentIds)
        assertEquals(
            setOf("old"),
            NotificationSyncPolicy.idsToPersist(
                selection.currentIds,
                emptySet(),
                emptySet(),
                selection.silentIds,
            ),
        )
    }

    @Test
    fun newAlertIsNotifiedOnceAndUnshownItemsAreNotPersisted() {
        val alert1 = NotificationCandidate("alert-1", "appetite_high", 1_100L)
        val alert2 = NotificationCandidate("alert-2", "task_completed", 1_200L)
        val first = NotificationPolicy.select(
            "admin",
            listOf(alert1),
            emptySet(),
            firstRun = true,
            loginAtMillis = 1_000L,
        )
        assertEquals(
            emptySet<String>(),
            NotificationSyncPolicy.idsToPersist(first.currentIds, emptySet(), emptySet()),
        )

        val afterShown = NotificationSyncPolicy.idsToPersist(
            first.currentIds,
            emptySet(),
            setOf("alert-1"),
        )
        val second = NotificationPolicy.select(
            "admin",
            listOf(alert1, alert2),
            afterShown,
            firstRun = false,
            loginAtMillis = 1_000L,
        )

        assertEquals(listOf("alert-2"), second.itemsToNotify.map { it.id })
        val afterSecondShown = NotificationSyncPolicy.idsToPersist(
            second.currentIds,
            afterShown,
            setOf("alert-2"),
        )
        assertTrue(
            NotificationPolicy.select(
                "admin",
                listOf(alert1, alert2),
                afterSecondShown,
                firstRun = false,
                loginAtMillis = 1_000L,
            ).itemsToNotify.isEmpty(),
        )
    }

    @Test
    fun firstRunSkipsAlertsAlreadyVisibleInTheForeground() {
        val selection = NotificationPolicy.select(
            role = "admin",
            currentItems = listOf(
                NotificationCandidate("alert-1", "appetite_high", 1_100L),
            ),
            alreadyNotified = setOf("alert-1"),
            firstRun = true,
            loginAtMillis = 1_000L,
        )

        assertTrue(selection.itemsToNotify.isEmpty())
    }

    @Test
    fun clearedAlertIsRemovedFromTrackedIds() {
        val persisted = NotificationSyncPolicy.idsToPersist(
            currentIds = setOf("alert-2"),
            alreadyNotified = setOf("alert-1", "alert-2"),
            shownIds = emptySet(),
        )

        assertEquals(setOf("alert-2"), persisted)
    }

    @Test
    fun unauthorizedResponseClearsSessionAndIsClassifiedAsExpired() {
        var cleared = false
        val outcome = NotificationSyncPolicy.onUnauthorized { cleared = true }

        assertTrue(cleared)
        assertEquals(SyncOutcome.SESSION_EXPIRED, outcome)
    }

    @Test
    fun unknownAlertTypesAreIgnored() {
        val selection = NotificationPolicy.select(
            "admin",
            listOf(NotificationCandidate("alert-1", "manual", 1_100L)),
            emptySet(),
            firstRun = false,
            loginAtMillis = 1_000L,
        )

        assertTrue(selection.itemsToNotify.isEmpty())
        assertTrue(selection.currentIds.isEmpty())
    }
}
