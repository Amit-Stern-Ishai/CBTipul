package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.Session
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date
import java.util.UUID

class GlobalSessionsTest {
    @Test
    fun numbersArePatientRelativeChronological() {
        val older = Session(id = UUID.randomUUID(), date = Date(1_000))
        val newer = Session(id = UUID.randomUUID(), date = Date(2_000))
        val patient = Patient(id = DatabaseId.Text("p"), sessions = listOf(newer, older), localName = "דני")
        val items = GlobalSessions.items(listOf(patient))
        assertEquals(1, items.first { it.session.id == older.id }.number)
        assertEquals(2, items.first { it.session.id == newer.id }.number)
    }

    @Test
    fun groupsNewestMonthFirst() {
        val jan = Session(date = Date(1_704_067_200_000L))
        val feb = Session(date = Date(1_706_745_600_000L))
        val patient = Patient(id = DatabaseId.Text("p"), sessions = listOf(jan, feb), localName = "א")
        val groups = GlobalSessions.grouped(listOf(patient), "מטופל/ת")
        assertTrue(groups.first().month.time >= groups.last().month.time)
        assertEquals(feb.date, groups.first().items.first().session.date)
    }

    @Test
    fun pickerSeparatesActiveAndInactive() {
        val active = Patient(id = DatabaseId.Text("a"), status = PatientStatus.Active)
        val inactive = Patient(id = DatabaseId.Text("i"), status = PatientStatus.Inactive)
        assertEquals(listOf(active), GlobalSessions.activePatients(listOf(active, inactive)))
        assertEquals(listOf(inactive), GlobalSessions.inactivePatients(listOf(active, inactive)))
    }

    @Test
    fun linkedQuestionnaireRequiresSessionId() {
        val session = Session(databaseId = DatabaseId.Text("s1"))
        val linked = com.cbtipul.app.model.CompletedQuestionnaire(
            databaseId = DatabaseId.Integer(1),
            sessionId = DatabaseId.Text("s1"),
            answeredDate = Date(),
            questionnaire = com.cbtipul.app.model.CombinedMoodQuestionnaire(),
        )
        val unlinked = linked.copy(sessionId = null, databaseId = DatabaseId.Integer(2))
        assertEquals(linked.databaseId, GlobalSessions.linkedQuestionnaire(session, listOf(unlinked, linked))?.databaseId)
        assertNull(GlobalSessions.linkedQuestionnaire(Session(), listOf(unlinked)))
    }
}

class PendingDestinationStoreTest {
    @Test
    fun consumeIsOneShot() {
        val store = PendingDestinationStore()
        store.offer(AppDestination.PatientDetail("p"))
        assertEquals(AppDestination.PatientDetail("p"), store.consume())
        assertNull(store.consume())
    }
}

class TherapistRootTabsTest {
    @Test
    fun fiveDestinationsWithoutHome() {
        assertEquals(
            listOf("patients", "sessions", "notifications", "library", "settings"),
            TherapistRootTabs.ordered,
        )
        assertEquals("patients", TherapistRootTabs.DEFAULT)
        assertTrue("home" !in TherapistRootTabs.ordered)
    }
}
