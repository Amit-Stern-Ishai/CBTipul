package com.cbtipul.app.telemetry

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Build
import com.cbtipul.app.BuildConfig
import java.util.Locale
import java.util.TimeZone

/** No sensitive permissions. Network stays unknown when ACCESS_NETWORK_STATE is absent. */
object TelemetryPlatform {
    private val starts = ActivityStartTracker()
    fun activityStart(recreated: Boolean) = starts.start(recreated)
    private fun network(app: Application): Network = runCatching {
        if (app.checkSelfPermission(android.Manifest.permission.ACCESS_NETWORK_STATE) != android.content.pm.PackageManager.PERMISSION_GRANTED) return Network.unknown
        val manager=app.getSystemService(android.net.ConnectivityManager::class.java) ?: return Network.unknown
        val active=manager.activeNetwork ?: return Network.offline
        val caps=manager.getNetworkCapabilities(active) ?: return Network.unknown
        when {
            caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) -> Network.wifi
            caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) -> Network.cellular
            caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET) -> Network.ethernet
            else -> Network.other
        }
    }.getOrDefault(Network.unknown)
    fun install(app: Application) {
        var active=0
        val state=java.util.concurrent.atomic.AtomicReference(Lifecycle.background)
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) { active++; state.set(Lifecycle.foreground) }
            override fun onActivityStopped(activity: Activity) { active=(active-1).coerceAtLeast(0); if(active==0) state.set(Lifecycle.background) }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
        Telemetry.install(TelemetryClient({
            Metadata(deviceModel=Build.MODEL ?: "unknown",manufacturer=Build.MANUFACTURER ?: "unknown",
                osVersion=Build.VERSION.RELEASE ?: "unknown",apiLevel=Build.VERSION.SDK_INT,
                appVersion=BuildConfig.VERSION_NAME,build=BuildConfig.VERSION_CODE.toString(),
                buildChannel=if(BuildConfig.DEBUG) "debug" else "release",
                network=network(app),lifecycle=state.get(),locale=Locale.getDefault().toLanguageTag(),timezone=TimeZone.getDefault().id)
        }))
        PostHogTelemetryBootstrap.configure(app, Telemetry.client)
    }
}
