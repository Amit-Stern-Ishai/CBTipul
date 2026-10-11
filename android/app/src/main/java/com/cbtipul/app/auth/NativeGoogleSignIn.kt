package com.cbtipul.app.auth

import android.content.Context
import android.content.MutableContextWrapper
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CancellationException

object NativeGoogleSignIn {
    // Public OAuth Web client ID; never use an Android client ID here.
    private const val SERVER_CLIENT_ID =
        "378231528435-5rftt3sjnsvi3kc6sh6pndua096nt5u7.apps.googleusercontent.com"

    suspend fun token(context: Context, hashedNonce: String): String {
        val option = GetSignInWithGoogleOption.Builder(SERVER_CLIENT_ID)
            .setNonce(hashedNonce)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val credential = try {
            CredentialManager.create(context).getCredential(MutableContextWrapper(context), request).credential
        } catch (_: GetCredentialCancellationException) {
            throw CancellationException()
        }
        require(credential is CustomCredential &&
            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL)
        return GoogleIdTokenCredential.createFrom(credential.data).idToken
    }

    suspend fun clearState(context: Context) {
        CredentialManager.create(context).clearCredentialState(ClearCredentialStateRequest())
    }
}
