package com.ufeel.heartrate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.IBinder
import android.os.PowerManager
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.Executors

private const val TARGET = "255.255.255.255"
private const val PORT = 9999

class HeartRateService : Service() {

    companion object {
        @Volatile
        var running = false
    }

    private val io = Executors.newSingleThreadExecutor()
    private var socket: DatagramSocket? = null
    private lateinit var cm: ConnectivityManager
    private lateinit var wakeLock: PowerManager.WakeLock
    private val exercise by lazy { HealthServices.getClient(this).exerciseClient }

    private val wifi = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            io.execute {
                socket?.close()
                socket = DatagramSocket().also { network.bindSocket(it) }
            }
        }

        override fun onLost(network: Network) {
            io.execute {
                socket?.close()
                socket = null
            }
        }
    }

    private val heartRate = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val bpm = update.latestMetrics.getData(DataType.HEART_RATE_BPM)
                .lastOrNull()?.value?.toInt() ?: return
            send(bpm)
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
        override fun onRegistered() {}
        override fun onRegistrationFailed(throwable: Throwable) {}
        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
    }

    private fun send(bpm: Int) = io.execute {
        val s = socket ?: return@execute
        val bytes = bpm.toString().toByteArray()
        runCatching {
            s.send(DatagramPacket(bytes, bytes.size, InetAddress.getByName(TARGET), PORT))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (running) return START_NOT_STICKY
        running = true

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(
                NotificationChannel("hr", "Heart rate", NotificationManager.IMPORTANCE_LOW)
            )
        startForeground(
            1,
            Notification.Builder(this, "hr")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setContentTitle("Streaming heart rate")
                .build(),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
        )

        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ufeel:hr")
            .apply { acquire() }

        cm = getSystemService(ConnectivityManager::class.java)
        cm.requestNetwork(
            NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build(),
            wifi
        )

        exercise.setUpdateCallback(heartRate)
        exercise.startExerciseAsync(
            ExerciseConfig.builder(ExerciseType.WORKOUT)
                .setDataTypes(setOf(DataType.HEART_RATE_BPM))
                .setIsAutoPauseAndResumeEnabled(false)
                .setIsGpsEnabled(false)
                .build()
        )
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (running) {
            exercise.endExerciseAsync()
            exercise.clearUpdateCallbackAsync(heartRate)
            cm.unregisterNetworkCallback(wifi)
            io.execute { socket?.close(); socket = null }
            io.shutdown()
            wakeLock.release()
            running = false
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
