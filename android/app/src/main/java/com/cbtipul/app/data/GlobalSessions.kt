package com.cbtipul.app.data

import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.Session
import java.util.Calendar
import java.util.Date

data class GlobalSessionItem(
    val patient: Patient,
    val session: Session,
    val number: Int,
)

data class GlobalSessionMonthGroup(
    val month: Date,
    val items: List<GlobalSessionItem>,
)

object GlobalSessions {
    fun items(patients: List<Patient>): List<GlobalSessionItem> =
        patients.flatMap { patient ->
            val chronological = patient.sessions.sortedBy { it.date.time }
            chronological.mapIndexed { index, session ->
                GlobalSessionItem(patient = patient, session = session, number = index + 1)
            }
        }

    fun grouped(patients: List<Patient>, unnamed: String): List<GlobalSessionMonthGroup> {
        val calendar = Calendar.getInstance()
        return items(patients)
            .groupBy { item ->
                calendar.time = item.session.date
                calendar.set(Calendar.DAY_OF_MONTH, 1)
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                calendar.time
            }
            .entries
            .sortedByDescending { it.key.time }
            .map { (month, groupItems) ->
                val ordered = groupItems.sortedWith(
                    compareByDescending<GlobalSessionItem> { it.session.date.time }
                        .thenBy { it.patient.displayName(unnamed) },
                )
                GlobalSessionMonthGroup(month, ordered)
            }
    }

    fun timeline(patients: List<Patient>, unnamed: String, query: String, upcoming: Boolean, now: Date = Date()): List<GlobalSessionMonthGroup> {
        val day = Calendar.getInstance().apply {
            time = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        return grouped(patients, unnamed).mapNotNull { group ->
            val filtered = group.items.filter {
                (it.session.date >= day) == upcoming && it.patient.displayName(unnamed).contains(query.trim(), ignoreCase = true)
            }
            if (filtered.isEmpty()) null else group.copy(items = if (upcoming) filtered.sortedBy { it.session.date } else filtered)
        }.let { if (upcoming) it.reversed() else it }
    }

    fun activePatients(patients: List<Patient>) =
        patients.filter { it.status == PatientStatus.Active }

    fun inactivePatients(patients: List<Patient>) =
        patients.filter { it.status != PatientStatus.Active }

    fun linkedQuestionnaire(
        session: Session,
        records: List<CompletedQuestionnaire>,
    ): CompletedQuestionnaire? {
        val sessionId = session.databaseId?.queryValue ?: return null
        return records.firstOrNull { it.sessionId?.queryValue == sessionId }
    }
}
