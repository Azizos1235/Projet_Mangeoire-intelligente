package com.example.eleveur_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VerificationWorkerTest {
    @Test
    fun notificationIntentSpecsDoNotSetData() {
        val view = buildNotificationIntentSpec("com.example.eleveur_app", "view", 1486)
        val ignore = buildNotificationIntentSpec("com.example.eleveur_app", "ignore", 1486)

        assertNull(view.dataUri)
        assertNull(ignore.dataUri)
        assertEquals(1486, view.requestCode)
        assertNotEquals(view.action, ignore.action)
    }

    @Test
    fun firstRunNotifiesOnlyTasksCreatedAfterThisLogin() {
        val selection = NotificationPolicy.select(
            role = "eleveur",
            currentItems = listOf(
                NotificationCandidate("old", "custom", 900L),
                NotificationCandidate("new", "check_weight", 1_001L),
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
    fun newTaskIsNotifiedOnceAndUnshownItemsAreNotPersisted() {
        val task1 = NotificationCandidate("task-1", "check_weight", 1_100L)
        val task2 = NotificationCandidate("task-2", "custom", 1_200L)
        val first = NotificationPolicy.select(
            "eleveur",
            listOf(task1),
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
            setOf("task-1"),
        )
        val second = NotificationPolicy.select(
            "eleveur",
            listOf(task1, task2),
            afterShown,
            firstRun = false,
            loginAtMillis = 1_000L,
        )

        assertEquals(listOf("task-2"), second.itemsToNotify.map { it.id })
        val afterSecondShown = NotificationSyncPolicy.idsToPersist(
            second.currentIds,
            afterShown,
            setOf("task-2"),
        )
        assertTrue(
            NotificationPolicy.select(
                "eleveur",
                listOf(task1, task2),
                afterSecondShown,
                firstRun = false,
                loginAtMillis = 1_000L,
            ).itemsToNotify.isEmpty(),
        )
    }

    @Test
    fun firstRunSkipsTasksAlreadyVisibleInTheForeground() {
        val selection = NotificationPolicy.select(
            role = "eleveur",
            currentItems = listOf(NotificationCandidate("task-1", "custom", 1_100L)),
            alreadyNotified = setOf("task-1"),
            firstRun = true,
            loginAtMillis = 1_000L,
        )

        assertTrue(selection.itemsToNotify.isEmpty())
    }

    @Test
    fun completedTaskIsRemovedFromTrackedIds() {
        val persisted = NotificationSyncPolicy.idsToPersist(
            currentIds = setOf("task-2"),
            alreadyNotified = setOf("task-1", "task-2"),
            shownIds = emptySet(),
        )

        assertEquals(setOf("task-2"), persisted)
    }

    @Test
    fun unauthorizedResponseClearsSessionAndIsClassifiedAsExpired() {
        var cleared = false
        val outcome = NotificationSyncPolicy.onUnauthorized { cleared = true }

        assertTrue(cleared)
        assertEquals(SyncOutcome.SESSION_EXPIRED, outcome)
    }

    @Test
    fun unsupportedRoleCannotSelectTaskNotifications() {
        val selection = NotificationPolicy.select(
            "admin",
            listOf(NotificationCandidate("task-1", "custom", 1_100L)),
            emptySet(),
            firstRun = false,
            loginAtMillis = 1_000L,
        )

        assertTrue(selection.itemsToNotify.isEmpty())
        assertTrue(selection.currentIds.isEmpty())
    }
}
