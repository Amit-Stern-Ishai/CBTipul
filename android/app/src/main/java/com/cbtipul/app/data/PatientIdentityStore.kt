package com.cbtipul.app.data

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.cbtipul.app.model.DatabaseId

class PatientIdentityStore(context: Context) {

    private val prefs = EncryptedSharedPreferences.create(
        context,
        SERVICE,
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    fun save(patientId: DatabaseId, name: String) {
        prefs.edit().putString(patientId.queryValue, name).apply()
    }

    fun name(patientId: DatabaseId): String? = prefs.getString(patientId.queryValue, null)

    fun delete(patientId: DatabaseId) {
        prefs.edit().remove(patientId.queryValue).apply()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
    }

    fun upsertIdentities(backendNames: Map<DatabaseId, String>) {
        backendNames.forEach { (id, name) ->
            if (name.isEmpty()) return@forEach
            if (this.name(id) == name) return@forEach
            runCatching { save(id, name) }
                .onFailure { Log.e(TAG, "Saving patient name failed", it) }
        }
    }

    companion object {
        private const val SERVICE = "CBTipul.patient-names"
        private const val TAG = "PatientIdentityStore"
    }
}
