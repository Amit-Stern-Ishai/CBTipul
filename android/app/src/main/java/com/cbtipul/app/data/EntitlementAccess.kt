package com.cbtipul.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement

@Serializable enum class EntitlementAccess {
    @SerialName("full") Full,
    @SerialName("read_only") ReadOnly,
}
@Serializable data class AppEntitlement(val access: EntitlementAccess) {
    val canWrite get() = access == EntitlementAccess.Full
    val canUseAI get() = canWrite
    val canPatientWrite get() = canWrite
}
/** Invalid entitlement does not make existing patient history unroutable. */
object LenientEntitlementSerializer : KSerializer<AppEntitlement?> {
    override val descriptor: SerialDescriptor = AppEntitlement.serializer().descriptor
    override fun deserialize(decoder: Decoder): AppEntitlement? {
        val input = decoder as JsonDecoder
        val element = input.decodeJsonElement()
        return runCatching { input.json.decodeFromJsonElement<AppEntitlement>(element) }.getOrNull()
    }
    override fun serialize(encoder: Encoder, value: AppEntitlement?) {
        val output = encoder as JsonEncoder
        output.encodeJsonElement(value?.let { output.json.encodeToJsonElement(it) } ?: JsonNull)
    }
}
data class EntitlementSnapshot(val identity: String? = null, val role: AppRole? = null, val access: EntitlementAccess? = null, val localDemo: Boolean = false) {
    val canWrite get() = access == EntitlementAccess.Full || localDemo
    val canUseAI get() = access == EntitlementAccess.Full
    val canPatientWrite get() = access == EntitlementAccess.Full
}
class EntitlementDenied(message: String) : IllegalStateException(message)

object Entitlements {
    private val mutable = MutableStateFlow(EntitlementSnapshot())
    val state = mutable.asStateFlow()
    private val blocked = MutableStateFlow(false)
    val explanationVisible = blocked.asStateFlow()
    var explanation: (Boolean) -> String = { "read_only" }
    val canWrite get() = mutable.value.canWrite
    val canUseAI get() = mutable.value.canUseAI
    val canPatientWrite get() = mutable.value.canPatientWrite
    fun setIdentity(identity: String?) {
        if (identity != mutable.value.identity) { PatientHomeCache.clear(); mutable.value = EntitlementSnapshot(identity); blocked.value = false }
    }
    fun apply(context: AppContext) {
        mutable.value = mutable.value.copy(role = context.role,
            access = if (context.isIncompletePatient) null else context.entitlement?.access)
    }
    fun invalidate() { mutable.value = mutable.value.copy(access = null) }
    fun clear() { PatientHomeCache.clear(); mutable.value = EntitlementSnapshot(); blocked.value = false }
    fun dismissExplanation() { blocked.value = false }
    fun allowMutation(allowLocalDemo: Boolean = true): Boolean {
        if (mutable.value.access == EntitlementAccess.Full || (allowLocalDemo && mutable.value.localDemo)) return true
        blocked.value = true
        return false
    }
    fun setLocalDemo(active: Boolean) { mutable.value = mutable.value.copy(localDemo = active); blocked.value = false }
    fun requireWrite(localDemo: Boolean = false) {
        if (mutable.value.access != EntitlementAccess.Full && !(mutable.value.localDemo && localDemo)) {
            blocked.value = true
            throw EntitlementDenied(explanation(mutable.value.role == AppRole.Patient))
        }
    }
}
