package com.cbtipul.app.ui.patients

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.cbtipul.app.model.DatabaseId

object PatientAvatarColor {
    private val palette = longArrayOf(
        0xFFF2C94C, 0xFFF2994A, 0xFFEB5757, 0xFFE05D8B, 0xFFBB6BD9,
        0xFF9B7BFF, 0xFF6C63FF, 0xFF4C9AFF, 0xFF2D9CDB, 0xFF00C2A8,
        0xFF6FCF97, 0xFF27AE60, 0xFF9CCC65, 0xFFB2B85C, 0xFFD4A72C,
        0xFFCA7842, 0xFFC86F4A, 0xFFA94442, 0xFF8E44AD, 0xFF5F3DC4,
        0xFF4B6CB7, 0xFF3D8EA5, 0xFF38B2AC, 0xFF7BA57A, 0xFFC9A66B,
        0xFFD7A5A5, 0xFF8D99AE, 0xFF6B7280, 0xFF4B5563, 0xFF9CA3AF,
    )

    fun background(id: DatabaseId): Color = Color(palette[paletteIndex(id)])

    fun foreground(id: DatabaseId): Color =
        if (background(id).luminance() > 0.179f) Color.Black else Color.White

    private fun paletteIndex(id: DatabaseId): Int {
        var hash = 0xcbf29ce484222325uL
        for (byte in id.queryValue.encodeToByteArray()) {
            hash = hash xor byte.toUByte().toULong()
            hash *= 0x00000100000001b3uL
        }
        return (hash % palette.size.toULong()).toInt()
    }
}
