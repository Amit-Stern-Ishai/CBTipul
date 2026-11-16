package com.cbtipul.app

import android.app.Activity
import android.os.Bundle
import android.media.MediaExtractor
import android.widget.TextView
import com.cbtipul.app.data.TranscriptionAudio
import java.io.File

/** Synthetic local platform regression: no microphone, account, or network. */
class TranscriptionAudioReviewActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val result = runCatching {
            val dir = File(noBackupFilesDir, "synthetic-audio-validation").apply { mkdirs() }
            val source = File(dir, "tone.aac")
            assets.open("synthetic-transcription-tone.aac").use { input -> source.outputStream().use { input.copyTo(it) } }
            val original = source.readBytes()
            try {
                TranscriptionAudio.withUpload(source) { upload ->
                    check(upload.extension == "m4a")
                    val bytes = upload.readBytes()
                    check(bytes.copyOfRange(4, 8).decodeToString() == "ftyp")
                    val ex = MediaExtractor()
                    try {
                        ex.setDataSource(upload.absolutePath)
                        check(ex.trackCount == 1)
                        ex.selectTrack(0)
                        var count = 0
                        do { count++ } while(ex.advance())
                        check(count > 40)
                    } finally { ex.release() }
                }
                check(source.readBytes().contentEquals(original))
                check(dir.listFiles()!!.size == 1)
                check(runCatching { TranscriptionAudio.withUpload(source) { error("synthetic network failure") } }.isFailure)
                check(source.readBytes().contentEquals(original))
                check(dir.listFiles()!!.size == 1)
                // Existing M4A uses its original file; no accidental deletion.
                val existing = File(dir, "existing.m4a").apply { writeBytes(byteArrayOf(1,2,3)) }
                try { TranscriptionAudio.withUpload(existing) { check(it == existing) }; check(existing.exists()) }
                finally { existing.delete() }
            } finally { source.delete(); dir.delete() }
            "PASS: M4A format, complete frames, unchanged original, failure cleanup, legacy M4A"
        }.getOrElse { "FAIL: " + it.javaClass.simpleName }
        android.util.Log.i("TranscriptionAudioCheck", result)
        setContentView(TextView(this).apply { text=result; textSize=20f; setPadding(32,80,32,32) })
    }
}
