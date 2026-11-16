package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.util.Date
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.patients.recentSubmissions

class DiaryUnreadTest {
 private val patient="11111111-1111-4111-8111-111111111111"
 private val other="22222222-2222-4222-8222-222222222222"
 private val entries=(1..3).map {"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa$it"}
 private fun key(i:Int,resource:String="diary_one_entry")=DiaryNotificationKey.of(patient,resource,entries[i])!!
 private inner class Fixture:AutoCloseable {
  val rows=(0..5).map {i->buildJsonObject {
   put("id","00000000-0000-4000-8000-%012d".format(i+1));put("type",if(i==5)"questionnaire_completed" else "diary_1_entry_added")
   put("patient_id",if(i==4)other else patient);put("resource_type",if(i==5)"questionnaire" else "diary_one_entry")
   put("resource_id",entries[if(i==3)0 else minOf(i,2)]);put("created_at","2026-11-11T10:00:00Z");put("read_at",JsonNull);put("seen_at",JsonNull)
  }}.toMutableList()
  val writes=mutableListOf<String>();var fail=false;var loadFail=false
  var owner:String?="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  var onMark:(()->Unit)?=null
  val server=HttpServer.create(InetSocketAddress("127.0.0.1",0),0).also {s->
   s.createContext("/"){e->
    val path=e.requestURI.path;var status=200
    val body=synchronized(rows){when {
     path.endsWith("mark_notification_read")-> {
      if(fail){status=503;"""{"code":"XX000","message":"synthetic failure"}"""}
      else {val id=Json.parseToJsonElement(e.requestBody.bufferedReader().readText()).jsonObject.getValue("p_notification_id").jsonPrimitive.content
       writes+=id
       for(i in rows.indices)if(rows[i]["id"]?.jsonPrimitive?.content==id)rows[i]=JsonObject(rows[i]+("read_at" to JsonPrimitive("2026-11-11T11:00:00Z")))
       onMark?.invoke();"null"
      }
     }
     path.endsWith("get_unseen_notification_count")->"0"
     path.endsWith("notifications")->if(loadFail){status=503;"""{"code":"XX000"}"""}else JsonArray(rows).toString()
     else->"null"
    }}.toByteArray()
    e.responseHeaders.add("Content-Type","application/json");e.sendResponseHeaders(status,body.size.toLong());e.responseBody.use {it.write(body)}
   };s.start()
  }
  val client=createSupabaseClient("http://127.0.0.1:${server.address.port}","synthetic"){install(Postgrest)}
  val repository=NotificationRepository(client,currentUserId={owner})
  override fun close(){runBlocking {client.close()};server.stop(0)}
 }
 @Test fun threeEntriesPushHistoryFinalAndRelaunchKeepDateRows()=runBlocking {
  Fixture().use {f->
   val repo=f.repository;repo.refresh()
   fun count()=DiaryNotificationReadState.unreadKeys(repo.items.value).count {it.patientId==patient}
   assertEquals(3,count());assertEquals(6,repo.items.value.size)
   val clinical=entries.map {id->DiaryOneEntry(id,DatabaseId.Text(patient),"synthetic-therapist",DiaryOneEntryCreator.Patient,"synthetic",emptyList(),emptyList(),"synthetic",null,Date(1000),Date(1000))}
   fun profileRows()=recentSubmissions(Patient(DatabaseId.Text(patient)),clinical,emptyList(),emptyList(),emptyList(),RecentActivityDismissals({emptySet()},{_,_->}),f.owner)
   assertEquals(3,profileRows().size)
   val push=NotificationPayload.from(repo.items.value.first())
   val destination=NotificationRouting.destination(push) as AppDestination.DiaryOneEntry
   assertEquals(entries[0],destination.entryId)
   repo.markDiaryEntryRead(key(0));assertEquals(2,count());assertEquals(2,f.writes.size);assertEquals(3,profileRows().size)
   repo.markDiaryEntryRead(key(1));assertEquals(1,count());assertEquals(3,profileRows().size)
   repo.markDiaryEntryRead(key(2));assertEquals(0,count());assertEquals(3,profileRows().size)
   assertEquals(6,repo.items.value.size)
   assertTrue(repo.items.value.first {it.patientId==other}.isUnread)
   assertTrue(repo.items.value.first {it.type==AppNotificationTypes.QUESTIONNAIRE_COMPLETED}.isUnread)
   val relaunched=NotificationRepository(f.client,currentUserId={f.owner});relaunched.refresh()
   assertEquals(0,DiaryNotificationReadState.unreadKeys(relaunched.items.value).count {it.patientId==patient})
  }
 }
 @Test fun refreshMissingEntryAndFailedReceiptNeverClearUnread()=runBlocking {
  Fixture().use {f->
   f.repository.refresh();f.repository.refresh();assertTrue(f.writes.isEmpty())
   f.repository.markDiaryEntryRead(DiaryNotificationKey.of(patient,"diary_one_entry","aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa99")!!)
   assertTrue(f.writes.isEmpty());f.fail=true;f.repository.markDiaryEntryRead(key(0))
   assertTrue(f.repository.items.value.all {it.isUnread})
   f.loadFail=true;f.repository.refresh();assertTrue(f.writes.isEmpty())
  }
 }
 @Test fun coldOpenAndLateDuplicateUsePersistedReadReceipt()=runBlocking {
  Fixture().use {f->
   f.repository.markDiaryEntryRead(key(0)) // No preceding inbox load.
   synchronized(f.rows){f.rows+=JsonObject(f.rows[0]+("id" to JsonPrimitive("00000000-0000-4000-8000-000000000099"))+("read_at" to JsonNull))}
   val relaunched=NotificationRepository(f.client,currentUserId={f.owner});relaunched.refresh()
   assertEquals(2,DiaryNotificationReadState.unreadKeys(relaunched.items.value).count {it.patientId==patient})
   assertTrue(relaunched.items.value.filter {DiaryNotificationKey.from(it)==key(0)}.all {!it.isUnread})
  }
 }
 @Test fun accountSwitchWhileReceiptRunsCannotUpdateNewAccount()=runBlocking {
  Fixture().use {f->f.repository.refresh();f.onMark={f.owner="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";f.repository.clear()}
   f.repository.markDiaryEntryRead(key(0));assertTrue(f.repository.items.value.isEmpty())
  }
 }
 @Test fun exactTypesAndMissingIdentityNeverGuessNewest()=runBlocking {
  Fixture().use {f->f.repository.refresh();val row=f.repository.items.value.first()
   for((type,resource)in listOf("diary_1_entry_added" to "diary_one_entry","diary_2_entry_added" to "diary_two_entry","diary_3_entry_added" to "diary_three_entry")) {
    assertEquals(key(0,resource),DiaryNotificationKey.from(row.copy(type=type,resourceType=resource)))
   }
   assertNull(DiaryNotificationKey.from(row.copy(resourceId=null)))
   assertNull(DiaryNotificationKey.from(row.copy(resourceType="diary_two_entry")))
   assertNull(DiaryNotificationKey.of(patient,"diary_one_entry","latest"))
   assertNotEquals(key(0),DiaryNotificationKey.of(other,"diary_one_entry",entries[0]))
   assertTrue(f.writes.isEmpty())
  }
 }
}
