package com.cbtipul.app.data

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Never retries a mutation automatically. Unknown outcomes require a fresh status read. */
class PatientActivitiesRequest {
    enum class State { Loading, Ready, Sending, Pending, Available, Failed }
    private val mutable = MutableStateFlow(State.Loading)
    val state = mutable.asStateFlow()
    private val uncertainty = MutableStateFlow(false)
    val uncertain = uncertainty.asStateFlow()
    private var busy = false
    suspend fun run(send: Boolean, current: () -> Boolean, rpc: suspend (Boolean) -> String) {
        if (busy || !current() || (send && mutable.value != State.Ready)) return
        busy = true
        mutable.value = if (send) State.Sending else State.Loading
        try {
            val result = rpc(send)
            if (!current()) return
            apply(result)
            uncertainty.value = false
        } catch (cancelled: CancellationException) { throw cancelled
        } catch (_: Exception) {
            if (!current()) return
            uncertainty.value = send || uncertainty.value
            if (send) {
                try {
                    val result = rpc(false)
                    if (!current()) return
                    apply(result)
                    if (mutable.value == State.Pending || mutable.value == State.Available) uncertainty.value = false
                } catch (cancelled: CancellationException) { throw cancelled
                } catch (_: Exception) { if (current()) mutable.value = State.Failed }
            } else mutable.value = State.Failed
        } finally { busy = false }
    }
    private fun apply(value: String) {
        mutable.value = when (value) {
            "no_request" -> State.Ready
            "pending" -> State.Pending
            "activities_available" -> State.Available
            else -> error("Unknown activities request status")
        }
    }
}
