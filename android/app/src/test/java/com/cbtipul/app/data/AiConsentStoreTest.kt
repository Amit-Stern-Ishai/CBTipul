package com.cbtipul.app.data

import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class AiConsentStoreTest {
    private class Server {
        var status="required"; var revision=0L; var owner="a"; var failRead=false; var lose=false; var refusal:String?=null
        val writes=mutableListOf<JsonObject>()
        val json=Json { encodeDefaults=true; explicitNulls=true }
        suspend fun call(method:String,args:JsonObject):String {
            if(method=="get_my_consent" && failRead)throw NameSyncFailure("connection")
            if(method=="record_my_consent") {
                writes+=args
                refusal?.let { throw NameSyncFailure(it) }
                status="accepted";revision=1
                if(lose){lose=false;throw NameSyncFailure("connection")}
            }
            return json.encodeToString(AiConsentReceipt(owner,"ai_data_sharing","2026-11-22",if(status=="accepted")"2026-11-22" else null,if(status=="accepted")"2026-11-22T10:00:00Z" else null,null,status,revision))
        }
        fun store()=AiConsentStore(::call,eligible={true}).also {it.setActiveUser(owner)}
    }
    @Test fun confirmedReceiptWorksOnAnotherDevice()=runBlocking {
        val server=Server();val first=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){first.ensureGranted()}
        assertTrue(first.promptVisible.value); first.accept();action.await()
        val second=server.store();second.ensureGranted();assertFalse(second.promptVisible.value);assertEquals(1,server.writes.size)
    }
    @Test fun declineSendsNothing()=runBlocking {
        val server=Server();val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        store.decline();assertTrue(action.await().isFailure);assertTrue(server.writes.isEmpty())
    }
    @Test fun lookupFailureDoesNotGrantOrBecomeRequired()=runBlocking {
        val server=Server();server.failRead=true;val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        assertTrue(store.failed.value);store.accept();assertFalse(store.accepted.value);assertTrue(server.writes.isEmpty())
        store.decline();assertTrue(action.await().isFailure)
    }
    @Test fun uncertainWriteRetriesFrozenArguments()=runBlocking {
        val server=Server();server.lose=true;val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){store.ensureGranted()}
        store.accept();assertFalse(action.isCompleted);assertTrue(store.failed.value)
        store.accept();action.await();assertEquals(server.writes[0],server.writes[1])
    }
    @Test fun supersededRetryNeverResumesAction()=runBlocking {
        val server=Server();server.lose=true;val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        store.accept();server.refusal="consent_request_superseded";store.accept()
        assertFalse(action.isCompleted);assertFalse(store.accepted.value);store.decline();assertTrue(action.await().isFailure)
    }
    @Test fun switchAccountCancelsPendingAction()=runBlocking {
        val server=Server();val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        store.setActiveUser("b");assertTrue(action.await().isFailure);assertFalse(store.promptVisible.value);assertFalse(store.accepted.value)
    }
    @Test fun leavingPatientCancelsPendingConsent()=runBlocking {
        val server=Server();val store=server.store()
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        store.cancelPending();assertTrue(action.await().isFailure);assertFalse(store.promptVisible.value);assertTrue(server.writes.isEmpty())
    }
    @Test fun malformedReceiptNeverGrants()=runBlocking {
        val store=AiConsentStore({_,_->"{}"},eligible={true});store.setActiveUser("a")
        val action=async(start=CoroutineStart.UNDISPATCHED){runCatching {store.ensureGranted()}}
        assertTrue(store.failed.value);store.decline();assertTrue(action.await().isFailure)
    }
    @Test fun patientCannotRequestConsent()=runBlocking {
        var calls=0;val store=AiConsentStore({_,_->calls++;"{}"},eligible={false});store.setActiveUser("a")
        assertTrue(runCatching {store.ensureGranted()}.isFailure);assertEquals(0,calls);assertFalse(store.promptVisible.value)
    }
}
