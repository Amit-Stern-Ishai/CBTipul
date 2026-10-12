package com.cbtipul.app.data

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.*
import org.junit.Test

class InvitationBackupRulesTest {
    private fun source(path: String): File = listOf(File("src/main/$path"), File("app/src/main/$path"))
        .first { it.isFile }
    @Test fun cloudAndDeviceTransferExcludeOnlyAuthenticationPreferences() {
        val manifest = source("AndroidManifest.xml").readText()
        assertTrue(manifest.contains("android:allowBackup=\"false\""))
        assertTrue(manifest.contains("android:dataExtractionRules=\"@xml/auth_data_extraction_rules\""))
        assertTrue(manifest.contains("android:fullBackupContent=\"@xml/auth_backup_rules\""))
        for ((file, sections) in listOf("auth_backup_rules.xml" to listOf("full-backup-content"),
                "auth_data_extraction_rules.xml" to listOf("cloud-backup", "device-transfer"))) {
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(source("res/xml/$file"))
            for (section in sections) {
                val node = doc.getElementsByTagName(section).item(0)
                val exclusions = node.childNodes
                val paths = mutableSetOf<String>()
                for (index in 0 until exclusions.length) {
                    val entry = exclusions.item(index)
                    if (entry.nodeName != "exclude") continue
                    assertEquals("sharedpref", entry.attributes.getNamedItem("domain").nodeValue)
                    paths += entry.attributes.getNamedItem("path").nodeValue
                }
                assertEquals(setOf("com.CBTipul.app_preferences.xml", "browser_auth.xml"), paths)
                // No patient-name store, clinical cache, app settings, or wildcard exclusion.
            }
        }
    }
}
