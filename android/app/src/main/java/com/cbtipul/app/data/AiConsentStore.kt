package com.cbtipul.app.data

import com.cbtipul.app.model.ConsentDeclinedException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import java.time.Instant
import java.util.UUID

@Serializable data class AiConsentReceipt(
    val therapist_id: String, val consent_type: String, val required_version: String,
    val accepted_version: String?, val accepted_at: String?, val revoked_at: String?,
    val status: String, val revision: Long,
) {
    fun validate(account: String) {
        fun date(value: String?) = value != null && runCatching { Instant.parse(value) }.isSuccess
        require(therapist_id.equals(account,true) && consent_type == "ai_data_sharing" && required_version == "2026-11-22")
        require(revision in 0..9007199254740991L && status in listOf("required","accepted","declined","revoked"))
        require((accepted_at == null || date(accepted_at)) && (revoked_at == null || date(revoked_at)))
        require(status != "accepted" || (accepted_version == required_version && date(accepted_at) && revoked_at == null))
        require(status != "revoked" || date(revoked_at))
    }
}

/** Uses server receipts exclusively; never imports device-only acceptance flags. */
class AiConsentStore(
    private val call: suspend (String, JsonObject) -> String,
    private val currentAccount: (() -> String?)? = null,
    private val eligible: () -> Boolean = { Entitlements.state.value.role == AppRole.Therapist },
) {
    private val mutex = Mutex()
    private var account: String? = null
    private var epoch = 0
    private var waiter: CompletableDeferred<Boolean>? = null
    private var pending: JsonObject? = null
    private var programmingFailure = false
    private var receipt: AiConsentReceipt? = null
    private var bypassForDemo = false
    private val json = Json { ignoreUnknownKeys = true }
    private val _promptVisible = MutableStateFlow(false)
    val promptVisible = _promptVisible.asStateFlow()
    val busy = MutableStateFlow(false)
    val failed = MutableStateFlow(false)
    val accepted = MutableStateFlow(false)

    fun setActiveUser(id: String?) {
        if(account == id) return
        account = id; epoch++; programmingFailure=false; pending = null; receipt = null
        accepted.value = false; failed.value = false; busy.value = false
        finish(false)
    }
    private fun check(owner: String, generation: Int) {
        if(account != owner || epoch != generation || (currentAccount != null && currentAccount.invoke() != owner) || !eligible()) throw ConsentDeclinedException()
    }
    private suspend fun request(method: String, args: JsonObject, owner: String, generation: Int): AiConsentReceipt {
        check(owner,generation)
        val body = call(method,args)
        check(owner,generation)
        val value = json.decodeFromString<AiConsentReceipt>(body).also { it.validate(owner) }
        receipt?.let { require(value.revision >= it.revision && (value.revision != it.revision || value.status == it.status)) }
        receipt = value; accepted.value = value.status == "accepted"
        return value
    }
    private suspend fun lookup(owner: String, generation: Int) = request("get_my_consent", buildJsonObject {
        put("p_consent_type","ai_data_sharing"); put("p_required_version","2026-11-22")
    },owner,generation)
    suspend fun ensureGranted() {
        if(bypassForDemo) return
        val owner = account ?: throw ConsentDeclinedException()
        val generation = epoch
        check(owner,generation)
        val deferred = mutex.withLock {
            waiter?.let { return@withLock it }
            try {
                if(pending == null && lookup(owner,generation).status == "accepted") return@withLock null
            } catch(error: Exception) {
                currentCoroutineContext().ensureActive(); check(owner,generation)
                accepted.value = false; failed.value = true
            }
            CompletableDeferred<Boolean>().also { waiter=it; _promptVisible.value=true }
        }
        try {
            if(deferred != null && !deferred.await()) throw ConsentDeclinedException()
        } catch (cancelled: kotlinx.coroutines.CancellationException) {
            if(waiter === deferred) finish(false)
            throw cancelled
        }
        currentCoroutineContext().ensureActive(); check(owner,generation)
    }
    fun setDemoBypass(enabled: Boolean) { bypassForDemo=enabled; if(enabled)finish(false) }
    suspend fun accept() {
        if(busy.value || programmingFailure) return
        val owner=account ?: return
        val generation=epoch
        busy.value=true; failed.value=false
        try {
            check(owner,generation)
            if(pending==null) {
                val current=lookup(owner,generation)
                pending=buildJsonObject {
                    put("p_consent_type","ai_data_sharing");put("p_required_version","2026-11-22")
                    put("p_decision","accepted");put("p_request_id",UUID.randomUUID().toString());put("p_expected_revision",current.revision)
                }
            }
            val args=pending ?: return
            val result=request("record_my_consent",args,owner,generation)
            require(result.status=="accepted" && result.revision>=args.getValue("p_expected_revision").jsonPrimitive.long)
            pending=null; finish(true)
        } catch(error: Exception) {
            if(account!=owner || epoch!=generation)return
            val code=(error as? NameSyncFailure)?.code
            if(code == "consent_request_id_reused") programmingFailure=true
            if(code in listOf("consent_revision_conflict","consent_request_superseded","consent_request_id_reused")) {
                pending=null; receipt=null
                runCatching { lookup(owner,generation) }
            }
            accepted.value=false; failed.value=true
        } finally { if(epoch==generation)busy.value=false }
    }
    fun cancelPending() { epoch++; busy.value=false; finish(false) }
    suspend fun decline() { if(!busy.value)finish(false) }
    private fun finish(granted: Boolean) {
        val current=waiter;waiter=null;_promptVisible.value=false;current?.complete(granted)
    }
}
