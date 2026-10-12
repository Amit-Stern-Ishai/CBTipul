package com.cbtipul.app.telemetry

import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable enum class Flow { authentication, restoration, access, invitation, submission, push, request, onboarding, sharing, assignment, message, ai }
@Serializable enum class Stage { started, succeeded, failed, cancelled, retry, received, previewShown, roleSwitchConfirmed, authorization, opened, shareSheetOpened, sharingReported, completed }
@Serializable enum class Feature { introduction, welcome, demoTour, displayName, invitationCreation, invitationShare, questionnaireAssignment, diaryAssignment, sendMessage, readMessage, messages, chat, transcription, sessionAnalysis, sessionPreparation, supervision, whatAmIMissing, caseReview }
@Serializable enum class Outcome { started, succeeded, failed, cancelled, retrying, observed }
private fun Stage.outcome() = when(this) { Stage.started -> Outcome.started; Stage.succeeded, Stage.completed -> Outcome.succeeded; Stage.failed -> Outcome.failed; Stage.cancelled -> Outcome.cancelled; Stage.retry -> Outcome.retrying; else -> Outcome.observed }
@Serializable enum class Method { email, google, apple, anonymous }
@Serializable enum class Form { questionnaire, diaryOne, diaryTwo, diaryThree }
@Serializable enum class Role { therapist, patient, unknown }
@Serializable enum class Access { full, read_only }
@Serializable enum class Network { wifi, cellular, ethernet, other, offline, unknown }
@Serializable enum class Lifecycle { foreground, background, unknown }
@Serializable enum class Start { cold, warm, unknown }
@Serializable enum class SafeError { none, generic, cancelled, timeout, network, unauthorized, forbidden, unavailable, unresolved }
@Serializable enum class PushOperation { permission, apnsRegistration, fcmRegistration, deviceRegistration, received, opened }
@Serializable enum class Authorization { allowed, denied, notDetermined, unknown }
@Serializable enum class Environment { development, production, unknown }
@Serializable enum class NotificationType { questionnaire, diary, patientMessage, other, unknown }
@Serializable enum class Request { appContext, invitationPreview, invitationClaim, questionnaireSubmit, diaryOneSubmit, diaryTwoSubmit, diaryThreeSubmit, pushDeviceRegister }

@Serializable data class Metadata(
    val platform: String = "android", val deviceModel: String = "unknown", val manufacturer: String = "unknown",
    val osVersion: String = "unknown", val apiLevel: Int? = null, val appVersion: String = "unknown", val build: String = "unknown",
    val buildChannel: String = "release", val distribution: String = "unknown",
    val demo: Boolean = false, val role: Role = Role.unknown,
    val network: Network = Network.unknown, val lifecycle: Lifecycle = Lifecycle.unknown,
    val locale: String = "unknown", val timezone: String = "unknown",
) {
    fun valid() = platform == "android" && distribution == "unknown" && buildChannel in listOf("debug", "release") &&
        (apiLevel == null || apiLevel in 1..1000) &&
        listOf(deviceModel,manufacturer,osVersion,appVersion,build,locale,timezone).all { it.isNotEmpty() && it.length <= 128 && it.none(Char::isISOControl) }
}
private fun uuid(value: String) = runCatching { UUID.fromString(value).toString() == value.lowercase() }.getOrDefault(false)

