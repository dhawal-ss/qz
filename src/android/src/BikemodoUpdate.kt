package org.cagnulen.qdomyoszwift

import android.app.Activity
import android.content.Context
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import org.json.JSONObject

// Bikemodo's updates come from Google Play, the only way a Play app may update itself. This is
// Play's in-app update, the flexible kind: Play's own dialog asks once, the new version downloads
// while the rider carries on, and a restart puts it in (or Play installs it quietly while the app
// is in the background). A build not installed from Play (a test APK) never sees an update.
// The app asks state() for where it stands (JSON):
//   { "state", "version", "progress" }
// state: "none", "available", "asking" (Play's dialog is open), "declined" (no thanks, until the
// app starts again), "downloading" (progress 0..1), "downloaded", "failed".
object BikemodoUpdate {
    private const val TAG = "BikemodoUpdate"
    private const val REQUEST_CODE = 7311

    @Volatile
    private var state = "none"

    @Volatile
    private var version = 0

    @Volatile
    private var progress = 0.0

    private var manager: AppUpdateManager? = null

    private val listener = InstallStateUpdatedListener { s ->
        follow(s.installStatus(), s.bytesDownloaded(), s.totalBytesToDownload())
    }

    @Synchronized
    private fun manager(context: Context): AppUpdateManager {
        manager?.let { return it }
        val m = AppUpdateManagerFactory.create(context.applicationContext)
        m.registerListener(listener)
        manager = m
        return m
    }

    private fun follow(status: Int, bytes: Long, total: Long) {
        when (status) {
            InstallStatus.PENDING, InstallStatus.DOWNLOADING -> {
                progress = if (total > 0) bytes.toDouble() / total else 0.0
                state = "downloading"
            }
            InstallStatus.DOWNLOADED -> {
                progress = 1.0
                state = "downloaded"
            }
            InstallStatus.FAILED -> state = "failed"
            // the rider stopped the download in Play's notification
            InstallStatus.CANCELED -> state = "declined"
        }
    }

    // asks Play whether there is a newer version; the answer comes in state()
    @JvmStatic
    fun check(context: Context?) {
        if (context == null)
            return
        try {
            manager(context).appUpdateInfo
                .addOnSuccessListener { info ->
                    version = info.availableVersionCode()
                    val status = info.installStatus()
                    if (status == InstallStatus.PENDING || status == InstallStatus.DOWNLOADING || status == InstallStatus.DOWNLOADED) {
                        follow(status, info.bytesDownloaded(), info.totalBytesToDownload())
                    } else if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                        info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                        if (state != "asking" && state != "declined")
                            state = "available"
                    } else {
                        state = "none"
                    }
                }
                .addOnFailureListener { e ->
                    // not installed from Play, no Play Store, or offline
                    QLog.d(TAG, "No update check: " + e.message)
                    if (state != "downloading" && state != "downloaded")
                        state = "none"
                }
        } catch (t: Throwable) {
            QLog.w(TAG, "Cannot check for an update", t)
        }
    }

    // Play's dialog for the update that check() found; it downloads in the background once allowed
    @JvmStatic
    fun start(context: Context?) {
        val activity = context as? Activity ?: return
        try {
            val m = manager(activity)
            // an AppUpdateInfo starts one flow only, so ask for a fresh one
            m.appUpdateInfo.addOnSuccessListener { info ->
                if (info.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE ||
                    !info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE))
                    return@addOnSuccessListener
                activity.runOnUiThread {
                    try {
                        state = "asking"
                        if (!m.startUpdateFlowForResult(info, activity,
                                AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(), REQUEST_CODE))
                            state = "available"
                    } catch (t: Throwable) {
                        QLog.w(TAG, "Cannot open Play's update dialog", t)
                        state = "failed"
                    }
                }
            }
        } catch (t: Throwable) {
            QLog.w(TAG, "Cannot start the update", t)
        }
    }

    // Play's dialog closed (CustomQtActivity.onActivityResult); true when it was ours
    @JvmStatic
    fun onResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_CODE)
            return false
        if (resultCode == Activity.RESULT_OK) {
            // the listener moves it to "downloading"
            if (state == "asking")
                state = "downloading"
        } else {
            state = "declined"
        }
        return true
    }

    // puts the downloaded update in: Play restarts the app (in the foreground) or installs it
    // quietly (in the background)
    @JvmStatic
    fun complete(context: Context?) {
        if (context == null || state != "downloaded")
            return
        try {
            manager(context).completeUpdate()
        } catch (t: Throwable) {
            QLog.w(TAG, "Cannot install the update", t)
        }
    }

    @JvmStatic
    fun state(): String =
        JSONObject().put("state", state).put("version", version).put("progress", progress).toString()
}
