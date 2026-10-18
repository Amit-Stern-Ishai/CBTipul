package com.cbtipul.app.data

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class WebWorkspaceTest {
    private val id = "11111111-1111-1111-1111-111111111111"
    private val patient = "33333333-3333-3333-3333-333333333333"
    private val session = "44444444-4444-4444-4444-444444444444"
    private val fixture = """{"id": "11111111-1111-1111-1111-111111111111", "status": "pending", "started_at": "2026-10-13T13:00:00.123+03:00", "finished_at": "2026-10-13T13:45:00+03:00", "reference_label": "בדיקה מקומית", "payload": {"version": 1, "notes": "הערות לבדיקה בלבד", "items": [{"id": "22222222-2222-2222-2222-000000000001", "type": "questionnaire", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"gad7_answers": [0, 1, 2, 3, 0, 1, 2], "phq9_answers": [0, 1, 2, 3, 0, 1, 2, 3, 1], "interference_level": 2, "notes": "הערת שאלון"}, "measurement_date": "2026-10-10"}, {"id": "22222222-2222-2222-2222-000000000002", "type": "diary_one", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"event": "אירוע לבדיקה", "automatic_thoughts": ["מחשבה אחת", "מחשבה נוספת"], "feelings": [{"name": "עצב", "intensity": 0}], "behaviour": "התנהגות", "physical_symptoms": null}}, {"id": "22222222-2222-2222-2222-000000000003", "type": "diary_two", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"event": "אירוע נוסף", "automatic_thoughts": ["מחשבה"], "feelings": [{"name": "דאגה", "intensity": 100}], "thinking_errors": ["mind_reading"], "alternative_thoughts": ["מחשבה חלופית"]}}, {"id": "22222222-2222-2222-2222-000000000004", "type": "diary_three", "completed_at": "2026-10-13T13:30:00.123+03:00", "data": {"situation": "מצב לבדיקה", "automatic_thoughts": [{"text": "מחשבה", "beliefBefore": 100, "beliefAfter": 0}], "feelings": [{"name": "דאגה", "intensityBefore": 100, "intensityAfter": 0}], "thinking_errors": ["fortune_telling"], "alternative_thoughts": [{"text": "מחשבה חלופית", "belief": 85}]}}]}}"""
    private val receipt get() = """{"workspace_id":"$id","patient_id":"$patient","session_id":null,"resources":[{"item_id":"$id","type":"questionnaire","id":"9223372036854775806"}],"linked_questionnaire_id":"9223372036854775806","notes_appended":true}"""
    private fun request(notes: Boolean = false, linked: Boolean = false, create: Boolean = false) = WebAssociationRequest(id, patient,
        p_existing_session_id = if ((notes || linked) && !create) session else null, p_create_session = create, p_link_questionnaire = linked,
        p_session_date = if (create) "2026-10-14" else null, p_session_type = if (create) "intake" else null, p_preview_token="test-preview", p_acknowledge_existing_notes=notes)

    @Test fun decodesEveryWorksheetPreservingOriginalDatesAndRatings() {
        val w = webWorkspaceJson.decodeFromString<WebWorkspace>(fixture)
        w.payload.items.forEach { it.validate() }
        assertEquals(4, w.payload.items.size)
        assertTrue(w.payload.hasNotes && w.payload.hasQuestionnaire)
        assertEquals("2026-10-13T13:00:00.123+03:00", w.started_at)
        val q = w.payload.items[0]
        assertEquals("2026-10-10", q.measurement_date)
        assertEquals("2026-10-13T13:30:00.123+03:00", q.completed_at)
        assertEquals(9, q.questionnaire().questionnaire.gad7Score)
        assertEquals(13, q.questionnaire().questionnaire.phq9Score)
        assertTrue(q.questionnaire().flagsQuestionNine)
        assertEquals(2, w.payload.items[1].diary().automatic_thoughts.size)
        assertEquals(0, w.payload.items[1].diary().feelings[0].intensity)
        assertNull(w.payload.items[1].diary().physical_symptoms)
        assertEquals(100, w.payload.items[2].diary().feelings[0].intensity)
        val three = w.payload.items[3].diaryThree()
        assertEquals(100, three.automatic_thoughts[0].beliefBefore)
        assertEquals(0, three.automatic_thoughts[0].beliefAfter)
        assertEquals(0, three.feelings[0].intensityAfter)
        assertEquals(85, three.alternative_thoughts[0].belief)
        assertEquals("9223372036854775806", webWorkspaceJson.decodeFromString<WebAssociationResult>(receipt).resources[0].id)
    }
    @Test fun validatesAssociationMatrixAndNeverEncodesPatientNames() {
        for (notes in listOf(false, true)) for (linked in listOf(false, true)) for (create in listOf(false, true)) {
            assertEquals(!create || notes || linked, request(notes, linked, create).valid(notes, true))
        }
        assertFalse(request().valid(true, true))
        assertTrue(request(linked = true).valid(false, false)) // Existing, not necessarily incoming.
        assertFalse(request(notes = true, create = true).copy(p_existing_session_id = session).valid(true, true))
        assertFalse(request(notes = true).copy(p_session_date = "2026-10-14").valid(true, true))
        val body = webWorkspaceJson.encodeToJsonElement(request(notes = true)).jsonObject
        assertEquals(JsonNull, body["p_session_date"])
        assertEquals(JsonNull, body["p_session_type"])
        assertFalse(body.keys.any { it.contains("name") })
        assertFalse(body.getValue("p_link_questionnaire").jsonPrimitive.boolean)
    }
    @Test fun exactRetrySurvivesNavigationAndProcessRecreation() = runBlocking {
        val persisted = mutableMapOf<String, String>()
        val bodies = mutableListOf<JsonObject>()
        val rpc: suspend (String, JsonObject) -> String = { name, body ->
            if (name == "list_pending_web_workspaces") "[]" else {
                bodies += body
                if (bodies.size == 1) throw java.io.IOException("response lost")
                receipt
            }
        }
        fun repository(owner: String = "a") = WebWorkspaceRepository(rpc, { owner }, { persisted[it] }, { k, v -> persisted[k] = v }, { true })
        val first = repository()
        try { first.associate(request(notes = true)); fail() } catch (e: WebWorkspaceException) { assertEquals(WebWorkspaceFailure.Uncertain, e.failure) }
        val second = repository()
        var refreshes = 0
        second.refreshRecords = { refreshes++; true }
        second.associate(request(linked = true, create = true))
        assertEquals(bodies[0], bodies[1])
        assertEquals(1, refreshes)
        assertTrue(second.state.value.requests.isEmpty())
        val other = repository("b"); other.refresh(); assertTrue(other.state.value.requests.isEmpty())
    }
    @Test fun duplicateSubmitCannotCreateSecondRpc() = runBlocking {
        val gate = CompletableDeferred<Unit>(); var calls = 0
        val repo = WebWorkspaceRepository({ name, _ -> if (name == "list_pending_web_workspaces") "[]" else { calls++; gate.await(); receipt } }, { "a" }, { null }, { _, _ -> }, { true })
        val first = launch(start = CoroutineStart.UNDISPATCHED) { repo.associate(request()) }
        try { repo.associate(request(create = true)); } catch (_: WebWorkspaceException) {}
        assertEquals(1, calls)
        gate.complete(Unit); first.join()
        assertTrue(repo.state.value.busy.isEmpty())
    }
    @Test fun conflictAllowsChangedSelectionAndReadOnlyCannotMutate() = runBlocking {
        var reject = true
        val repo = WebWorkspaceRepository({ name, _ -> if (name == "list_pending_web_workspaces") "[]" else if (reject) error("session_already_has_questionnaire") else receipt }, { "a" }, { null }, { _, _ -> }, { true })
        try { repo.associate(request(linked = true)); fail() } catch (e: WebWorkspaceException) { assertEquals(WebWorkspaceFailure.Conflict, e.failure) }
        assertTrue(repo.state.value.requests.isEmpty())
        reject = false; repo.associate(request())
        var calls = 0
        val readOnly = WebWorkspaceRepository({ _, _ -> calls++; "[]" }, { "b" }, { null }, { _, _ -> }, { false })
        try { readOnly.associate(request()); fail() } catch (_: WebWorkspaceException) {}
        try { readOnly.discard(id); fail() } catch (_: WebWorkspaceException) {}
        assertEquals(0, calls)
        readOnly.refresh(); assertEquals(1, calls)
    }
    @Test fun pickerDatesSurviveEastAndWestTimezones() {
        val midnight = java.time.Instant.parse("2026-10-14T00:00:00Z").toEpochMilli()
        for (name in listOf("America/Los_Angeles", "Asia/Jerusalem")) {
            val zone = java.time.ZoneId.of(name)
            val local = WebWorkspaceDates.fromPicker(midnight, zone)
            assertEquals("2026-10-14", java.time.Instant.ofEpochMilli(local).atZone(zone).toLocalDate().toString())
            assertEquals(midnight, WebWorkspaceDates.toPicker(local, zone))
        }
    }
    @Test fun unavailableWorkspacesStayClosedAcrossScreenReentry() = runBlocking {
        var transfers = 0
        val repo = WebWorkspaceRepository({ name, _ ->
            if (name == "list_pending_web_workspaces") "[]" else { transfers++; error("already_associated") }
        }, { "a" }, { null }, { _, _ -> }, { true })
        try { repo.discard(id); fail() } catch (_: WebWorkspaceException) {}
        assertTrue(id in repo.state.value.closedIDs)
        try { repo.associate(request()); fail() } catch (_: WebWorkspaceException) {}
        assertEquals(1, transfers)
    }
    @Test fun notificationRoutesWithoutPatientOrSession() {
        val payload = NotificationPayload("web_workspace_ready", null, null, null, null, "web_workspace", id)
        assertEquals(AppDestination.WebWorkspace(id), NotificationRouting.destination(payload))
        assertEquals("web-workspaces/$id", NotificationRouting.inboxRoute(NotificationRouting.destination(payload)!!))
        assertFalse(payload.isPatientMode())
        assertNull(NotificationRouting.destination(payload.copy(resourceType = "questionnaire")))
        assertNull(NotificationRouting.destination(payload.copy(resourceId = "not-a-uuid")))
    }
    @Test fun refreshPaginatesToAnAccurateCount() = runBlocking {
        val offsets = mutableListOf<Int>()
        val repo = WebWorkspaceRepository({ _, body ->
            val offset = body.getValue("p_offset").jsonPrimitive.int; offsets += offset
            webWorkspaceJson.encodeToString((offset until minOf(offset + 100, 101)).map { WebWorkspaceSummary("$it", "2026-10-13T00:00:00Z", "2026-10-13T00:00:00Z", null, 1, false) })
        }, { "a" }, { null }, { _, _ -> }, { true })
        repo.refresh(); assertEquals(listOf(0, 100), offsets); assertEquals(101, repo.state.value.items.size)
    }
    @Test fun consecutiveAssociationsCannotReappearFromStalePendingList() = runBlocking {
        val secondID="55555555-5555-5555-5555-555555555555"
        val rows=webWorkspaceJson.encodeToString(listOf(id,secondID).map { WebWorkspaceSummary(it,"2026-10-15T09:00:00Z","2026-10-15T10:00:00Z",null,1,true) })
        val transfers=mutableListOf<String>()
        val repo=WebWorkspaceRepository({name,body ->
            if(name=="list_pending_web_workspaces") rows else {
                val target=body.getValue("p_workspace_id").jsonPrimitive.content
                transfers+=target
                receipt.replace(id,target)
            }
        },{"a"},{null},{_,_->},{true})
        repo.refresh();assertEquals(2,repo.state.value.items.size)
        repo.associate(request(notes=true))
        assertEquals(listOf(secondID),repo.state.value.items.map {it.id})
        assertTrue(repo.state.value.busy.isEmpty() && repo.state.value.requests.isEmpty())
        repo.associate(request(notes=true).copy(p_workspace_id=secondID,p_preview_token="second-preview"))
        repo.refresh()
        assertTrue(repo.state.value.items.isEmpty())
        assertEquals(listOf(id,secondID),transfers)
        assertEquals(setOf(id,secondID),repo.state.value.closedIDs)
        assertTrue(repo.state.value.busy.isEmpty() && repo.state.value.requests.isEmpty())
    }

}
