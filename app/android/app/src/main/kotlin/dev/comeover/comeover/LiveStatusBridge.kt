package dev.comeover.comeover

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * Android 16 Live Updates ("promoted ongoing" notifications) with a normal
 * ongoing-notification fallback on older releases.
 *
 * Pixel, Samsung One UI 8+ (Now Bar) and other Android 16 skins all render the
 * same notification; no vendor SDK is involved.
 */
class LiveStatusBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "dev.comeover/live_status")
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
            "hasPermission" -> result.success(notificationsEnabled())
            "requestPermission" -> requestNotifications(result)
            "start", "update" -> {
                val snapshot = Snapshot.from(call.arguments as? Map<*, *>)
                result.success(snapshot != null && post(snapshot))
            }
            "end" -> {
                cancel()
                result.success(true)
            }
            "openSettings" -> {
                openSettings()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(granted)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || notificationsEnabled()) {
            result.success(notificationsEnabled())
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST,
        )
    }

    private fun notificationsEnabled(): Boolean {
        val manager = activity.getSystemService(NotificationManager::class.java)
        return manager?.areNotificationsEnabled() == true
    }

    private fun post(snapshot: Snapshot): Boolean {
        if (!notificationsEnabled()) return false
        ensureChannel()

        val manager = activity.getSystemService(NotificationManager::class.java) ?: return false
        val open = PendingIntent.getActivity(
            activity,
            0,
            Intent(activity, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val mint = activity.getColor(R.color.live_status_mint)
        val action = Notification.Action.Builder(
            Icon.createWithResource(activity, R.drawable.ic_live_status),
            "Open ComeOver",
            open,
        ).build()

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(activity, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(activity)
                .setPriority(Notification.PRIORITY_DEFAULT)
                .setSound(null)
        }
        builder
            .setSmallIcon(R.drawable.ic_live_status)
            .setContentTitle(snapshot.title)
            .setContentText(snapshot.subtitle)
            .setSubText("ComeOver · ${snapshot.roomCode}")
            .setContentIntent(open)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setColor(mint)
            .setShowWhen(false)
            .addAction(action)

        val arrival = snapshot.arrivalAt
        if (arrival != null && arrival > System.currentTimeMillis() && snapshot.phase != "arrived") {
            // The system ticks the countdown itself, so the lock screen keeps
            // moving even if a background update is delayed.
            builder.setWhen(arrival)
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(true)
            builder.setShowWhen(true)
        }

        val progress = (snapshot.progress * 100).roundToInt().coerceIn(0, 100)
        val chip = snapshot.shortText.ifBlank { "Live" }
        if (Build.VERSION.SDK_INT >= 36) {
            val style = Notification.ProgressStyle()
                .setStyledByProgress(true)
                .setProgress(progress)
                .setProgressTrackerIcon(Icon.createWithResource(activity, R.drawable.ic_live_status))
                .addProgressSegment(Notification.ProgressStyle.Segment(100).setColor(mint))
            builder.setStyle(style)
            builder.setShortCriticalText(chip)
            // setRequestPromotedOngoing() is API 36.1; this string extra is the
            // stable way to request promotion when compiling against API 36.
            builder.addExtras(Bundle().apply {
                putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true)
            })
        } else {
            builder.setStyle(Notification.BigTextStyle().bigText(snapshot.subtitle))
            builder.setProgress(100, progress, false)
        }

        manager.notify(NOTIFICATION_ID, builder.build())
        return true
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = activity.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Live arrival",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Ongoing arrival countdown while a room is open."
            setShowBadge(false)
            enableVibration(false)
            enableLights(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun cancel() {
        activity.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    }

    private fun openSettings() {
        val manager = activity.getSystemService(NotificationManager::class.java)
        val promoted = Build.VERSION.SDK_INT >= 36 && manager?.canPostPromotedNotifications() == false
        val intent = if (promoted) {
            Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
        }
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            activity.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${activity.packageName}")
                },
            )
        }
    }

    private data class Snapshot(
        val phase: String,
        val title: String,
        val subtitle: String,
        val shortText: String,
        val roomCode: String,
        val progress: Float,
        val arrivalAt: Long?,
    ) {
        companion object {
            fun from(raw: Map<*, *>?): Snapshot? {
                val title = raw?.get("title") as? String ?: return null
                return Snapshot(
                    phase = raw["phase"] as? String ?: "waiting",
                    title = title,
                    subtitle = raw["subtitle"] as? String ?: "",
                    shortText = raw["shortText"] as? String ?: "",
                    roomCode = raw["roomCode"] as? String ?: "",
                    progress = (raw["progress"] as? Number)?.toFloat() ?: 0f,
                    arrivalAt = (raw["arrivalAt"] as? Number)?.toLong(),
                )
            }
        }
    }

    companion object {
        private const val CHANNEL_ID = "comeover_live_status"
        private const val NOTIFICATION_ID = 4701
        private const val PERMISSION_REQUEST = 4702
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    }
}
