package com.cbtipul.app.telemetry

import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import org.junit.Assert.*
import org.junit.Test

class RecordingCapture:TelemetryCapture {
    val events=mutableListOf<Event>()
    var resets=0
    override fun capture(event:Event) {events+=event}
    override fun reset() {resets++}
}
class TelemetryClientTest {
    @Test fun typedSchemaAndNoClinicalProperties() {
        val sink=RecordingCapture();val c=TelemetryClient({Metadata()},sink)
        c.operation(Flow.access,form=Form.diaryOne).event(Stage.succeeded,access=Access.read_only)
        c.operation(Flow.submission).event(Stage.succeeded);assertTrue(sink.events.isEmpty())
        c.operation(Flow.access).event(Stage.failed,error=SafeError.unresolved)
        val event=sink.events.single();assertNull(event.access)
        assertFalse(event.copy(httpStatus=200).valid());assertFalse(event.copy(correlationID="clinical-id").valid())
    }
    @Test fun timestampCorrelationAndMonotonicDuration() {
        var mono=0L;val sink=RecordingCapture();val c=TelemetryClient({Metadata()},sink,wall={10_000L},monotonic={mono})
        val op=c.begin(Flow.access);mono=75;op.event(Stage.succeeded,access=Access.full)
        assertEquals(75L,sink.events.last().durationMs)
        assertTrue(sink.events.all {it.timestamp=="1970-01-01T00:00:10Z" && it.correlationID==op.correlation})
    }
    @Test fun restorationResetAndAlreadyCapturedMetadata() {
        val sink=RecordingCapture();val c=TelemetryClient({Metadata()},sink)
        c.setOwner("private-a",Role.therapist);assertEquals(0,sink.resets)
        val old=c.begin(Flow.access);val captured=sink.events.single()
        c.setOwner("private-a",Role.therapist);assertEquals(0,sink.resets)
        c.setOwner(null,Role.unknown);c.setOwner("private-b",Role.patient);assertEquals(2,sink.resets)
        old.event(Stage.succeeded,access=Access.full);assertEquals(1,sink.events.size)
        old.rebound().event(Stage.succeeded,access=Access.full);assertEquals(Role.patient,sink.events.last().metadata.role)
        assertEquals(captured,sink.events.first())
        c.setOwner("private-b",Role.therapist);assertEquals(3,sink.resets)
        val json=Json.encodeToString(sink.events);assertFalse(json.contains("private-a"));assertFalse(json.contains("private-b"))
    }
    @Test fun disabledAndBrokenCaptureCannotAffectBusiness()=runTest {
        val previous=Telemetry.client
        try {
            val broken=object:TelemetryCapture {override fun capture(event:Event){error("raw sensitive SDK exception")};override fun reset(){error("raw")}}
            Telemetry.install(TelemetryClient({Metadata()},broken))
            assertEquals(42,Telemetry.measure(Flow.submission,form=Form.diaryTwo){42})
            val failure=IllegalStateException("private clinical content")
            try {Telemetry.measure(Flow.submission,form=Form.diaryThree){throw failure};fail()}catch(e:IllegalStateException){assertSame(failure,e)}
            val cancelled=CancellationException("private")
            try {Telemetry.measure(Flow.authentication,method=Method.google){throw cancelled};fail()}catch(e:CancellationException){assertSame(cancelled,e)}
            Telemetry.install(TelemetryClient({error("metadata failure")}))
            assertEquals(9,Telemetry.measure(Flow.submission,form=Form.diaryOne){9})
        } finally {Telemetry.install(previous)}
    }
    @Test fun allAuthAndSubmissionOutcomesAndDemo()=runTest {
        val previous=Telemetry.client;val sink=RecordingCapture();val c=TelemetryClient({Metadata()},sink);Telemetry.install(c);c.setDemo(true)
        try {
            for(method in Method.entries) Telemetry.measure(Flow.authentication,method=method){Unit}
            for(form in Form.entries) {Telemetry.measure(Flow.submission,form=form){Unit};runCatching {Telemetry.measure(Flow.submission,form=form){error("private answer")}}}
            assertEquals(4,sink.events.count {it.flow==Flow.authentication && it.stage==Stage.succeeded})
            assertEquals(4,sink.events.count {it.flow==Flow.submission && it.stage==Stage.failed})
            assertTrue(sink.events.all {it.metadata.demo});assertFalse(Json.encodeToString(sink.events).contains("private answer"))
        } finally {Telemetry.install(previous)}
    }
    @Test fun coldWarmAndRestoredActivityClassification() {
        val tracker=ActivityStartTracker();assertEquals(Start.cold,tracker.start(false));assertEquals(Start.warm,tracker.start(false));assertEquals(Start.unknown,tracker.start(true))
        val restored=ActivityStartTracker();assertEquals(Start.unknown,restored.start(true));assertEquals(Start.warm,restored.start(false))
    }
}
