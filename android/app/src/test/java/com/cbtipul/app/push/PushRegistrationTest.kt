package com.cbtipul.app.push

import org.junit.Assert.assertEquals
import org.junit.Test

class PushRegistrationTest {
    @Test
    fun androidRegisterUsesProductionEnvironment() {
        assertEquals("android", PushRegistration.PLATFORM)
        assertEquals("production", PushRegistration.ENVIRONMENT)
        assertEquals("cbtipul_notifications", PushRegistration.CHANNEL_ID)
    }
}
