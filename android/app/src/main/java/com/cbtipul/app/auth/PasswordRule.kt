package com.cbtipul.app.auth

enum class PasswordRule {
    MinLength,
    Uppercase,
    Lowercase,
    Digit,
    Special,
    ;

    fun isMet(password: String): Boolean = when (this) {
        MinLength -> password.length >= 8
        Uppercase -> password.any { it.isUpperCase() }
        Lowercase -> password.any { it.isLowerCase() }
        Digit -> password.any { it.isDigit() }
        Special -> password.any { !it.isLetterOrDigit() && !it.isWhitespace() }
    }

    companion object {
        fun allSatisfied(password: String): Boolean = entries.all { it.isMet(password) }
    }
}
