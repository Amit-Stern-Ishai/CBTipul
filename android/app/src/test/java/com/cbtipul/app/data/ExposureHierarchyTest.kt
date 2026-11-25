package com.cbtipul.app.data
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
class ExposureHierarchyTest {
 @Test fun roundTripAndOrder(){val a=ExposureItem(situation="א");val b=ExposureItem(situation="ב",difficulty=0);val c=ExposureItem(situation="ג",difficulty=90);val baseline=ExposureDocument(listOf(c,b,a));val draft=baseline.move(a.id,0);assertEquals(listOf(a,c,b),draft.items);assertEquals(listOf(c,b,a),baseline.items);val encoded=ExposureContract.json.encodeToJsonElement(draft);assertEquals(draft,ExposureContract.json.decodeFromJsonElement<ExposureDocument>(encoded));assertEquals(JsonNull,encoded.jsonObject["items"]!!.jsonArray[0].jsonObject["difficulty"]);assertEquals(JsonPrimitive(0),encoded.jsonObject["items"]!!.jsonArray[2].jsonObject["difficulty"])}
 @Test fun validationAndIdentity(){val a=ExposureItem(situation="א");assertTrue(ExposureDocument().valid());assertFalse(ExposureDocument(listOf(a,a)).valid());for(item in listOf(a.copy(situation=" "),a.copy(situation="א".repeat(1001)),a.copy(difficulty=101),a.copy(difficulty=-1),a.copy(id="bad")))assertFalse(ExposureDocument(listOf(item)).valid());val body=ExposureContract.body("save",null,null,ExposureDocument(listOf(a)));assertFalse(body.containsKey("patient_id"));assertEquals(JsonNull,body["expected_revision"]);assertEquals(JsonPrimitive("p"),ExposureContract.body("load","p",null,ExposureDocument())["patient_id"])}
 @Test fun ongoingAssignmentRecognized(){val row=PatientAssignment("a","p",null,null,"exposure_hierarchy",java.util.Date(),java.util.Date(),null);assertTrue(row.isExposureHierarchy);assertTrue(row.isOpen);assertFalse(row.copy(cancelledAt=java.util.Date()).isOpen)}
 @Test fun nullDocumentIsNotAnEmptyList(){assertNull(ExposureContract.json.decodeFromString<ExposureRecord>("""{"patient_id":"p","document":null,"revision":null}""").document)}
}
