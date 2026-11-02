package com.cbtipul.app.ui.patients

import com.cbtipul.app.data.SummaryAllowance
import com.cbtipul.app.data.SummaryFailure

/** Shared production/test pipeline: completed transcript and anonymization are durable checkpoints. */
suspend fun processSummaryVoice(
    draft: SessionEditorDraft,
    allowance: suspend () -> SummaryAllowance,
    transcribe: suspend () -> String,
    anonymize: suspend (String) -> String,
    onNotes: (String) -> Unit,
    isCurrentAccount: () -> Boolean,
    onAnonymizing: () -> Unit = {},
) {
    fun preserve() {
        if (!isCurrentAccount()) throw SummaryFailure(SummaryFailure.Kind.Login)
        if (!draft.persistRecovery()) throw SummaryFailure(SummaryFailure.Kind.Local)
    }
    preserve()
    allowance().assess(needsTokens=draft.prepared==null, seconds=if(draft.transcriptReady) null else draft.audioSeconds)
    if (!draft.transcriptReady) {
        val transcript=transcribe()
        if (!isCurrentAccount()) throw SummaryFailure(SummaryFailure.Kind.Login)
        val combined=if(draft.notes.isBlank()) transcript else draft.notes+"\n\n"+transcript
        draft.notes=combined
        draft.transcriptReady=true
        preserve()
        onNotes(combined)
    }
    onAnonymizing()
    allowance().assess(needsTokens=draft.prepared==null)
    if (draft.prepared==null) {
        val source=draft.notes
        val safe=anonymize(source)
        if (!isCurrentAccount()) throw SummaryFailure(SummaryFailure.Kind.Login)
        if (safe.isBlank() && source.isNotBlank()) throw SummaryFailure(SummaryFailure.Kind.Service)
        draft.preparedSource=source;draft.preparedText=safe
        preserve()
    }
}
