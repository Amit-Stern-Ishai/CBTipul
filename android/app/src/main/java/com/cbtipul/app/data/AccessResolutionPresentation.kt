package com.cbtipul.app.data

/** Email verification, authentication, context resolution and entitlement are independent. */
enum class AccessResolutionPresentation { Loading, Retry, Full, ReadOnly }

fun accessResolutionPresentation(
    userId: String,
    entitlement: EntitlementSnapshot,
    contextState: AppContextLoadState,
): AccessResolutionPresentation {
    if (entitlement.identity == userId) {
        when (entitlement.access) {
            EntitlementAccess.Full -> return AccessResolutionPresentation.Full
            EntitlementAccess.ReadOnly -> return AccessResolutionPresentation.ReadOnly
            null -> Unit
        }
    }
    return if (contextState is AppContextLoadState.Failed) AccessResolutionPresentation.Retry
        else AccessResolutionPresentation.Loading
}
