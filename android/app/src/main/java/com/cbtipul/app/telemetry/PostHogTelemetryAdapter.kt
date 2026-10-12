package com.cbtipul.app.telemetry

import java.util.UUID

data class PostHogSettings(val token:String,val host:String,val enabled:Boolean) {
    val valid get()=PostHogTelemetryConfiguration.valid(token,host)
    companion object {val production=PostHogSettings(PostHogTelemetryConfiguration.PROJECT_TOKEN,PostHogTelemetryConfiguration.HOST,PostHogTelemetryConfiguration.ENABLED)}
}
data class PostHogManualEvent internal constructor(val name:String,val timestamp:String,val properties:Map<String,Any>)
object PostHogEventMapper {
    fun name(e:Event):String {
        val stage=when(e.stage) {Stage.previewShown->"preview_shown";Stage.roleSwitchConfirmed->"role_switch_confirmed";Stage.shareSheetOpened->"share_sheet_opened";Stage.sharingReported->"sharing_reported";else->e.stage.name}
        return "cbtipul_${e.flow.name}_$stage"
    }
    fun map(e:Event):PostHogManualEvent? {
        if(!e.valid()) return null
        val m=e.metadata
        val p=linkedMapOf<String,Any>("schema_version" to e.schemaVersion,"correlation_id" to e.correlationID,
            "platform" to m.platform,"device_model" to m.deviceModel,"manufacturer" to m.manufacturer,
            "os_version" to m.osVersion,"app_version" to m.appVersion,"app_build" to m.build,"build_channel" to m.buildChannel,
            "distribution" to m.distribution,"role" to m.role.name,"demo" to m.demo,"network" to m.network.name,"lifecycle" to m.lifecycle.name,
            "locale" to m.locale,"timezone" to m.timezone,"flow" to e.flow.name,"stage" to e.stage.name,"outcome" to e.outcome.name,
            "safe_error_code" to e.error.name,"duration_ms" to e.durationMs,"attempt" to e.attempt,"retry_count" to e.retryCount,
            "\$process_person_profile" to false,"\$geoip_disable" to true)
        fun optional(key:String,value:Any?){if(value!=null)p[key]=value}
        optional("api_level",m.apiLevel);optional("method",e.method?.name);optional("form",e.form?.name);optional("access",e.access?.name)
        optional("start",e.start?.name);optional("previous_role",e.previousRole?.name);optional("push_operation",e.pushOperation?.name)
        optional("authorization",e.authorization?.name);optional("preference_enabled",e.preferenceEnabled);optional("apns_environment",e.apnsEnvironment?.name)
        optional("notification_type",e.notificationType?.name);optional("logical_operation",e.request?.name);optional("http_status",e.httpStatus);optional("feature",e.feature?.name)
        return PostHogManualEvent(name(e),e.timestamp,p.toMap())
    }
}
/** Stateless beforeSend filter; no event registry, identity overrides, or delivery controls. */
object PostHogPrivacyGuard {
    private val customKeys = setOf("schema_version","correlation_id","platform","device_model","manufacturer","api_level","os_version","app_version","app_build","build_channel","distribution","role","demo","network","lifecycle","locale","timezone","flow","stage","outcome","safe_error_code","duration_ms","attempt","retry_count","feature","method","form","access","start","previous_role","push_operation","authorization","preference_enabled","apns_environment","notification_type","logical_operation","http_status")
    private val sdkKeys = setOf("\$lib", "\$lib_version", "\$session_id", "\$device_id", "\$is_identified")
    fun filter(name:String, properties:Map<String,Any>?):MutableMap<String,Any>? {
        val p=properties ?: return null
        val flow=(p["flow"] as? String)?.let {raw -> Flow.entries.find {it.name==raw}} ?: return null
        val stage=(p["stage"] as? String)?.let {raw -> Stage.entries.find {it.name==raw}} ?: return null
        val suffix=when(stage) {Stage.previewShown->"preview_shown";Stage.roleSwitchConfirmed->"role_switch_confirmed";Stage.shareSheetOpened->"share_sheet_opened";Stage.sharingReported->"sharing_reported";else->stage.name}
        if(name!="cbtipul_${flow.name}_$suffix") return null
        return p.filter { (key,value) ->
            if(key !in customKeys && key !in sdkKeys) false
            else if(enums.containsKey(key)) value is String && value in enums.getValue(key)
            else if(key in setOf("correlation_id", "\$session_id", "\$device_id")) value is String && runCatching {UUID.fromString(value).toString()==value.lowercase()}.getOrDefault(false)
            else if(key in setOf("demo", "preference_enabled", "\$is_identified")) value is Boolean
            else when(value) {is Number -> value.toDouble().isFinite() && value.toDouble() in 0.0..86_400_000.0;is String -> value.length in 1..128 && value.matches(Regex("[A-Za-z0-9 _./:()+-]+"));else -> false}
        }.toMutableMap().apply {put("\$process_person_profile",false);put("\$geoip_disable",true)}
    }
    private val enums = mapOf("platform" to setOf("ios","android"),
"build_channel" to setOf("debug","release"),
"distribution" to setOf("unknown"),
"flow" to Flow.entries.map {it.name}.toSet(),
"stage" to Stage.entries.map {it.name}.toSet(),
"outcome" to Outcome.entries.map {it.name}.toSet(),
"feature" to Feature.entries.map {it.name}.toSet(),
"role" to Role.entries.map {it.name}.toSet(),
"previous_role" to Role.entries.map {it.name}.toSet(),
"network" to Network.entries.map {it.name}.toSet(),
"lifecycle" to Lifecycle.entries.map {it.name}.toSet(),
"safe_error_code" to SafeError.entries.map {it.name}.toSet(),
"method" to Method.entries.map {it.name}.toSet(),
"form" to Form.entries.map {it.name}.toSet(),
"access" to Access.entries.map {it.name}.toSet(),
"start" to Start.entries.map {it.name}.toSet(),
"push_operation" to PushOperation.entries.map {it.name}.toSet(),
"authorization" to Authorization.entries.map {it.name}.toSet(),
"apns_environment" to Environment.entries.map {it.name}.toSet(),
"notification_type" to NotificationType.entries.map {it.name}.toSet(),
"logical_operation" to Request.entries.map {it.name}.toSet(),
"\$lib" to setOf("posthog-ios","posthog-android"))
}
