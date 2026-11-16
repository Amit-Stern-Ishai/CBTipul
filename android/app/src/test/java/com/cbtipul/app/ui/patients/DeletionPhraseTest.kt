package com.cbtipul.app.ui.patients
import org.junit.Test
import org.junit.Assert.*
class DeletionPhraseTest {
 @Test fun exactPhrasesAndWhitespace() {
  assertEquals("מחיקת מטופל", DeletionPhrase.Patient.text)
  assertEquals("מחיקת חשבון", DeletionPhrase.Account.text)
  for (phrase in DeletionPhrase.entries) {
   assertTrue(phrase.matches(phrase.text))
   assertTrue(phrase.matches(" \n" + phrase.text + "\t "))
   for (input in listOf("", "מחיקת", phrase.text + "x", "ABCDEFGH")) assertFalse(phrase.matches(input))
  }
 }
}
