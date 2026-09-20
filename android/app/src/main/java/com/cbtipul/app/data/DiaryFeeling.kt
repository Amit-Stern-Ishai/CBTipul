package com.cbtipul.app.data

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class DiaryFeeling(
    val name: String,
    val intensity: Int,
)

data class DiaryFeelingDraft(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val intensity: Int? = null,
) {
    constructor(persisted: DiaryFeeling) : this(
        name = persisted.name,
        intensity = persisted.intensity,
    )

    val trimmedName: String get() = name.trim()
}

data class DiaryFeelingGroup(
    val title: String,
    val feelings: List<String>,
)

object DiaryFeelingVocabulary {
    val groups: List<DiaryFeelingGroup> = listOf(
        DiaryFeelingGroup("עצב", listOf("עצוב", "מדוכא", "אומלל", "נוגה", "מדוכדך")),
        DiaryFeelingGroup("חרדה", listOf("חרד", "מודאג", "מבוהל", "מפוחד", "מבועת", "מתוח", "לחוץ")),
        DiaryFeelingGroup("אשמה ובושה", listOf("אשמה", "חרטה", "בושה", "ייסורי מצפון")),
        DiaryFeelingGroup("חוסר ערך", listOf("נחות", "דפוק", "חסר ערך", "לקוי", "פגום", "לא יוצלח")),
        DiaryFeelingGroup("בדידות ודחייה", listOf("בודד", "לבד", "דחוי", "נטוש", "לא אהוב")),
        DiaryFeelingGroup("מבוכה", listOf("מבוכה", "אווילי", "מושפל", "לא בנוח", "מובך")),
        DiaryFeelingGroup("חוסר תקווה", listOf("חסר תקווה", "מיואש", "פסימי", "ייאוש")),
        DiaryFeelingGroup("תסכול", listOf("מתוסכל", "תקוע", "מובס", "מנוצח")),
        DiaryFeelingGroup("כעס", listOf("כועס", "ממורמר", "רגוז", "מעוצבן", "זועם", "רותח", "פגוע")),
    )

    val allNames: List<String> = groups.flatMap { it.feelings }

    fun matching(query: String): List<String> {
        val needle = query.trim()
        if (needle.isEmpty()) return emptyList()
        return allNames.filter { it.contains(needle, ignoreCase = true) }
    }
}

data class DiaryOneEntryDraft(
    val event: String = "",
    val thought: String = "",
    val feelings: List<DiaryFeelingDraft> = emptyList(),
    val behaviour: String = "",
    val physicalSymptoms: String = "",
) {
    data class Snapshot(
        val event: String,
        val thought: String,
        val feelings: List<Pair<String, Int?>>,
        val behaviour: String,
        val physicalSymptoms: String,
    )

    val comparableSnapshot: Snapshot
        get() = Snapshot(
            event = event.trim(),
            thought = thought.trim(),
            feelings = feelings.map { it.trimmedName to it.intensity },
            behaviour = behaviour.trim(),
            physicalSymptoms = physicalSymptoms.trim(),
        )

    fun validationMessage(
        eventMissing: String,
        thoughtMissing: String,
        feelingsRequired: String,
        feelingName: String,
        intensityFor: (String) -> String,
        behaviourMissing: String,
    ): String? {
        if (event.trim().isEmpty()) return eventMissing
        if (thought.trim().isEmpty()) return thoughtMissing
        if (feelings.isEmpty()) return feelingsRequired
        for (feeling in feelings) {
            if (feeling.trimmedName.isEmpty()) return feelingName
            val intensity = feeling.intensity ?: return intensityFor(feeling.trimmedName)
            if (intensity !in 0..100) return intensityFor(feeling.trimmedName)
        }
        if (behaviour.trim().isEmpty()) return behaviourMissing
        return null
    }

    fun persistedFeelings(): List<DiaryFeeling>? {
        if (event.trim().isEmpty() || thought.trim().isEmpty() || behaviour.trim().isEmpty()) return null
        if (feelings.isEmpty()) return null
        if (feelings.any { it.trimmedName.isEmpty() || it.intensity == null || it.intensity !in 0..100 }) return null
        return feelings.map { DiaryFeeling(it.trimmedName, it.intensity ?: 0) }
    }

    companion object {
        fun from(entry: DiaryOneEntry) = DiaryOneEntryDraft(
            event = entry.event,
            thought = entry.thought,
            feelings = entry.feelings.map(::DiaryFeelingDraft),
            behaviour = entry.behaviour,
            physicalSymptoms = entry.physicalSymptoms.orEmpty(),
        )
    }
}
