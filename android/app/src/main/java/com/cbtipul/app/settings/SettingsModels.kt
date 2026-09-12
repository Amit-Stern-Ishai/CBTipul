package com.cbtipul.app.settings

enum class AppAppearance(val storageValue: String) {
    Light("light"),
    Dark("dark");

    companion object {
        fun fromStorage(value: String?): AppAppearance =
            entries.find { it.storageValue == value } ?: Dark
    }
}

enum class AppTextSize(val storageValue: String, val fontScale: Float) {
    Small("small", 0.85f),
    Standard("standard", 1.0f),
    Large("large", 1.15f),
    ExtraLarge("extraLarge", 1.3f),
    Huge("huge", 1.55f);

    companion object {
        fun fromStorage(value: String?): AppTextSize =
            entries.find { it.storageValue == value } ?: Standard
    }
}

enum class AIResponseStyle(val storageValue: String) {
    Typing("typing"),
    Regular("regular");

    companion object {
        fun fromStorage(value: String?): AIResponseStyle =
            entries.find { it.storageValue == value } ?: Typing
    }
}
