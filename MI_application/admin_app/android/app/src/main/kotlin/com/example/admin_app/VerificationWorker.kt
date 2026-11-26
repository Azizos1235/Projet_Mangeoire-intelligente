package com.example.admin_app

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class VerificationWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        Log.d(NotificationSync.TAG, "WorkManager worker started at=${System.currentTimeMillis()}")
        val result = when (NotificationSync.synchronize(applicationContext)) {
            SyncOutcome.SUCCESS -> Result.success()
            SyncOutcome.RETRY -> Result.retry()
            SyncOutcome.SESSION_EXPIRED -> Result.success()
        }
        Log.d(NotificationSync.TAG, "WorkManager worker ended result=$result")
        return result
    }

    companion object {
        fun planifier(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = PeriodicWorkRequestBuilder<VerificationWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 20, TimeUnit.SECONDS)
                .addTag(SessionNatif.WORK_TAG)
                .build()
            Log.d(
                NotificationSync.TAG,
                "Planificateur planifier unique=${SessionNatif.WORK_NAME} " +
                    "intervalMinutes=15 policy=KEEP",
            )
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                SessionNatif.WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun maintenant(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = OneTimeWorkRequestBuilder<VerificationWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 20, TimeUnit.SECONDS)
                .addTag(SessionNatif.WORK_TAG)
                .build()
            Log.d(NotificationSync.TAG, "Planificateur maintenant unique=false")
            WorkManager.getInstance(context).enqueue(request)
        }

        fun annuler(context: Context) {
            Log.d(
                NotificationSync.TAG,
                "Planificateur annuler unique=${SessionNatif.WORK_NAME} " +
                    "tag=${SessionNatif.WORK_TAG}",
            )
            WorkManager.getInstance(context).cancelUniqueWork(SessionNatif.WORK_NAME)
            WorkManager.getInstance(context).cancelAllWorkByTag(SessionNatif.WORK_TAG)
            ServiceSurveillance.stop(context)
        }
    }
}
