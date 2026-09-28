package com.cbtipul.app.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.MessageDigest

/** Drafts stay on this device, encrypted and isolated by account and form target. */
class DeviceFormDraftStore(context: Context) {
    private val preferences by lazy {
        EncryptedSharedPreferences.create(
            context, "CBTipul.form-drafts",
            MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun read(key: String): String? = preferences.getString(key, null)
    fun write(key: String, value: String) {
        check(preferences.edit().putString(key, value).commit()) { "Draft could not be saved" }
    }
    fun clear(key: String) {
        check(preferences.edit().remove(key).commit()) { "Draft could not be removed" }
    }

    companion object {
        fun key(account: String, kind: String, target: String): String {
            require(account.isNotBlank() && target.isNotBlank())
            val parts = listOf(account, kind, target).joinToString("") { "${it.length}:$it" }
            return MessageDigest.getInstance("SHA-256").digest(parts.toByteArray()).joinToString("") { "%02x".format(it) }
        }
    }
}
