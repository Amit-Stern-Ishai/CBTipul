package com.cbtipul.app.data

/** Count complete ADTS frames; a truncated final frame after process death is ignored. */
object SessionAudioMetadata {
    fun duration(input: java.io.InputStream): Double {
        val rates = intArrayOf(96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350)
        var seconds=0.0
        val header=ByteArray(7)
        while (true) {
            var read=0
            while(read<7) { val n=input.read(header,read,7-read); if(n<0) return seconds; read+=n }
            val b=header.map { it.toInt() and 255 }
            require(b[0]==255 && b[1] and 0xF6 == 0xF0) { "Invalid protected audio" }
            val index=(b[2] shr 2) and 15
            require(index<rates.size)
            val length=((b[3] and 3) shl 11) or (b[4] shl 3) or (b[5] shr 5)
            require(length>=7)
            var left=length-7
            while(left>0) { val n=input.read(); if(n<0) return seconds;left-- }
            seconds += 1024.0*((b[6] and 3)+1)/rates[index]
        }
    }
}
