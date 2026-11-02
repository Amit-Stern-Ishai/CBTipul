package com.cbtipul.app.data

import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import java.util.Date
import org.junit.Assert.*
import org.junit.Test

class PatientJourneyTest {
    @Test fun groupsOnlyConsecutiveTypesAndExcludesFuture() {
        val now = Date(1700000000000)
        fun session(days: Int, type: SessionType) = Session(date = Date(now.time + days * 86400000L), type = type)
        val stages = patientJourney(listOf(session(-4, SessionType.Intake), session(-3, SessionType.Intake),
            session(-2, SessionType.DiaryOne), session(-1, SessionType.Intake), session(3, SessionType.DiaryThree)), now)
        assertEquals(listOf(2, 1, 1), stages.map { it.sessions.size })
        assertEquals(SessionType.Intake, stages.last().type)
        assertTrue(patientJourney(emptyList(), now).isEmpty())
    }
}
