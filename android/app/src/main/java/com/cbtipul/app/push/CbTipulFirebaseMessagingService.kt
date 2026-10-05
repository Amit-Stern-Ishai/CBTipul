package com.cbtipul.app.push

import android.util.Log
import com.cbtipul.app.CbTipulApp
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class CbTipulFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        Log.i("CBTipulFCMEntry", "onNewToken ENTERED: token refresh occurred")
        (application as CbTipulApp).pushManager.onNewToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.i("CBTipulFCMEntry", "onMessageReceived ENTERED")
        // Temporary boundary diagnostics: never log payload values or the token.
        Log.i("CBTipulFCMEntry", "messageId=${message.messageId} dataKeys=${message.data.keys} from=${message.from}")
        (application as CbTipulApp).pushManager.onMessageReceived(message)
    }
}
