package com.cbtipul.app.data
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
class ConceptSuggestionsTest {
 @Test fun allSectionsUseCurrentCompleteDraft() {
  val draft=emptyConcept()+(ConceptSection.Core to listOf("unsaved"))
  ConceptSection.entries.forEach { section->val body=ConceptSuggestions.body("selected",section,draft,"full context");assertEquals(JsonPrimitive(section.key),body["section"]);assertEquals(JsonPrimitive("selected"),body["patient_id"]);assertEquals(5,body["document"]!!.jsonObject.size);assertEquals("unsaved",body["document"]!!.jsonObject["core_beliefs"]!!.jsonArray[0].jsonPrimitive.content) }
 }
 @Test fun emptyAndMalformedResponses(){assertTrue(ConceptSuggestions.decode(buildJsonObject{put("suggestions",JsonArray(emptyList()))}).isEmpty());assertThrows(IllegalArgumentException::class.java){ConceptSuggestions.decode(buildJsonObject{put("suggestions",JsonArray(List(5){JsonPrimitive("x")}))})}}
 @Test fun appendPreservesEditsAndDeduplicates(){assertEquals(listOf("old","new"),ConceptSuggestions.append(listOf("old"),listOf("old","new","new")));assertEquals(30,ConceptSuggestions.append(List(30){"$it"},listOf("new")).size)}
}
