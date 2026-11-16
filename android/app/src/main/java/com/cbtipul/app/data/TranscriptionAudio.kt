package com.cbtipul.app.data

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/** Keep crash-recoverable ADTS untouched; upload an M4A container, without re-encoding. */
object TranscriptionAudio {
    fun <T> withUpload(source: File, action: (File) -> T): T {
        if (!source.extension.equals("aac", ignoreCase = true)) return action(source)
        // Beside the protected, account-scoped source, never public/shared storage.
        val upload = File.createTempFile("transcription-", ".m4a", source.parentFile)
        try {
            remux(source, upload)
            return action(upload)
        } finally { upload.delete() }
    }

    internal fun remux(source: File, target: File) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(source.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == "audio/mp4a-latm"
            } ?: error("No AAC track")
            val format = extractor.getTrackFormat(track)
            extractor.selectTrack(track)
            val writer = MediaMuxer(target.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = writer
            val destination = writer.addTrack(format)
            writer.start()
            val buffer = ByteBuffer.allocate(1024 * 1024)
            val info = MediaCodec.BufferInfo()
            var frames = 0
            while (true) {
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                info.set(0, size, extractor.sampleTime.coerceAtLeast(0), 0)
                writer.writeSampleData(destination, buffer, info)
                frames++
                if (!extractor.advance()) break
            }
            check(frames > 0) { "No complete audio frames" }
            writer.stop()
        } finally {
            try { muxer?.release() } finally { extractor.release() }
        }
    }
}