/** Only typed primitives and enums; never clinical objects or arbitrary properties. */
@Serializable data class Event internal constructor(
    val schemaVersion: Int = 1, val timestamp: String, val correlationID: String,
    val metadata: Metadata, val flow: Flow, val stage: Stage, val outcome: Outcome = stage.outcome(), val error: SafeError = SafeError.none,
    val durationMs: Long, val attempt: Int = 1, val retryCount: Int = attempt - 1, val feature: Feature? = null, val method: Method? = null, val form: Form? = null,
    val access: Access? = null, val start: Start? = null, val previousRole: Role? = null,
    val pushOperation: PushOperation? = null, val authorization: Authorization? = null,
    val preferenceEnabled: Boolean? = null, val apnsEnvironment: Environment? = null,
    val notificationType: NotificationType? = null, val request: Request? = null, val httpStatus: Int? = null,
) {
    fun valid(): Boolean {
        if (retryCount != attempt - 1 || outcome != stage.outcome() || schemaVersion != 1 || !metadata.valid() || !uuid(correlationID) ||
            runCatching { Instant.parse(timestamp) }.isFailure || durationMs !in 0..86_400_000 || attempt !in 1..100 ||
            (httpStatus != null && httpStatus !in 100..599)) return false
        val allowed = when(flow) {
            Flow.authentication -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled)
            Flow.restoration -> setOf(Stage.succeeded,Stage.failed)
            Flow.access, Flow.request -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled,Stage.retry)
            Flow.invitation -> setOf(Stage.received,Stage.previewShown,Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled,Stage.roleSwitchConfirmed)
            Flow.submission -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled)
            Flow.onboarding, Flow.ai -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled)
            Flow.message -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled,Stage.opened)
            Flow.sharing -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled,Stage.shareSheetOpened,Stage.sharingReported)
            Flow.assignment -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.cancelled,Stage.completed)
            Flow.push -> setOf(Stage.started,Stage.succeeded,Stage.failed,Stage.authorization,Stage.received,Stage.opened)
        }
        val features=when(flow) {
            Flow.onboarding->setOf(Feature.introduction,Feature.welcome,Feature.demoTour,Feature.displayName)
            Flow.sharing->setOf(Feature.invitationCreation,Feature.invitationShare)
            Flow.assignment->setOf(Feature.questionnaireAssignment,Feature.diaryAssignment)
            Flow.message->setOf(Feature.sendMessage,Feature.readMessage,Feature.messages)
            Flow.ai->setOf(Feature.chat,Feature.transcription,Feature.sessionAnalysis,Feature.sessionPreparation,Feature.supervision,Feature.whatAmIMissing,Feature.caseReview)
            else->null
        }
        if(features!=null && feature !in features || features==null && feature!=null) return false
        return stage in allowed && (method == null || flow == Flow.authentication) && (form == null || flow == Flow.submission) &&
            (access == null || flow == Flow.access && stage == Stage.succeeded) &&
            (start == null && previousRole == null || flow == Flow.invitation) &&
            (pushOperation == null && authorization == null && preferenceEnabled == null && apnsEnvironment == null && notificationType == null || flow == Flow.push) &&
            (request == null && httpStatus == null || flow == Flow.request) &&
            (flow != Flow.authentication || method != null) && (flow != Flow.submission || form != null) &&
            (flow != Flow.push || pushOperation != null) && (flow != Flow.request || request != null) &&
            (if(stage == Stage.failed) error != SafeError.none && error != SafeError.cancelled else if(stage == Stage.cancelled) error == SafeError.cancelled else error == SafeError.none)
    }
}
/** SDK owns buffering, delivery, retries and anonymous identity. */
interface TelemetryCapture {
    fun capture(event: Event)
    fun reset()
}
object DisabledTelemetryCapture : TelemetryCapture {
    override fun capture(event: Event) = Unit
    override fun reset() = Unit
}
class TelemetryClient(
    private val metadata: () -> Metadata,
    private var capture: TelemetryCapture = DisabledTelemetryCapture,
    private val wall: () -> Long = System::currentTimeMillis,
    private val monotonic: () -> Long = { System.nanoTime()/1_000_000 },
) {
    private val lock = Any()
    private var owner: String? = null
    private var observedOwner = false
    private var role = Role.unknown
    private var demo = false
    fun configure(capture: TelemetryCapture) = synchronized(lock) { this.capture = capture }
    /** Local equality only, never sent to PostHog. Restoration keeps SDK identity. */
    fun setOwner(identity: String?, role: Role) = synchronized(lock) {
        val changed = owner != identity || this.role != role
        if (observedOwner && changed) runCatching { capture.reset() }
        if (changed) demo = false
        owner = identity; this.role = role; observedOwner = true
    }
    fun setDemo(enabled: Boolean) = synchronized(lock) { demo=enabled }
    fun operation(flow: Flow, method: Method? = null, form: Form? = null, push: PushOperation? = null,
                  request: Request? = null, correlation: String = UUID.randomUUID().toString(), feature: Feature? = null) =
        synchronized(lock) { Operation(this, flow, method, form, push, request, owner, role, demo, monotonic(), correlation, feature) }
    fun begin(flow: Flow, method: Method? = null, form: Form? = null, push: PushOperation? = null, request: Request? = null, feature: Feature? = null) =
        operation(flow,method,form,push,request,feature=feature).also { it.event(Stage.started) }
    internal fun rebind(op: Operation) = synchronized(lock) { Operation(this,op.flow,op.method,op.form,op.push,op.request,owner,role,demo,op.started,op.correlation,op.feature) }
    internal fun child(op: Operation, request: Request) = Operation(this,Flow.request,null,null,null,request,op.owner,op.role,op.demo,monotonic(),op.correlation)
    internal fun record(op: Operation, stage: Stage, error: SafeError, access: Access?, attempt: Int, start: Start?, previous: Role?,
                        authorization: Authorization?, preference: Boolean?, environment: Environment?, notification: NotificationType?, status: Int?) {
        // A broken metadata provider never reaches business operations.
        runCatching {
            val m = metadata()
            synchronized(lock) {
                // Only reject NEW stale captures; never edit or discard SDK queues.
                if (op.owner != owner || op.role != role) return
                val e = Event(timestamp=Instant.ofEpochMilli(wall()).toString(),
                    correlationID=op.correlation,metadata=m.copy(role=op.role,demo=op.demo),flow=op.flow,stage=stage,error=error,
                    durationMs=(monotonic()-op.started).coerceIn(0,86_400_000),attempt=attempt,feature=op.feature,method=op.method,form=op.form,
                    access=access,start=start,previousRole=previous,pushOperation=op.push,authorization=authorization,
                    preferenceEnabled=preference,apnsEnvironment=environment,notificationType=notification,request=op.request,httpStatus=status)
                if (!e.valid()) return
                capture.capture(e)
            }
        }
    }
}

