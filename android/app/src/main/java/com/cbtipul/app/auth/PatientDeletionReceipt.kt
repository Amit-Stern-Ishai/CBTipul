package com.cbtipul.app.auth
import kotlinx.serialization.json.*
internal fun validatePatientDeletionReceipt(status: Int, receipt: JsonObject) {
    check(status == 200 && (receipt["deleted"] as? JsonPrimitive)?.let { !it.isString && it.booleanOrNull == true } == true)
}
