package com.cbtipul.app.auth

import java.security.MessageDigest
import java.security.SecureRandom
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/** In-memory, single-use attempt; never serialize or log credentials/nonces. */
internal class GoogleNonce {
    val raw: String = ByteArray(32).also { SecureRandom().nextBytes(it) }.hex()
    val hashed: String = MessageDigest.getInstance("SHA-256")
        .digest(raw.toByteArray(Charsets.UTF_8)).hex()
}

private fun ByteArray.hex() = joinToString("") { "%02x".format(it.toInt() and 0xff) }

/** Main-thread owned. Network and platform operations are injected for offline tests. */
internal class GoogleSignInFlow {
    private var generation = 0L
    private var active: Long? = null

    fun invalidate() {
        generation++
        active = null
    }

    suspend fun <T> run(
        hasSession: () -> Boolean,
        credential: suspend (hashedNonce: String) -> String,
        exchange: suspend (token: String, rawNonce: String) -> T,
        commit: suspend (T) -> Unit,
    ) {
        if (active != null || hasSession()) throw CancellationException()
        val attempt = ++generation
        active = attempt
        suspend fun checkCurrent() {
            currentCoroutineContext().ensureActive()
            if (generation != attempt || hasSession()) throw CancellationException()
        }
        try {
            val nonce = GoogleNonce()
            val token = credential(nonce.hashed)
            checkCurrent()
            require(token.isNotBlank())
            val session = exchange(token, nonce.raw)
            checkCurrent()
            commit(session)
        } finally {
            if (active == attempt) active = null
        }
    }
}
