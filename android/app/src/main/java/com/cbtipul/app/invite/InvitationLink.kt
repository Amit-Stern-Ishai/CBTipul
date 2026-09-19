package com.cbtipul.app.invite

import android.net.Uri

/**
 * Parses canonical patient-invitation App Links:
 * `https://cbtipul.com/invite/<TOKEN>`.
 *
 * Does not claim the invitation or talk to the backend.
 */
object InvitationLink {
    const val HOST = "cbtipul.com"
    const val PATH_PREFIX = "/invite/"

    fun tokenFrom(uri: Uri?): String? {
        if (uri == null) return null
        return tokenFrom(uri.scheme, uri.host, uri.path)
    }

    fun tokenFrom(scheme: String?, host: String?, path: String?): String? {
        if (scheme != "https") return null
        if (host != HOST) return null
        val normalizedPath = path.orEmpty()
        if (!normalizedPath.startsWith(PATH_PREFIX)) return null
        val token = normalizedPath.removePrefix(PATH_PREFIX).trimEnd('/')
        if (token.isEmpty() || token.contains('/')) return null
        return token
    }
}
