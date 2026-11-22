package com.cbtipul.app.data
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class CoreBeliefWorksheetTest {
    @Test fun blankRoundTripIncludesEveryNull() {
        val value = CoreBeliefWorksheet()
        val encoded = CoreBeliefWorksheetCodec.encodeDocument(value)
        val json = Json.parseToJsonElement(encoded).jsonObject
        assertEquals(16, json.size)
        listOf("old_now","old_most","old_least","balanced_now","balanced_most","balanced_least","old_final","balanced_final").forEach { assertEquals(JsonNull,json[it]) }
        assertEquals(value,CoreBeliefWorksheetCodec.decodeDocument(encoded))
    }
    @Test fun zeroAndMixedValuesKeepTheirMeaning() {
        val value = CoreBeliefWorksheet(CoreBeliefWorksheet.Belief("ישן","חשש",0,91,null),CoreBeliefWorksheet.Belief("מאוזן","תקווה",12,null,0),"ראיות","חלופה","עבר","ניסוי",0,100)
        val encoded = CoreBeliefWorksheetCodec.encodeDocument(value)
        val json = Json.parseToJsonElement(encoded).jsonObject
        assertEquals(JsonPrimitive(0),json["old_now"]); assertEquals(JsonPrimitive(91),json["old_most"])
        assertEquals(JsonPrimitive(12),json["balanced_now"]); assertEquals(JsonPrimitive(0),json["old_final"])
        assertEquals(JsonPrimitive(100),json["balanced_final"]); assertEquals(JsonPrimitive("חלופה"),json["alternative_interpretations"])
        assertEquals(value,CoreBeliefWorksheetCodec.decodeDocument(encoded))
    }
    @Test fun absentAndPublishedDocumentsRemainDistinct() {
        val empty = CoreBeliefWorksheetCodec.decodeRecord("""{"patient_id":"p","document":null,"revision":null,"published_at":null}""")
        assertNull(empty.document); assertNull(empty.updatedAt)
        val document = CoreBeliefWorksheetCodec.encodeDocument(CoreBeliefWorksheet())
        val record = CoreBeliefWorksheetCodec.decodeRecord("""{"patient_id":"p","document":$document,"revision":"opaque-A","published_at":"sent","published_revision":"opaque-A","updated_at":"updated"}""")
        assertEquals(CoreBeliefWorksheet(),record.document); assertEquals("opaque-A",record.revision)
        assertEquals("opaque-A",record.publishedRevision); assertEquals("updated",record.updatedAt); assertEquals("sent",record.publishedAt)
        val edit = record.document!!.copy(oldBelief=record.document.oldBelief.copy(text="B"))
        assertEquals("",record.document.oldBelief.text); assertEquals("B",edit.oldBelief.text)
    }
    @Test fun malformedRatingsAndMissingKeysAreRejected() {
        val json = Json.parseToJsonElement(CoreBeliefWorksheetCodec.encodeDocument(CoreBeliefWorksheet())).jsonObject
        listOf(JsonPrimitive(-1),JsonPrimitive(101),JsonPrimitive(0.5),JsonPrimitive("0"),JsonPrimitive(true)).forEach { bad ->
            assertThrows(Exception::class.java) { CoreBeliefWorksheetCodec.decodeDocument(JsonObject(json + ("old_now" to bad)).toString()) }
        }
        assertThrows(Exception::class.java) { CoreBeliefWorksheetCodec.decodeDocument(JsonObject(json - "old_now").toString()) }
        assertThrows(Exception::class.java) { CoreBeliefWorksheetCodec.encodeDocument(CoreBeliefWorksheet(finalOldRating=101)) }
    }

    @org.junit.Test fun requestSeparatesDraftAndPublishedCopy() {
        val draft=CoreBeliefWorksheet(oldBelief=CoreBeliefWorksheet.Belief(now=0))
        val save=CoreBeliefContract.body("save","patient",null,draft)
        val encoded=save.getValue("document").toString()
        val decoded=CoreBeliefWorksheetCodec.decodeDocument(encoded)
        org.junit.Assert.assertEquals(0,decoded.oldBelief.now)
        org.junit.Assert.assertNull(decoded.oldBelief.most)
        org.junit.Assert.assertEquals(kotlinx.serialization.json.JsonNull,save["expected_revision"])
        val publish=CoreBeliefContract.body("publish","patient","opaque",draft)
        org.junit.Assert.assertFalse(publish.containsKey("document"))
        org.junit.Assert.assertEquals(1,CoreBeliefContract.body("load_published","must-not-send","revision",draft).size)
        org.junit.Assert.assertTrue(runCatching { CoreBeliefContract.body("publish","patient",null,draft) }.isFailure)
    }
}
