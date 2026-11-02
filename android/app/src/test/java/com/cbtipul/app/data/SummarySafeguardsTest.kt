package com.cbtipul.app.data

import com.cbtipul.app.model.Session
import com.cbtipul.app.ui.patients.SessionEditorDraft
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

class SummarySafeguardsTest {
    private fun allowance(tokens: Double = 500.0, seconds: Double = 60.0) = SummaryAllowance(
        "2026-10-22T10:00:00Z", "2026-10", "2026-11-01T00:00:00Z",
        SummaryAllowance.Balance(1000.0, 1000.0-tokens, tokens, tokens==0.0),
        SummaryAllowance.Balance(600.0, 600.0-seconds, seconds, seconds==0.0))
    private fun failure(kind: SummaryFailure.Kind, action: () -> Unit) {
        try { action(); fail("Expected failure") } catch (e: SummaryFailure) { assertEquals(kind, e.kind) }
    }
    @Test fun interruptedAdtsDurationUsesCompletedFrames() {
        // AAC LC, 44.1kHz, 9-byte frame (7 header + 2 payload).
        val frame=byteArrayOf(0xFF.toByte(),0xF1.toByte(),0x50,0x80.toByte(),0x01,0x3F,0xFC.toByte(),0,0)
        val data=frame+frame+frame.copyOf(8)
        assertEquals(2048.0/44100,SessionAudioMetadata.duration(data.inputStream()),0.000001)
    }
    @Test fun tokensAndVoiceDurationAreCheckedSeparately() {
        assertFalse(allowance(seconds=0.0).assess())
        failure(SummaryFailure.Kind.Tokens) { allowance(tokens=0.0).assess() }
        failure(SummaryFailure.Kind.Transcription) { allowance(seconds=0.0).assess(seconds=1.0) }
        failure(SummaryFailure.Kind.Duration) { allowance(seconds=59.0).assess(seconds=60.0) }
    }
    @Test fun lowThresholdAndCompletedSteps() {
        assertTrue(allowance(tokens=100.0).assess())
        assertFalse(allowance(tokens=101.0).assess())
        assertFalse(allowance(tokens=0.0, seconds=0.0).assess(needsTokens=false))
        assertFalse(allowance(seconds=0.0).assess(seconds=null))
    }
    @Test fun earlySuccessDoesNotAuthorizeLaterProcessing() {
        allowance().assess()
        failure(SummaryFailure.Kind.Tokens) { allowance(tokens=0.0).assess() }
        assertEquals(SummaryFailure.Kind.Tokens, SummaryFailure.classify(429, """{"monthlyLimit":100,"usedTokens":101,"remainingTokens":0}"""))
    }
    @Test fun malformedLookupNeverMeansExhaustion() {
        failure(SummaryFailure.Kind.Lookup) { allowance().copy(checkedAt="invalid").assess() }
        failure(SummaryFailure.Kind.Lookup) { allowance().copy(tokens=SummaryAllowance.Balance(100.0, 2.0, 0.0, true)).assess() }
    }
    @Test fun ratesAndMessagesAreNotMonthlyExhaustion() {
        assertEquals(SummaryFailure.Kind.Rate, SummaryFailure.classify(429))
        assertEquals(SummaryFailure.Kind.Rate, SummaryFailure.classify(429, """{"error":"Monthly chat token limit exceeded"}"""))
        assertEquals(SummaryFailure.Kind.Rate, SummaryFailure.classify(429, """{"monthlyLimit":"100","usedTokens":101,"remainingTokens":0}"""))
        assertEquals(SummaryFailure.Kind.Login, SummaryFailure.classify(401))
        assertEquals(SummaryFailure.Kind.Service, SummaryFailure.classify(503))
        assertEquals(SummaryFailure.Kind.Conflict, SummaryFailure.classify(409))
    }
    @Test fun transportErrorsAreSafe() = runTest {
        assertEquals(SummaryFailure.Kind.Connection, SummaryFailure.from(java.io.IOException("secret clinical text")).kind)
        assertFalse(SummaryFailure.from(IllegalStateException("secret clinical text")).message!!.contains("secret"))
    }
    class Storage : DeviceDraftStorage {
        val entries = mutableMapOf<String,String>()
        var fail = false
        override fun read(key:String) = entries[key]
        override fun write(key:String, value:String) { check(!fail); entries[key]=value }
        override fun clear(key:String) { check(!fail); entries.remove(key) }
    }
    private fun draft(storage: Storage, account: String = "account-a") = SessionEditorDraft(Session()).also { it.configureRecovery(storage, account) }
    @Test fun transcriptPreparedResultAndAudioSurviveRelaunch() {
        val store=Storage(); val first=draft(store)
        first.notes="Original transcript"; first.audioName="11111111-1111-1111-1111-111111111111.aac"
        first.audioSeconds=181.0; first.transcriptReady=true
        first.preparedSource=first.notes; first.preparedText="Anonymized transcript"
        assertTrue(first.persistRecovery())
        val next=draft(store)
        assertTrue(next.transcriptReady); assertEquals(181.0,next.audioSeconds,0.01)
        assertEquals(first.audioName,next.audioName); assertEquals("Anonymized transcript",next.prepared)
        next.notes="Edited original"
        assertNull(next.prepared)
        assertEquals("Edited original",draft(store).notes)
        assertEquals("",draft(store,"account-b").notes)
    }
    @Test fun failureKeepsInputAndDoesNotClaimPreserved() {
        val store=Storage();val d=draft(store);store.fail=true
        d.notes="Unsaved edit"
        assertFalse(d.persistRecovery());assertTrue(d.recoveryFailed);assertFalse(d.recoverySaved)
        assertEquals("Unsaved edit",d.notes)
    }
    @Test fun uncertainStateSurvivesBothPossibleServerOutcomes() {
        for (serverCommitted in listOf(false,true)) {
            val store=Storage();val d=draft(store)
            d.notes="Original";d.pendingCreation=true;assertTrue(d.persistRecovery())
            // Receipt lost OR request never arrived: neither may unlock automatic retry.
            val restored=draft(store);assertTrue(restored.pendingCreation)
            assertEquals("Original",restored.notes)
            if (serverCommitted) { restored.clearRecovery(close=true);assertNull(store.entries["account-a"]) }
        }
    }
    @Test fun voiceRetryUsesDurableTranscriptAndPreparedText() = runTest {
        val storage=Storage();var d=draft(storage);d.audioSeconds=5.0
        var transcriptions=0;var anonymizations=0
        suspend fun process(fail:Boolean) = com.cbtipul.app.ui.patients.processSummaryVoice(d,
            { allowance() }, { transcriptions++; "Original transcript" },
            { anonymizations++; if(fail) throw SummaryFailure(SummaryFailure.Kind.Tokens); "Safe text" },
            {}, { true })
        try { process(true);fail() } catch(_:SummaryFailure) {}
        d=draft(storage)
        assertTrue(d.transcriptReady);assertEquals("Original transcript",d.notes)
        process(false)
        assertEquals(1,transcriptions);assertEquals(2,anonymizations)
        d=draft(storage);process(false)
        assertEquals(1,transcriptions);assertEquals(2,anonymizations)
        assertEquals("Original transcript",d.notes)
    }
    @Test fun failedPersistenceBlocksVoiceProcessing() = runTest {
        val storage=Storage();val d=draft(storage);d.notes="Existing";storage.fail=true
        var calls=0
        try {
            com.cbtipul.app.ui.patients.processSummaryVoice(d,{allowance()}, { calls++; "text" }, { calls++; "safe" }, {}, {true})
            fail()
        } catch(e:SummaryFailure) { assertEquals(SummaryFailure.Kind.Local,e.kind) }
        assertEquals(0,calls)
    }
    @Test fun clearingTextDoesNotClearProtectedRecovery() {
        val store=Storage();val d=draft(store);d.notes="Started";d.notes=""
        assertTrue(store.entries.containsKey("account-a"))
        assertTrue(draft(store).hasSummaryDraft)
    }
    @Test fun explicitDiscardAndAcknowledgedSaveCleanup() {
        for (saved in listOf(false,true)) {
            val store=Storage();val d=draft(store);d.notes="Draft"
            if(saved) d.markSaved(d.snapshot()) else d.clearRecovery(close=true)
            assertFalse(d.persistRecovery());assertNull(store.entries["account-a"])
        }
    }
}
