package com.example.system_audio_recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log

class MediaProjectionService : Service() {
    private val CHANNEL_ID = "media_projection"
    private val TAG = "MediaProjectionService"
    inner class LocalBinder : Binder() {
        fun getService(): MediaProjectionService = this@MediaProjectionService
    }
    private val binder = LocalBinder()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate called")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "系统音频录制",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called, intent=$intent, flags=$flags, startId=$startId")
        try {
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("系统音频录制中")
            .setContentText("正在录制系统音频...")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()
        startForeground(1, notification)
            Log.d(TAG, "startForeground success")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}", e)
            throw e
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.d(TAG, "onBind called, intent=$intent")
        return binder
    }
}