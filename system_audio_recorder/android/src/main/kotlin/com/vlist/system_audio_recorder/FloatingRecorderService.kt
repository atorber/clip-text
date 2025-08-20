package com.vlist.system_audio_recorder

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
import android.widget.LinearLayout

class FloatingRecorderService : Service() {
    private var windowManager: WindowManager? = null
    private var floatView: View? = null
    private var handler: Handler? = null
    private var seconds = 0
    private var running = false
    private var timerRunnable: Runnable? = null
    private var isRecording = false
    private var isShowingQuestion = false

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
            .setContentTitle("录音悬浮窗")
            .setContentText("可通过悬浮窗控制录音")
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
        val startBtn = floatView?.findViewById<Button>(R.id.btn_start)
        val stopBtn = floatView?.findViewById<Button>(R.id.btn_stop)
        val questionLayout = floatView?.findViewById<LinearLayout>(R.id.ll_question)
        val yesBtn = floatView?.findViewById<Button>(R.id.btn_yes)
        val noBtn = floatView?.findViewById<Button>(R.id.btn_no)
        
        // 初始化状态
        updateButtonStates()
        updateTimerDisplay()
        hideQuestionDialog()

        startBtn?.setOnClickListener {
            if (!isRecording && !isShowingQuestion) {
                startRecording()
            }
        }

        stopBtn?.setOnClickListener {
            if (isRecording) {
                stopRecording()
            } else if (isShowingQuestion) {
                // 如果正在显示询问对话框，关闭悬浮窗
                stopSelf()
            } else {
                // 如果未在录音，关闭悬浮窗
                stopSelf()
            }
        }

        yesBtn?.setOnClickListener {
            // 用户选择去录音列表查看
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            // 添加特殊标记，表示需要直接跳转到录音列表页面
            launchIntent?.putExtra("go_to_recordings_list", true)
            startActivity(launchIntent)
            // 关闭悬浮窗
            stopSelf()
        }

        noBtn?.setOnClickListener {
            // 用户选择不去录音列表，恢复悬浮窗初始状态
            resetToInitialState()
        }
    }

    private fun startRecording() {
        if (isRecording) return
        
        Log.d("FloatingRecorderService", "startRecording called, isRecording: $isRecording")
        
        isRecording = true
        running = true
        seconds = 0
        isShowingQuestion = false
        updateButtonStates()
        updateTimerDisplay()
        hideQuestionDialog()
        
        Log.d("FloatingRecorderService", "About to send start event to Flutter")
        
        // 通知Flutter端开始录音
        try {
            SystemAudioRecorderPlugin.sendEventToFlutter("start")
            Log.d("FloatingRecorderService", "Start event sent to Flutter successfully")
        } catch (e: Exception) {
            Log.e("FloatingRecorderService", "Failed to send start event to Flutter: ${e.message}")
        }
        
        // 启动计时器
        timerRunnable = object : Runnable {
            override fun run() {
                if (running) {
                    seconds++
                    updateTimerDisplay()
                    handler?.postDelayed(this, 1000)
                }
            }
        }
        handler?.post(timerRunnable!!)
        
        Log.d("FloatingRecorderService", "Recording started, timer started, seconds: $seconds")
    }

    private fun stopRecording() {
        if (!isRecording) return
        
        Log.d("FloatingRecorderService", "stopRecording called, isRecording: $isRecording")
        
        isRecording = false
        running = false
        updateButtonStates()
        updateTimerDisplay()
        
        // 停止计时器
        timerRunnable?.let { handler?.removeCallbacks(it) }
        timerRunnable = null
        
        Log.d("FloatingRecorderService", "About to send stop event to Flutter")
        
        // 先通知Flutter端停止录音，确保文件被保存
        try {
            SystemAudioRecorderPlugin.sendEventToFlutter("stop")
            Log.d("FloatingRecorderService", "Stop event sent to Flutter successfully")
        } catch (e: Exception) {
            Log.e("FloatingRecorderService", "Failed to send stop event to Flutter: ${e.message}")
        }
        
        // 延迟显示询问对话框，给Flutter端时间保存文件
        handler?.postDelayed({
            Log.d("FloatingRecorderService", "Showing question dialog after delay")
            showQuestionDialog()
            Log.d("FloatingRecorderService", "Question dialog shown after recording stop")
        }, 1000) // 延迟1秒，确保文件保存完成
        
        Log.d("FloatingRecorderService", "Recording stopped, will show question dialog")
    }

    private fun showQuestionDialog() {
        isShowingQuestion = true
        val questionLayout = floatView?.findViewById<LinearLayout>(R.id.ll_question)
        questionLayout?.visibility = View.VISIBLE
        updateButtonStates()
    }

    private fun hideQuestionDialog() {
        isShowingQuestion = false
        val questionLayout = floatView?.findViewById<LinearLayout>(R.id.ll_question)
        questionLayout?.visibility = View.GONE
        updateButtonStates()
    }

    private fun resetToInitialState() {
        isShowingQuestion = false
        hideQuestionDialog()
        updateButtonStates()
        updateTimerDisplay()
        Log.d("FloatingRecorderService", "Reset to initial state")
    }

    private fun updateButtonStates() {
        val startBtn = floatView?.findViewById<Button>(R.id.btn_start)
        val stopBtn = floatView?.findViewById<Button>(R.id.btn_stop)
        
        if (isShowingQuestion) {
            // 显示询问对话框时，隐藏开始和停止按钮
            startBtn?.visibility = View.GONE
            stopBtn?.visibility = View.GONE
        } else if (isRecording) {
            // 录音中
            startBtn?.isEnabled = false
            startBtn?.visibility = View.VISIBLE
            stopBtn?.text = "停止"
            stopBtn?.backgroundTintList = android.content.res.ColorStateList.valueOf(android.graphics.Color.parseColor("#E53935"))
            stopBtn?.visibility = View.VISIBLE
        } else {
            // 初始状态
            startBtn?.isEnabled = true
            startBtn?.visibility = View.VISIBLE
            stopBtn?.text = "关闭"
            stopBtn?.backgroundTintList = android.content.res.ColorStateList.valueOf(android.graphics.Color.parseColor("#757575"))
            stopBtn?.visibility = View.VISIBLE
        }
    }

    private fun updateTimerDisplay() {
        val timerText = floatView?.findViewById<TextView>(R.id.tv_timer)
        if (isRecording) {
            val min = seconds / 60
            val sec = seconds % 60
            timerText?.text = String.format("%02d:%02d", min, sec)
        } else {
            timerText?.text = "00:00"
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