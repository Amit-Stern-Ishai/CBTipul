package com.cbtipul.app.data

import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import java.util.Calendar
import java.util.Date

data class PatientJourneyStage(val sessions: List<Session>) {
    val type: SessionType? get() = sessions.first().type
}
/** Consecutive recorded session types, not a clinical progress measure. */
fun patientJourney(sessions: List<Session>, now: Date = Date()): List<PatientJourneyStage> {
    val endOfToday = Calendar.getInstance().apply {
        time = now; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0); add(Calendar.DAY_OF_YEAR, 1)
    }.time
    val groups = mutableListOf<PatientJourneyStage>()
    sessions.filter { it.date < endOfToday }.sortedWith(compareBy<Session> { it.date }.thenBy { it.id.toString() }).forEach { session ->
        val last = groups.lastOrNull()
        if (last != null && last.type == session.type) groups[groups.lastIndex] = last.copy(sessions = last.sessions + session)
        else groups += PatientJourneyStage(listOf(session))
    }
    return groups
}
