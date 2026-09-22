package com.cbtipul.app.push

import com.cbtipul.app.CbTipulApp
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class CbTipulFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        (application as CbTipulApp).pushManager.onNewToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        (application as CbTipulApp).pushManager.onMessageReceived(message)
    }
}