class Operation internal constructor(
    private val client: TelemetryClient, internal val flow: Flow, internal val method: Method?, internal val form: Form?,
    internal val push: PushOperation?, internal val request: Request?, internal val owner: String?, internal val role: Role, internal val demo: Boolean, internal val started: Long,
    val correlation: String, internal val feature: Feature? = null,
) {
    fun rebound() = client.rebind(this)
    fun requestOperation(request: Request) = client.child(this,request)
    fun event(stage: Stage, error: SafeError=SafeError.none, access: Access?=null, attempt: Int=1,
              start: Start?=null, previous: Role?=null, authorization: Authorization?=null, preference: Boolean?=null,
              environment: Environment?=null, notification: NotificationType?=null, status: Int?=null) =
        client.record(this,stage,error,access,attempt,start,previous,authorization,preference,environment,notification,status)
}
object Telemetry {
    @Volatile var client = TelemetryClient({ Metadata() })
        private set
    fun install(client: TelemetryClient) { this.client=client }
    suspend fun <T> measure(flow: Flow, method: Method?=null, form: Form?=null, feature: Feature?=null, block: suspend (Operation) -> T): T {
        val op=client.begin(flow,method=method,form=form,feature=feature)
        try { return block(op).also { (if(flow==Flow.authentication) op.rebound() else op).event(Stage.succeeded) } }
        catch(e: CancellationException) { op.event(Stage.cancelled,error=SafeError.cancelled); throw e }
        catch(e: Exception) { op.event(Stage.failed,error=SafeError.generic); throw e }
    }
}

suspend fun <T> telemetryRequest(request: Request, parent: Operation? = null, block: suspend () -> T): T {
    val op=parent?.requestOperation(request) ?: Telemetry.client.operation(Flow.request,request=request)
    op.event(Stage.started)
    try { return block().also { op.event(Stage.succeeded) } }
    catch(e: CancellationException) { op.event(Stage.cancelled,error=SafeError.cancelled);throw e }
    catch(e: Exception) {
        val status=com.cbtipul.app.data.EdgePayload.httpStatus(e)
        op.event(Stage.failed,error=when(status) {401->SafeError.unauthorized;403->SafeError.forbidden;else->SafeError.generic},status=status)
        throw e
    }
}

object PushObservation {
    fun type(raw: String?): NotificationType = when(raw) {
        "questionnaire_assigned", "questionnaire_completed" -> NotificationType.questionnaire
        "diary_1_assigned", "diary_2_assigned", "diary_3_assigned", "diary_one_entry_added", "diary_two_entry_added", "diary_three_entry_added" -> NotificationType.diary
        "message_received" -> NotificationType.patientMessage
        null -> NotificationType.unknown
        else -> NotificationType.other
    }
    fun record(stage: Stage, type: NotificationType, correlation: String? = null) {
        val safeCorrelation=correlation?.takeIf { uuid(it) } ?: UUID.randomUUID().toString()
        Telemetry.client.operation(Flow.push,push=if(stage==Stage.opened) PushOperation.opened else PushOperation.received,correlation=safeCorrelation).event(stage,notification=type)
    }
}

/** Process-local launch classifier; activity restoration is deliberately unknown. */
class ActivityStartTracker {
    private val seen = java.util.concurrent.atomic.AtomicBoolean(false)
    fun start(recreated: Boolean): Start {
        if (recreated) { seen.set(true); return Start.unknown }
        return if (seen.compareAndSet(false,true)) Start.cold else Start.warm
    }
}
