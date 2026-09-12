package com.cbtipul.app.ui.theme

import java.text.DateFormat
import java.util.Date
import java.util.Locale

fun hebrewDate(date: Date): String =
    DateFormat.getDateInstance(DateFormat.MEDIUM, Locale("he", "IL")).format(date)
