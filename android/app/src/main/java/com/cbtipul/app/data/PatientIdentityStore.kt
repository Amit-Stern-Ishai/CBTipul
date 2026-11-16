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

    var resolvedName: ((DatabaseId) -> String?)? = null
    fun legacyName(patientId: DatabaseId): String? = prefs.getString(patientId.queryValue, null)
    fun name(patientId: DatabaseId): String? = resolvedName?.invoke(patientId)

    // Migration calls this only after an authoritative server acknowledgement.
    fun removeConfirmedLegacy(patientId: String): Boolean = prefs.edit().remove(patientId).commit()

    fun delete(patientId: DatabaseId) {
        prefs.edit().remove(patientId.queryValue).apply()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val SERVICE = "CBTipul.patient-names"
        private const val TAG = "PatientIdentityStore"
    }
}
