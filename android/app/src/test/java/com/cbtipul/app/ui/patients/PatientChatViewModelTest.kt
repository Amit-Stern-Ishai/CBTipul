package com.cbtipul.app.ui.patients

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import org.junit.Assert.*
import org.junit.Test

class PatientChatViewModelTest {
    @Test fun tabReentryKeepsDraftConversationAndBackgroundReply() {
        val store = ViewModelStore()
        val factory = object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return PatientChatViewModel() as T
            }
        }
        val first = ViewModelProvider(store, factory)["chat-patient", PatientChatViewModel::class.java]
        first.entries = listOf(ChatEntry(role = "user", text = "question"))
        first.prompt = "next question"
        first.isLoading = true
        // Screen composition disappears; the request completes against its retained owner.
        first.entries = first.entries + ChatEntry(role = "assistant", text = "answer")
        first.isLoading = false
        val reopened = ViewModelProvider(store, factory)["chat-patient", PatientChatViewModel::class.java]
        assertSame(first, reopened)
        assertEquals(listOf("question", "answer"), reopened.entries.map { it.text })
        assertEquals("next question", reopened.prompt)
        assertFalse(reopened.isLoading)
        val otherPatient = ViewModelProvider(store, factory)["chat-other", PatientChatViewModel::class.java]
        assertTrue(otherPatient.entries.isEmpty())
        assertEquals("", otherPatient.prompt)
    }
}
