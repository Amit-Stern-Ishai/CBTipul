package com.cbtipul.app.data

enum class PatientMilestone { SecondSession, DiaryOne, DiaryTwo;
    val assignment: PatientAssignmentType get() = when (this) {
        SecondSession -> PatientAssignmentType.Questionnaire
        DiaryOne -> PatientAssignmentType.DiaryOne
        DiaryTwo -> PatientAssignmentType.DiaryTwo
    }
}
data class PatientMilestoneRequest(val patient: String, val milestone: PatientMilestone, val standalone: Boolean,
    val id: String = java.util.UUID.randomUUID().toString())

object DiscoveryRules {
    fun patientFeature(patient: String, feature: String) = "patient.${patient.lowercase(java.util.Locale.ROOT)}.$feature"
    fun sessionMilestones(type: com.cbtipul.app.model.SessionType?, matchingCount: Int, total: Int): List<PatientMilestone> = buildList {
        if (matchingCount == 1 && type == com.cbtipul.app.model.SessionType.DiaryOne) add(PatientMilestone.DiaryOne)
        if (matchingCount == 1 && type == com.cbtipul.app.model.SessionType.DiaryTwo) add(PatientMilestone.DiaryTwo)
        if (total == 2) add(PatientMilestone.SecondSession)
    }
    // A failed lookup throws: retain the intent. null is confirmed ineligibility.
    suspend fun resolve(intent: DiscoveryIntent, firstEntry: suspend () -> Boolean, sessionExists: () -> Boolean,
        connected: suspend () -> Boolean, enabled: suspend (PatientMilestone) -> Boolean): Boolean? {
        if (intent.feature == "web") return false
        if (intent.standalone && !intent.reminder && !firstEntry()) return null
        if (intent.session != null && !sessionExists()) return null
        val linked = connected()
        if (intent.feature == "invite") return if (linked) null else true
        val kind = PatientMilestone.entries.firstOrNull { it.name == intent.feature } ?: return null
        return suggestion(linked, if (linked) enabled(kind) else false)
    }
    // true = invite, false = activity settings, null = no authoritative suggestion.
    fun suggestion(connected: Boolean?, enabled: Boolean?): Boolean? = when {
        connected == null -> null
        !connected -> true
        enabled == false -> false
        else -> null
    }

    fun key(account: String, feature: String) = "discovery.$feature.${account.lowercase(java.util.Locale.ROOT)}"
    fun voice(userEdit: Boolean, nonempty: Boolean, therapist: Boolean, demo: Boolean, seen: Boolean) = userEdit && nonempty && therapist && !demo && !seen
    fun present(pending: Boolean, busy: Boolean, feedback: Boolean, obstructed: Boolean, valid: Boolean) = pending && !busy && !feedback && !obstructed && valid
}

/** No content or addresses: only owner, prompt type, and navigation/trigger IDs. */
@kotlinx.serialization.Serializable
data class DiscoveryIntent(val account: String, val feature: String, val patient: String,
    val standalone: Boolean = false, val session: String? = null, val id: String = java.util.UUID.randomUUID().toString(),
    val reminder: Boolean = false, val context: String? = null)

