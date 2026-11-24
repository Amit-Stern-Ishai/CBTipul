package com.cbtipul.app.data

object RevokePatientAccess {
    const val phrase = "הפסקת גישה"
    const val explanation = "הפסקת הגישה תמנע מהמטופל/ת גישה לתיק באפליקציה.\nהתיק והמידע שנשמר בו לא יימחקו."
    fun matches(input: String) = input.trim() == phrase
    fun confirmed(value: String) = value == "access_revoked" || value == "already_disconnected"
}
