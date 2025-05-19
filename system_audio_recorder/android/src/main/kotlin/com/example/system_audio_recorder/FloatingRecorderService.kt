package com.example.system_audio_recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.annotation.RequiresApi
import android.util.Log

class FloatingRecorderService : Service() {
    private var windowManager: WindowManager? = null
    private var floatView: View? = null
    private var handler: Handler? = null
    private var seconds = 0
    private var running = false
    private var timerRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate() {
        super.onCreate()
        Log.d("FloatingRecorderService", "onCreate called")
        // 前台服务通知
        val channelId = "floating_recorder"
        val channelName = "录音悬浮窗"
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(channelId) == null) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(channel)
        }
        val notification = Notification.Builder(this, channelId)
            .setContentTitle("录音进行中")
            .setContentText("点击悬浮窗可停止录音")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()
        startForeground(1, notification)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        handler = Handler(mainLooper)
        showFloatingWindow()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun showFloatingWindow() {
        Log.d("FloatingRecorderService", "showFloatingWindow called")
        val inflater = LayoutInflater.from(this)
        floatView = inflater.inflate(R.layout.layout_floating_recorder, null)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = 30
        params.y = 100
        windowManager?.addView(floatView, params)

        // 悬浮窗拖动支持
        floatView?.setOnTouchListener(object : View.OnTouchListener {
            var lastX = 0f
            var lastY = 0f
            var paramX = 0
            var paramY = 0
            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        lastX = event.rawX
                        lastY = event.rawY
                        paramX = params.x
                        paramY = params.y
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - lastX).toInt()
                        val dy = (event.rawY - lastY).toInt()
                        params.x = paramX + dx
                        params.y = paramY + dy
                        windowManager?.updateViewLayout(floatView, params)
                    }
                }
                return false
            }
        })

        val timerText = floatView?.findViewById<TextView>(R.id.tv_timer)
        val stopBtn = floatView?.findViewById<Button>(R.id.btn_stop)
        running = true
        seconds = 0
        timerRunnable = object : Runnable {
            override fun run() {
                if (running) {
                    seconds++
                    val min = seconds / 60
                    val sec = seconds % 60
                    timerText?.text = String.format("%02d:%02d", min, sec)
                    handler?.postDelayed(this, 1000)
                }
            }
        }
        handler?.post(timerRunnable!!)

        stopBtn?.setOnClickListener {
            running = false
            // 唤起App到前台
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(launchIntent)
            // 通知Flutter端
            SystemAudioRecorderPlugin.sendEventToFlutter("stop")
            // 关闭悬浮窗Service
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (floatView != null) {
            windowManager?.removeView(floatView)
            floatView = null
        }
        handler?.removeCallbacksAndMessages(null)
    }
} 