/** Stored in Context.noBackupFilesDir: not carried to another device. */
class DiscoveryLedger(private val file: java.io.File, private val now: () -> Long = System::currentTimeMillis) {
    @kotlinx.serialization.Serializable
    private data class Display(val initial: Long, val reminderShown: Boolean = false, val suppressed: Boolean = false)
    @kotlinx.serialization.Serializable
    private data class State(val shown: Set<String> = emptySet(), val pending: List<DiscoveryIntent> = emptyList(),
        val displays: Map<String, Display> = emptyMap(), val voiceUsed: Set<String> = emptySet())
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }
    private var state = try { json.decodeFromString(State.serializer(), file.readText()) } catch (_: Exception) { State() }
    private val mutable = kotlinx.coroutines.flow.MutableStateFlow(state.pending)
    val pending: kotlinx.coroutines.flow.StateFlow<List<DiscoveryIntent>> = mutable
    private val opportunity = kotlinx.coroutines.flow.MutableStateFlow(0L)
    val opportunities: kotlinx.coroutines.flow.StateFlow<Long> = opportunity
    var activeContext: String? = null; private set
    init {
        state = state.copy(displays = state.shown.associateWith { state.displays[it] ?: Display(now()) } + state.displays,
            pending = state.pending.filterNot { it.reminder })
        if (state.shown.isNotEmpty()) persist()
    }
    @Synchronized fun enterContext(context: String?) {
        if (activeContext == context) return
        activeContext = context
        state = state.copy(pending = state.pending.filterNot { it.reminder && it.context != context }); persist()
    }
    @Synchronized fun returnAfterSave(context: String?) {
        if (context.isNullOrEmpty()) return
        state = state.copy(pending = state.pending.map { if (it.reminder && it.context == activeContext) it.copy(context = context) else it })
        activeContext = context; persist()
    }
    @Synchronized fun eligible(account: String, feature: String): Boolean {
        val display = state.displays[DiscoveryRules.key(account, canonical(feature))] ?: return true
        return !display.reminderShown && !display.suppressed && !(feature == "voice" && account.lowercase(java.util.Locale.ROOT) in state.voiceUsed) &&
            now() - display.initial >= (if (feature == "invite") 3L else 7L) * 86_400_000L
    }
    @Synchronized fun valid(intent: DiscoveryIntent) = state.pending.any { it.id == intent.id } && if (intent.reminder) intent.context == activeContext && eligible(intent.account, intent.feature) else !seen(intent.account, intent.feature)
    @Synchronized fun suppress(account: String, feature: String) {
        val key = DiscoveryRules.key(account, feature)
        state = state.copy(displays = state.displays + (key to (state.displays[key] ?: Display(now())).copy(suppressed = true)),
            pending = state.pending.filterNot { it.account.equals(account, true) && it.feature == feature }); persist()
    }
    @Synchronized fun usedVoice(account: String) {
        state = state.copy(voiceUsed = state.voiceUsed + account.lowercase(java.util.Locale.ROOT),
            pending = state.pending.filterNot { it.account.equals(account, true) && it.feature == "voice" && it.reminder }); persist()
    }
    @Synchronized fun presented(intent: DiscoveryIntent) {
        if (state.pending.none { it.id == intent.id } || !valid(intent)) return
        if (!intent.reminder) { mark(intent.account, intent.feature); return }
        val key = DiscoveryRules.key(intent.account, intent.feature)
        state = state.copy(displays = state.displays + (key to state.displays.getValue(key).copy(reminderShown = true)),
            pending = state.pending.filterNot { it.account == intent.account && it.feature == intent.feature }); persist()
    }
    @Synchronized fun presentedVoice(account: String, patient: String?) {
        state.pending.firstOrNull { it.account.equals(account, true) && it.patient == patient && it.feature == "voice" }?.let(::presented)
    }
    private fun canonical(feature: String) = feature.substringAfterLast('.')
    @Synchronized fun seen(account: String, feature: String) = DiscoveryRules.key(account, canonical(feature)) in state.shown
    @Synchronized fun mark(account: String, feature: String): Boolean {
        val key = DiscoveryRules.key(account, canonical(feature))
        state = state.copy(shown = state.shown + key, displays = state.displays + (key to (state.displays[key] ?: Display(now()))),
            pending = state.pending.filterNot { it.account.equals(account, true) && it.feature == canonical(feature) })
        return persist()
    }
    @Synchronized fun enqueue(account: String, feature: String, patient: String, standalone: Boolean = false, session: String? = null, reminderOnly: Boolean = false, initialOnly: Boolean = false) {
        opportunity.value += 1
        if (!eligible(account, feature) || (reminderOnly && !seen(account, feature)) || (initialOnly && seen(account, feature)) || state.pending.any { it.account.equals(account, true) && it.feature == feature && it.patient == patient && it.standalone == standalone }) return
        val reminder = seen(account, feature)
        if (reminder && activeContext.isNullOrEmpty()) return
        state = state.copy(pending = state.pending + DiscoveryIntent(account.lowercase(java.util.Locale.ROOT), feature, patient, standalone, session, reminder = reminder, context = if (reminder) activeContext else null)); persist()
    }
    @Synchronized fun remove(intent: DiscoveryIntent) { state = state.copy(pending = state.pending.filterNot { it.id == intent.id }); persist() }
    private fun persist(): Boolean {
        val saved = try {
            file.parentFile?.mkdirs()
            val tmp = java.io.File(file.path + ".tmp")
            tmp.writeText(json.encodeToString(State.serializer(), state))
            java.nio.file.Files.move(tmp.toPath(), file.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING, java.nio.file.StandardCopyOption.ATOMIC_MOVE)
            true
        } catch (_: java.io.IOException) { false }
        mutable.value = state.pending
        return saved
    }
}
