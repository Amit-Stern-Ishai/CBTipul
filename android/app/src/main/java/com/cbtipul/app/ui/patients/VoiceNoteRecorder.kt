package com.cbtipul.app.ui.patients

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

class VoiceNoteRecorder(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null
    private var tickJob: Job? = null
    private var recordingStartedAt = 0L
    private var outputFile: File? = null

    var isRecording: Boolean = false
        private set
    var isPlaying: Boolean = false
        private set
    var recordingFile: File? = null
        private set
    var durationSeconds: Double = 0.0
        private set
    var errorMessage: String? = null

    var onChange: () -> Unit = {}

    fun startRecording() {
        errorMessage = null
        stopPlayback()
        discardFile()
        val file = File(context.cacheDir, "voice-note-${UUID.randomUUID()}.m4a")
        val mediaRecorder = createRecorder()
        try {
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioSamplingRate(44_100)
            mediaRecorder.setAudioChannels(1)
            mediaRecorder.setAudioEncodingBitRate(128_000)
            mediaRecorder.setOutputFile(file.absolutePath)
            mediaRecorder.prepare()
            mediaRecorder.start()
            recorder = mediaRecorder
            outputFile = file
            recordingFile = null
            durationSeconds = 0.0
            recordingStartedAt = SystemClock.elapsedRealtime()
            isRecording = true
            tickJob?.cancel()
            tickJob = scope.launch {
                while (isRecording) {
                    durationSeconds = (SystemClock.elapsedRealtime() - recordingStartedAt) / 1000.0
                    onChange()
                    delay(250)
                }
            }
            onChange()
        } catch (error: Exception) {
            mediaRecorder.release()
            recorder = null
            file.delete()
            outputFile = null
            errorMessage = error.message
            onChange()
        }
    }

    fun stopRecording() {
        tickJob?.cancel()
        val active = recorder ?: return
        durationSeconds = (SystemClock.elapsedRealtime() - recordingStartedAt) / 1000.0
        try {
            active.stop()
        } catch (_: Exception) {
        }
        active.release()
        recorder = null
        isRecording = false
        recordingFile = outputFile
        onChange()
    }

    fun togglePlayback() {
        if (isPlaying) {
            stopPlayback()
            return
        }
        val file = recordingFile ?: return
        try {
            val mediaPlayer = MediaPlayer()
            mediaPlayer.setDataSource(file.absolutePath)
            mediaPlayer.setOnCompletionListener {
                it.release()
                player = null
                isPlaying = false
                onChange()
            }
            mediaPlayer.prepare()
            mediaPlayer.start()
            player = mediaPlayer
            isPlaying = true
            onChange()
        } catch (error: Exception) {
            errorMessage = error.message
            onChange()
        }
    }

    fun discard() {
        stopPlayback()
        tickJob?.cancel()
        recorder?.runCatching {
            stop()
            release()
        }
        recorder = null
        isRecording = false
        discardFile()
        durationSeconds = 0.0
        onChange()
    }

    fun release() {
        discard()
        scope.cancel()
    }

    private fun stopPlayback() {
        player?.runCatching {
            stop()
            release()
        }
        player = null
        if (isPlaying) {
            isPlaying = false
            onChange()
        }
    }

    private fun discardFile() {
        recordingFile?.delete()
        outputFile?.delete()
        recordingFile = null
        outputFile = null
    }

    private fun createRecorder(): MediaRecorder {
        @Suppress("DEPRECATION")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            MediaRecorder()
        }
    }
}
