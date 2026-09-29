package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.push.PatientPushPersonalizer
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class DiaryThreeNotificationTest {
    private val patient = "22222222-2222-2222-2222-222222222222"
    private val target = "11111111-1111-1111-1111-111111111111"
    private val payload = NotificationPayload(AppNotificationTypes.DIARY_THREE_ASSIGNED, "n1", patient, null, target, "assignment", target)
    private val assignment = PatientAssignment(target, patient, null, null, "diary_three", Date(), Date(), null)

    @Test fun explicitTypesAndUnknownAreSafeAndSeparated() {
        val parsed = NotificationPayload.from(mapOf("type" to "diary_3_assigned", "patient_id" to patient,
            "assignment_id" to target, "resource_type" to "assignment", "resource_id" to target))!!
        assertTrue(parsed.isPatientMode())
        assertTrue(NotificationRouting.destination(parsed) is AppDestination.PatientDiaryThreeForm)
        assertTrue(NotificationRouting.therapistRoutes(NotificationRouting.destination(parsed)!!).isEmpty())
        val entry = parsed.copy(type = "diary_3_entry_added", resourceType = "diary_three_entry")
        assertFalse(entry.isPatientMode())
        assertEquals(AppDestination.DiaryThreeEntry(patient, target), NotificationRouting.destination(entry))
        assertNull(NotificationRouting.destination(parsed.copy(type = "future")))
    }
    @Test fun refreshFindsExactActiveAssignmentOrFallsBack() = runTest {
        var calls = 0
        val resolved = PatientDiaryThreeNotificationRouting.resolve(payload, patient) {
            calls++; listOf(assignment.copy(id = "other"), assignment)
        }
        assertEquals(target, resolved?.id)
        assertEquals(1, calls)
        for (rows in listOf(emptyList(), listOf(assignment.copy(typeValue = "diary_one")),
            listOf(assignment.copy(cancelledAt = Date())), listOf(assignment.copy(patientId = target)),
            listOf(assignment.copy(id = patient)))) {
            assertNull(PatientDiaryThreeNotificationRouting.resolve(payload, patient) { calls++; rows })
        }
        assertEquals(6, calls)
        assertNull(PatientDiaryThreeNotificationRouting.resolve(payload, patient) { error("offline") })
        for (bad in listOf(payload.copy(assignmentId = "bad"), payload.copy(assignmentId = "1-1-1-1-1"),
            payload.copy(resourceType = "diary_one_entry"), payload.copy(resourceId = patient), payload.copy(patientId = target))) {
            assertNull(PatientDiaryThreeNotificationRouting.matchingAssignment(listOf(assignment), bad, patient))
        }
    }
    @Test fun pendingRouteIsAvailableAfterColdStartAndConsumedOnce() {
        val store = PendingDestinationStore()
        store.offer(payload)
        assertEquals(AppDestination.PatientDiaryThreeForm(payload), store.pending.value)
        assertEquals(AppDestination.PatientDiaryThreeForm(payload), store.consume())
        assertNull(store.consume())
        assertNull(store.pending.value)
        store.offer(payload); assertNull(store.consume())
        store.offer(payload.copy(notificationId = "another")); assertNotNull(store.consume())
    }
    @Test fun exactEntryHasHistoryParentAndMalformedTargetsStayAtHistory() {
        val entry = payload.copy(type = "diary_3_entry_added", resourceType = "diary_three_entry")
        assertEquals(listOf("patient/$patient", "patient/$patient/diary-three?entry=$target"),
            NotificationRouting.therapistRoutes(NotificationRouting.destination(entry)!!))
        for (bad in listOf(entry.copy(resourceType = "diary_one_entry"), entry.copy(resourceId = "bad"), entry.copy(resourceId = null))) {
            assertEquals(listOf("patient/$patient", "patient/$patient/diary-three"),
                NotificationRouting.therapistRoutes(NotificationRouting.destination(bad)!!))
        }
    }
    @Test fun exactLookupRejectsWrongPatientWrongIdAndMissingDeletedEntry() {
        val owner = DatabaseId.Text(patient)
        val entry = DiaryThreeEntry(target, owner, "t", DiaryOneEntryCreator.Patient, "private", emptyList(), emptyList(), emptyList(), emptyList(), Date(), Date())
        assertEquals(entry, DiaryThreeEntryLookup.accepted(entry, target, owner))
        assertNull(DiaryThreeEntryLookup.accepted(entry, patient, owner))
        assertNull(DiaryThreeEntryLookup.accepted(entry, target, DatabaseId.Text(target)))
        assertNull(DiaryThreeEntryLookup.accepted(null, target, owner))
    }
    @Test fun diaryThreeSeenAndMarkOneReadPreserveGrouping() {
        val items = (0..1).map { AppNotification("$it", "diary_3_entry_added", patient, null, null, "diary_three_entry", target, Date(it.toLong()), null, null) }
        assertEquals(2, NotificationInbox.unseenCount(items))
        val seen = NotificationInbox.applyingSeen(items, Date())
        assertEquals(0, NotificationInbox.unseenCount(seen))
        assertEquals(2, NotificationInbox.unread(seen).size)
        val opened = listOf(seen[0].opened(Date()), seen[1])
        assertEquals(listOf("1"), NotificationInbox.unread(opened).map { it.id })
        assertEquals(listOf("0"), NotificationInbox.read(opened).map { it.id })
        assertEquals(InboxCopyKind.DiaryThreeEntryAdded, NotificationRouting.inboxCopy(items[0].type))
    }
    @Test fun localNameAndGenericCopyNeverUseServerClinicalText() {
        for (name in listOf("דני", null)) {
            val result = PatientPushPersonalizer.personalize("diary_3_entry_added", patient,
                "server name", "private clinical text", resourceType = "diary_three_entry", resourceId = target) { name }
            assertEquals(name ?: "מטופל/ת", result.title)
            assertEquals("הוסיף/ה רשומה חדשה ליומן 3", result.body)
            assertEquals(target, result.resourceId)
        }
    }
}
