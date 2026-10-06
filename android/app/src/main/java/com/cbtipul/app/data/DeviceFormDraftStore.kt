package com.cbtipul.app.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.MessageDigest

interface DeviceDraftStorage {
    fun read(key: String): String?
    fun write(key: String, value: String)
    fun clear(key: String)
}

/** Real drafts are encrypted on-device; demo drafts live only in memory for this visit. */
class DeviceFormDraftStore(context: Context) : DeviceDraftStorage {
    private val preferences by lazy {
        EncryptedSharedPreferences.create(
            context, "CBTipul.form-drafts",
            MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private val demoDrafts = mutableMapOf<String, String>()
    fun resetDemo(account: String?, patients: List<com.cbtipul.app.model.Patient>) {
        demoDrafts.clear()
        demoGeneration = java.util.UUID.randomUUID().toString()
        if (account == null) return
        val targets = listOf("_:new") + patients.flatMap { patient ->
            listOf("${patient.id.queryValue}:new") + patient.sessions.map { "${patient.id.queryValue}:${it.id}" }
        }
        val editor = preferences.edit()
        targets.forEach { editor.remove(legacyKey(account, "demo-session", it)) }
        editor.apply()
    }
    override fun read(key: String): String? =
        if (key.startsWith("demo:")) demoDrafts[key] else preferences.getString(key, null)
    override fun write(key: String, value: String) {
        if (key.startsWith("demo:")) {
            if (key.startsWith("demo:$demoGeneration:")) demoDrafts[key] = value
            return
        }
        check(preferences.edit().putString(key, value).commit()) { "Draft could not be saved" }
    }
    override fun clear(key: String) {
        if (key.startsWith("demo:")) { demoDrafts.remove(key); return }
        check(preferences.edit().remove(key).commit()) { "Draft could not be removed" }
    }

    companion object {
        private var demoGeneration = java.util.UUID.randomUUID().toString()
        fun key(account: String, kind: String, target: String): String {
            val hash = legacyKey(account, kind, target)
            return if (kind == "demo-session") "demo:$demoGeneration:$hash" else hash
        }
        private fun legacyKey(account: String, kind: String, target: String): String {
            require(account.isNotBlank() && target.isNotBlank())
            val parts = listOf(account, kind, target).joinToString("") { "${it.length}:$it" }
            return MessageDigest.getInstance("SHA-256").digest(parts.toByteArray()).joinToString("") { "%02x".format(it) }
        }
    }
}
