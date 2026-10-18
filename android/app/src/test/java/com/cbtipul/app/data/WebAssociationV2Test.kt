package com.cbtipul.app.data

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class WebAssociationV2Test {
    private val workspace="11111111-1111-1111-1111-111111111111"
    private val patient="33333333-3333-3333-3333-333333333333"
    private val session="44444444-4444-4444-4444-444444444444"
    private val item="22222222-2222-2222-2222-222222222222"
    private val bigID="9223372036854775806"
    private fun base(link:Boolean=true,target:Boolean=true)=WebAssociationRequest(workspace,patient,p_existing_session_id=if(target)session else null,p_link_questionnaire=link)
    private fun candidate(incoming:Boolean=false,disabled:Boolean=false,current:Boolean=false,id:String=bigID)=WebAssociationCandidate(
        source=if(incoming)"incoming" else "existing",id=if(incoming)null else id,item_id=if(incoming)item else null,
        measurement_date=if(current)"2026-09-20" else "2026-10-10",recorded_at="2026-10-13T13:30:00Z",time_kind=if(incoming)"completed_at" else "created_at",
        session_id=if(disabled)"55555555-5555-5555-5555-555555555555" else if(current)session else null,selectable=!disabled,is_current_session_questionnaire=current,
        gad7_answers=List(7){1},phq9_answers=List(9){1},interference_level=2,gad7_score=7,phq9_score=9)
    private fun preview(candidates:List<WebAssociationCandidate>,append:Boolean=false,token:String="token-one",target:Boolean=true)=WebAssociationPreview(
        workspace,patient,if(target)session else null,token,append,append,append,"2026-10-10",candidates,candidates.count{it.selectable},candidates.count{it.selectable}>1,candidates.firstOrNull{it.is_current_session_questionnaire}?.id)
    private val receipt get()="""{"workspace_id":"$workspace","patient_id":"$patient","session_id":"$session","resources":[],"linked_questionnaire_id":"$bigID","notes_appended":true}"""
    @Test fun candidateDaysTimesScoresStringsAndFlagsStayDistinct() {
        val raw=webWorkspaceJson.encodeToString(preview(listOf(candidate(true),candidate(),candidate(current=true,id="9007199254740993"),candidate(disabled=true,id="12"))))
        val p=webWorkspaceJson.decodeFromString<WebAssociationPreview>(raw)
        assertEquals(4,p.questionnaires.size);assertEquals(3,p.selectable_questionnaire_count)
        assertEquals("completed_at",p.questionnaires[0].time_kind);assertEquals("created_at",p.questionnaires[1].time_kind)
        assertEquals("2026-10-10",p.questionnaires[0].measurement_date);assertEquals("2026-09-20",p.questionnaires[2].measurement_date)
        assertTrue(p.questionnaires[2].is_current_session_questionnaire);assertFalse(p.questionnaires[3].selectable)
        assertEquals(bigID,p.questionnaires[1].id);assertEquals("9007199254740993",p.questionnaires[2].id);assertTrue(p.questionnaires[0].flagsQuestionNine)
    }
    @Test fun choicesHaveExactlyTwoKeysAndDisabledCannotBeSelected() {
        val p=preview(listOf(candidate(true),candidate(),candidate(disabled=true,id="12")))
        assertThrows(WebWorkspaceException::class.java){p.prepare(base(),null)}
        val incoming=p.prepare(base(),candidate(true).choice)
        assertEquals(setOf("source","item_id"),incoming.p_questionnaire_choice!!.keys)
        val existing=p.prepare(base(),candidate().choice)
        assertEquals(setOf("source","id"),existing.p_questionnaire_choice!!.keys)
        assertEquals(bigID,existing.p_questionnaire_choice["id"]!!.jsonPrimitive.content)
        assertThrows(WebWorkspaceException::class.java){p.prepare(base(),candidate(disabled=true,id="12").choice)}
    }
    @Test fun notesOnlyCanChooseExistingAndPatientOnlyPreservesLinks() {
        val p=preview(listOf(candidate(),candidate(current=true,id="2")),append=true)
        val r=p.prepare(base(),candidate().choice)
        assertTrue(r.valid(true,false));assertFalse(r.p_acknowledge_existing_notes)
        assertTrue(p.confirmed(r).p_acknowledge_existing_notes)
        val preserve=p.prepare(base(link=false),candidate().choice)
        assertEquals(JsonNull,webWorkspaceJson.encodeToJsonElement(preserve).jsonObject["p_questionnaire_choice"])
        val standalone=preview(listOf(candidate(true),candidate()),target=false).prepare(base(link=false,target=false),null)
        assertTrue(standalone.valid(false,true));assertNull(standalone.p_existing_session_id);assertFalse(standalone.p_link_questionnaire)
    }
    @Test fun missingDatesAnswersScoresRemainMissingAndQuestionNineIsFlagged() {
        val raw="""{"source":"existing","id":"$bigID","selectable":true,"is_current_session_questionnaire":false,"phq9_answers":[null,null,null,null,null,null,null,null,1]}"""
        val c=webWorkspaceJson.decodeFromString<WebAssociationCandidate>(raw)
        assertNull(c.measurement_date);assertNull(c.recorded_at);assertNull(c.gad7_score);assertFalse(c.hasCompleteAnswers);assertTrue(c.flagsQuestionNine)
    }
    @Test fun changedTargetAndOldTokenCannotBeConfirmed() {
        val p=preview(listOf(candidate()),append=true)
        val r=p.prepare(base(),candidate().choice)
        assertThrows(WebWorkspaceException::class.java){p.confirmed(r.copy(p_preview_token="old"))}
        assertThrows(WebWorkspaceException::class.java){p.prepare(base().copy(p_patient_id="99999999-9999-9999-9999-999999999999"),candidate().choice)}
    }
    @Test fun previewUsesOnlyTargetAndReadOnlyNeverWrites()=runBlocking {
        val calls=mutableListOf<String>();var body:JsonObject?=null
        val repo=WebWorkspaceRepository({name,args->calls+=name;body=args;webWorkspaceJson.encodeToString(preview(listOf(candidate()),target=false))},{"owner"},{null},{_,_->},{false})
        val target=WebAssociationTarget(workspace,patient,p_create_session=true,p_session_date="2026-10-15",p_session_type="intake")
        repo.preview(target)
        assertEquals("2026-10-15",body!!["p_session_date"]!!.jsonPrimitive.content);assertTrue(body!!["p_create_session"]!!.jsonPrimitive.boolean)
        assertFalse(body!!.containsKey("p_link_questionnaire"));assertFalse(body!!.containsKey("p_questionnaire_choice"))
        try{repo.associate(base());fail()}catch(e:WebWorkspaceException){assertEquals(WebWorkspaceFailure.ReadOnly,e.failure)}
        assertEquals(listOf("preview_web_workspace_association"),calls)
    }
    @Test fun stalePreviewClearsRequestAndRequiresNewChoiceAndConfirmation()=runBlocking {
        var writes=0;var previews=0
        val repo=WebWorkspaceRepository({name,_->when(name){
            "preview_web_workspace_association"->{previews++;webWorkspaceJson.encodeToString(preview(listOf(candidate(),candidate(true)),true,if(previews==1)"one" else "two"))}
            "list_pending_web_workspaces"->"[]"
            else->{assertEquals("associate_web_workspace_v2",name);writes++;if(writes==1)error("association_preview_changed");receipt}
        }},{"owner"},{null},{_,_->},{true})
        val p=repo.preview(base().target)
        try{repo.associate(p.confirmed(p.prepare(base(),candidate().choice)));fail()}catch(e:WebWorkspaceException){assertEquals(WebWorkspaceFailure.PreviewChanged,e.failure)}
        assertEquals(1,writes);assertTrue(repo.state.value.requests.isEmpty());assertTrue(repo.state.value.busy.isEmpty())
        val fresh=repo.preview(base().target)
        assertThrows(WebWorkspaceException::class.java){fresh.prepare(base(),null)}
        repo.associate(fresh.confirmed(fresh.prepare(base(),candidate(true).choice)))
        assertEquals(2,writes);assertEquals(2,previews);assertEquals(bigID,repo.linkedQuestionnaireId)
    }
    @Test fun lostAckRetriesExactTokenChoiceAndAppendAckOnlyOnce()=runBlocking {
        val persistence=mutableMapOf<String,String>();val bodies=mutableListOf<JsonObject>();var appends=0;var refreshed=0;var notices=0
        val rpc:suspend(String,JsonObject)->String={name,args->if(name=="list_pending_web_workspaces")"[]" else {
            assertEquals("associate_web_workspace_v2",name);bodies+=args
            if(bodies.size==1){appends++;throw java.io.IOException("response lost")}
            assertEquals(bodies[0],args);receipt
        }}
        fun repository()=WebWorkspaceRepository(rpc,{"owner"},{persistence[it]},{k,v->persistence[k]=v},{true})
        val p=preview(listOf(candidate(),candidate(true)),append=true);val submitted=p.confirmed(p.prepare(base(),candidate().choice))
        try{repository().associate(submitted)}catch(_:WebWorkspaceException){}
        val next=repository();next.refreshRecords={refreshed++;true};next.refreshNotifications={notices++}
        next.associate(base(link=false))
        assertEquals(1,appends);assertEquals(bodies[0],bodies[1]);assertEquals(1,refreshed);assertEquals(1,notices)
        assertTrue(bodies[1]["p_acknowledge_existing_notes"]!!.jsonPrimitive.boolean);assertEquals(p.preview_token,bodies[1]["p_preview_token"]!!.jsonPrimitive.content)
        assertTrue(next.state.value.requests.isEmpty());assertEquals(bigID,next.linkedQuestionnaireId)
    }
    @Test fun refreshFailureAfterAcknowledgementIsNotAnotherAssociation()=runBlocking {
        var writes=0;var notices=0
        val repo=WebWorkspaceRepository({name,_->if(name=="list_pending_web_workspaces")"[]" else{writes++;receipt}},{"owner"},{null},{_,_->},{true})
        repo.refreshRecords={throw java.io.IOException("refresh")};repo.refreshNotifications={notices++}
        repo.associate(preview(listOf(candidate())).confirmed(preview(listOf(candidate())).prepare(base(),candidate().choice)))
        assertEquals(1,writes);assertEquals(1,notices);assertTrue(repo.state.value.refreshFailed);assertTrue(repo.state.value.requests.isEmpty())
    }
    @Test fun oneEligibleIsAutomaticButSeveralNeedExplicitChoice() {
        val only=preview(listOf(candidate(incoming=true),candidate(disabled=true,id="12")))
        assertEquals(candidate(incoming=true).choice,only.resolvedChoice(null))
        val multiple=preview(listOf(candidate(incoming=true),candidate()))
        assertNull(multiple.resolvedChoice(null))
        assertEquals(candidate().choice,multiple.resolvedChoice(candidate().choice))
        assertNull(multiple.resolvedChoice(candidate(id="12").choice))
    }
    @Test fun finalSaveAcknowledgesVisibleAppendAndNeverNeedsASecondConfirmation() {
        val p=preview(listOf(candidate()),append=true)
        val submitted=p.confirmed(p.prepare(base(),p.resolvedChoice(null)))
        assertTrue(submitted.p_acknowledge_existing_notes)
        assertEquals(candidate().choice,submitted.p_questionnaire_choice)
        val notesOnly=p.confirmed(p.prepare(base(link=false),null))
        assertTrue(notesOnly.p_acknowledge_existing_notes);assertNull(notesOnly.p_questionnaire_choice)
    }
    @Test fun staleRefreshPreservesValidChoiceAndDoesNotSilentlyAcceptANewAppendWarning() {
        val old=preview(listOf(candidate(),candidate(incoming=true)),append=true)
        val request=old.confirmed(old.prepare(base(),candidate().choice))
        val fresh=old.copy(preview_token="fresh")
        assertTrue(fresh.canContinueSaving(request,fresh.resolvedChoice(candidate().choice),true))
        assertFalse(fresh.canContinueSaving(request,null,true))
        val notesRequest=old.confirmed(old.prepare(base(link=false),null))
        assertFalse(fresh.copy(has_notes=false,notes_will_append=false).canContinueSaving(notesRequest,null,true))
        assertFalse(fresh.canContinueSaving(request,candidate().choice,false))
        val replacement=preview(listOf(candidate(incoming=true)))
        assertFalse(replacement.canContinueSaving(request,replacement.resolvedChoice(candidate().choice),true))
    }
    @Test fun knownMissingServiceAndRejectionDoNotKeepUncertainRequests()=runBlocking {
        for(failure in listOf(WebWorkspaceFailure.ServiceUnavailable,WebWorkspaceFailure.Rejected)) {
            val repository=WebWorkspaceRepository({_,_->throw WebWorkspaceException(failure)},{"owner"},{null},{_,_->},{true})
            val p=preview(listOf(candidate()))
            try{repository.associate(p.confirmed(p.prepare(base(),p.resolvedChoice(null))));fail()}catch(e:WebWorkspaceException){assertEquals(failure,e.failure)}
            assertTrue(repository.state.value.requests.isEmpty());assertTrue(repository.state.value.busy.isEmpty())
        }
        assertEquals(WebWorkspaceFailure.ServiceUnavailable,WebWorkspaceFailure.classify(Exception("PGRST202")))
        assertEquals(WebWorkspaceFailure.Uncertain,WebWorkspaceFailure.classify(java.io.IOException("connection lost")))
    }

}
