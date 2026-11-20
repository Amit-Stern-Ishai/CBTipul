package com.cbtipul.app.data
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class PatientConceptualizationTest {
    @Test fun completeVersionedPayloadAndPublishedScope() {
        val a = emptyConcept() + (ConceptSection.Core to listOf("A"))
        val first = ConceptContract.body("save", "p", null, a)
        assertEquals(JsonNull, first["expected_revision"])
        assertEquals(5, first["document"]!!.jsonObject.size)
        assertEquals(JsonPrimitive("opaque"), ConceptContract.body("save", "p", "opaque", a)["expected_revision"])
        assertEquals(buildJsonObject { put("action", "load_published") }, ConceptContract.body("load_published", "never-send", "ignored", a))
        assertThrows(IllegalArgumentException::class.java) { ConceptContract.body("publish", "p", null, a) }
    }
    @Test fun limitsAndNoSharedMutableSnapshot() {
        val a = emptyConcept() + (ConceptSection.Core to listOf("A")); val b = a + (ConceptSection.Core to listOf("B"))
        assertEquals(listOf("A"), a[ConceptSection.Core]); assertNotEquals(a,b)
        assertFalse(validConcept(a + (ConceptSection.Rules to listOf(" "))))
        assertFalse(validConcept(a + (ConceptSection.Rules to List(31) { "משפט" })))
        assertFalse(validConcept(a + (ConceptSection.Rules to listOf("א".repeat(1501)))))
        assertTrue(validConcept(emptyConcept()))
    }
    @Test fun mappingPreservesNullAndRejectsWrongPatient() {
        val empty = buildJsonObject { put("patient_id", "p"); put("document", JsonNull); put("revision", JsonNull) }
        assertNull(ConceptContract.decode(empty, "p").document)
        assertThrows(IllegalArgumentException::class.java) { ConceptContract.decode(empty, "other") }
        val row = buildJsonObject { put("patient_id","p"); put("document", ConceptContract.body("save","p",null,emptyConcept())["document"]!!); put("revision","r-A"); put("published_revision","r-A") }
        assertEquals("r-A", ConceptContract.decode(row,"p").revision)
    }
}
