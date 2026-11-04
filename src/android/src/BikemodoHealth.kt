package org.cagnulen.qdomyoszwift

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

// Bikemodo reads three things from Health Connect, only once the rider asks for it: heart rate
// variability (RMSSD), resting heart rate and sleep, a value a day for the last 35 days, for the
// readiness on Today. Nothing is sent anywhere. The answer is left in `latest` (JSON) for the app to
// take: { "available", "granted", "days": [{ "day", "hrv", "rhr", "sleepMin" }] }.
object BikemodoHealth {
    private const val TAG = "BikemodoHealth"
    private const val PROVIDER = "com.google.android.apps.healthdata"

    @Volatile
    private var latest: String = ""

    private fun readPermissions(): Set<String> = setOf(
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class)
    )

    @JvmStatic
    fun available(context: Context?): Boolean {
        if (context == null || Build.VERSION.SDK_INT < 26)
            return false
        return try {
            HealthConnectClient.getSdkStatus(context.applicationContext, PROVIDER) == HealthConnectClient.SDK_AVAILABLE
        } catch (t: Throwable) {
            false
        }
    }

    // the Health Connect dialog for the three read permissions
    @JvmStatic
    fun requestRead(context: Context?) {
        val activity = context as? Activity ?: return
        if (!available(activity))
            return
        try {
            val intent = Intent(activity, HealthConnectPermissionActivity::class.java)
            intent.putStringArrayListExtra(HealthConnectPermissionActivity.EXTRA_PERMISSIONS, ArrayList(readPermissions()))
            activity.runOnUiThread { activity.startActivity(intent) }
        } catch (t: Throwable) {
            QLog.w(TAG, "Cannot ask for the Health Connect read permissions", t)
        }
    }

    // reads the last 35 days in the background; take() gives the answer once it is there
    @JvmStatic
    fun refresh(context: Context?) {
        if (context == null)
            return
        if (!available(context)) {
            latest = JSONObject().put("available", false).put("granted", false).put("days", JSONArray()).toString()
            return
        }
        val app = context.applicationContext
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val client = HealthConnectClient.getOrCreate(app, PROVIDER)
                val granted = client.permissionController.getGrantedPermissions()
                val zone = ZoneId.systemDefault()
                val end = Instant.now()
                val start = end.minus(35, ChronoUnit.DAYS)
                val range = TimeRangeFilter.between(start, end)
                val hrv = HashMap<LocalDate, MutableList<Double>>()
                val rhr = HashMap<LocalDate, MutableList<Double>>()
                val sleep = HashMap<LocalDate, Long>()

                if (granted.contains(HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class))) {
                    var token: String? = null
                    do {
                        val page = client.readRecords(ReadRecordsRequest(HeartRateVariabilityRmssdRecord::class, range, pageToken = token))
                        for (r in page.records)
                            hrv.getOrPut(r.time.atZone(zone).toLocalDate()) { mutableListOf() }.add(r.heartRateVariabilityMillis)
                        token = page.pageToken
                    } while (token != null)
                }
                if (granted.contains(HealthPermission.getReadPermission(RestingHeartRateRecord::class))) {
                    var token: String? = null
                    do {
                        val page = client.readRecords(ReadRecordsRequest(RestingHeartRateRecord::class, range, pageToken = token))
                        for (r in page.records)
                            rhr.getOrPut(r.time.atZone(zone).toLocalDate()) { mutableListOf() }.add(r.beatsPerMinute.toDouble())
                        token = page.pageToken
                    } while (token != null)
                }
                if (granted.contains(HealthPermission.getReadPermission(SleepSessionRecord::class))) {
                    var token: String? = null
                    do {
                        val page = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, range, pageToken = token))
                        for (r in page.records) {
                            // a night counts for the day it ends on
                            val day = r.endTime.atZone(zone).toLocalDate()
                            sleep[day] = (sleep[day] ?: 0L) + ChronoUnit.MINUTES.between(r.startTime, r.endTime)
                        }
                        token = page.pageToken
                    } while (token != null)
                }

                val days = JSONArray()
                val all = (hrv.keys + rhr.keys + sleep.keys).toSortedSet()
                for (d in all) {
                    val o = JSONObject().put("day", d.toString())
                    hrv[d]?.let { o.put("hrv", it.average()) }
                    rhr[d]?.let { o.put("rhr", it.minOrNull() ?: 0.0) }
                    sleep[d]?.let { o.put("sleepMin", it) }
                    days.put(o)
                }
                val any = readPermissions().any { granted.contains(it) }
                latest = JSONObject().put("available", true).put("granted", any).put("days", days).toString()
            } catch (t: Throwable) {
                QLog.w(TAG, "Cannot read from Health Connect", t)
                latest = JSONObject().put("available", true).put("granted", false).put("days", JSONArray()).toString()
            }
        }
    }

    // the answer of the last refresh, once ("" while it is not there)
    @JvmStatic
    fun take(): String {
        val out = latest
        latest = ""
        return out
    }
}
