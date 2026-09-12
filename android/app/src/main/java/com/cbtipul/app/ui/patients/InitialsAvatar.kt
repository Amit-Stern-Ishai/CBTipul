package com.cbtipul.app.ui.patients

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.model.DatabaseId

@Composable
fun InitialsAvatar(name: String, patientId: DatabaseId, size: Dp = 44.dp) {
    val initials = name.trim()
        .split(Regex("\\s+"))
        .filter { it.isNotEmpty() }
        .take(2)
        .map { it.first().uppercaseChar() }
        .joinToString("")
        .ifEmpty { "?" }
    Box(
        modifier = Modifier
            .size(size)
            .background(PatientAvatarColor.background(patientId), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initials,
            color = PatientAvatarColor.foreground(patientId),
            fontWeight = FontWeight.SemiBold,
            fontSize = (size.value * 0.36f).sp,
        )
    }
}
