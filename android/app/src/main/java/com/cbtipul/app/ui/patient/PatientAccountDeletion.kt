package com.cbtipul.app.ui.patient

import androidx.compose.runtime.*
import com.cbtipul.app.data.EdgePayload
import kotlinx.coroutines.CancellationException

class PatientAccountDeletion(
    private val identity: () -> String?,
    private val request: suspend () -> Unit,
    private val checkSession: suspend () -> Unit,
    private val cleanup: suspend () -> Unit,
    private val statusCode: (Throwable) -> Int? = EdgePayload::httpStatus,
) {
    enum class State { Idle, Confirming, Deleting, Rejected, Uncertain, Checking, Retryable, SessionUnverified, CleanupFailed, Deleted }
    var state by mutableStateOf(State.Idle); private set
    private val owner = identity()
    private var generation = 0
    val busy get() = state == State.Deleting || state == State.Checking
    private fun current(epoch: Int) = epoch == generation && owner != null && identity() == owner
    fun ask() { if (state in listOf(State.Idle, State.Rejected, State.Retryable)) state = State.Confirming }
    fun cancel() { if (state == State.Confirming) state = State.Idle }
    fun invalidate() { generation++; state = State.Idle }
    suspend fun confirm() {
        if (state != State.Confirming || !current(generation)) return
        val epoch = generation
        state = State.Deleting
        try { request() } catch (error: Exception) {
            if (error is CancellationException) throw error
            if (current(epoch)) state = when (statusCode(error)) {
                401 -> State.SessionUnverified
                in 400..499 -> State.Rejected
                else -> State.Uncertain
            }
            return
        }
        if (current(epoch)) finish(epoch)
    }
    private suspend fun finish(epoch: Int) {
        try { cleanup(); if (epoch == generation) state = State.Deleted }
        catch (error: Exception) { if (error is CancellationException) throw error; if (current(epoch)) state = State.CleanupFailed }
    }
    suspend fun retryCleanup() { if (state == State.CleanupFailed && current(generation)) { state = State.Deleting; finish(generation) } }
    suspend fun recheck() {
        if (state !in listOf(State.Uncertain, State.SessionUnverified) || !current(generation)) return
        val epoch = generation; state = State.Checking
        try { checkSession(); if (current(epoch)) state = State.Retryable }
        catch (error: Exception) { if (error is CancellationException) throw error; if (current(epoch)) state = State.SessionUnverified }
    }
}
