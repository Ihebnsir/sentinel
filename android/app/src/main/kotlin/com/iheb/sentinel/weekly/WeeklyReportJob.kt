package com.iheb.sentinel.weekly

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Tâche quotidienne d'Android (JobScheduler, celui qu'utilise WorkManager
 * en dessous) : efface les semaines trop anciennes et, si l'option est
 * activée, prévient le lundi que le bilan est prêt. Aucun service permanent :
 * Android la lance environ une fois par jour, quand ça l'arrange.
 */
object WeeklyReportJob {
    // Identifiant fixe, gardé entre les mises à jour de l'app.
    private const val JOB_ID = 0x5E7701

    private val PERIOD_MS = TimeUnit.DAYS.toMillis(1)
    private val FLEX_MS = TimeUnit.HOURS.toMillis(6)

    /** Programme la tâche si elle a du travail, sinon l'annule. */
    fun sync(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val needed = WeeklyStatsStore.notificationsEnabled(context) ||
            WeeklyStatsStore.weeks(context).isNotEmpty()
        val scheduled = scheduler.getPendingJob(JOB_ID) != null
        if (needed && !scheduled) {
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, WeeklyReportJobService::class.java))
                .setPeriodic(PERIOD_MS, FLEX_MS)
                // Survit au redémarrage (permission RECEIVE_BOOT_COMPLETED déjà déclarée).
                .setPersisted(true)
                .build()
            try {
                scheduler.schedule(job)
            } catch (e: Exception) {
                // Trop de tâches ou refus du système : nouvel essai au prochain appel.
            }
        } else if (!needed && scheduled) {
            scheduler.cancel(JOB_ID)
        }
    }

    /** Le travail du jour (rapide : quelques lectures de préférences). */
    fun run(context: Context) {
        val weeks = WeeklyStatsStore.weeks(context) // efface les anciennes
        val week = WeeklyStatsStore.currentWeek()
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val notify = WeeklyLedger.shouldNotify(
            enabled = WeeklyStatsStore.notificationsEnabled(context),
            currentWeek = week,
            lastNotifiedWeek = WeeklyStatsStore.lastNotifiedWeek(context),
            localHour = hour,
            previous = weeks.firstOrNull { it.week == week - 7 },
        )
        if (notify && WeeklyReportNotifier.show(context)) {
            WeeklyStatsStore.markNotified(context, week)
        }
        sync(context) // plus rien à faire : la tâche s'arrête
    }
}

/** Lancé par Android ; protégé par BIND_JOB_SERVICE (voir le manifeste). */
class WeeklyReportJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        try {
            WeeklyReportJob.run(applicationContext)
        } catch (e: Exception) {
            // Jamais de plantage en arrière-plan.
        }
        return false // travail terminé
    }

    override fun onStopJob(params: JobParameters?): Boolean = false
}
