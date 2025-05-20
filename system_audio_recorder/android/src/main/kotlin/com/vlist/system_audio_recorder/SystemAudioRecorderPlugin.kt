package com.vlist.system_audio_recorder

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.*
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class SystemAudioRecorderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel : MethodChannel
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null
    private var mediaProjection: MediaProjection? = null
    private var recorder: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var isRecording = false
    private var outputFilePath: String? = null
    private val REQUEST_CODE = 10086
    private val TAG = "SysAudioRecorder"
    private var savedResultCode: Int = 0
    private var savedData: Intent? = null
    private var isServiceBound = false
    private var serviceConnection: android.content.ServiceConnection? = null
    private val lock = Any() // 新增锁对象

    companion object {
        var staticChannel: MethodChannel? = null
        fun sendEventToFlutter(event: String) {
            staticChannel?.invokeMethod("onFloatingRecorderEvent", event)
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "system_audio_recorder")
        channel.setMethodCallHandler(this)
        staticChannel = channel
        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        staticChannel = null
        Log.d(TAG, "Plugin detached from engine")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "Attached to activity")
        binding.addActivityResultListener { requestCode, resultCode, data ->
            Log.d(TAG, "onActivityResult: requestCode=$requestCode, resultCode=$resultCode, data=$data")
            if (requestCode == REQUEST_CODE && resultCode == Activity.RESULT_OK && data != null) {
                // 1. 启动前台服务
                val serviceIntent = Intent(activity, MediaProjectionService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity!!.startForegroundService(serviceIntent)
                } else {
                    activity!!.startService(serviceIntent)
                }
                // 2. bindService，等待onServiceConnected后再获取MediaProjection
                savedResultCode = resultCode
                savedData = data
                serviceConnection = object : android.content.ServiceConnection {
                    override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {
                        Log.d(TAG, "MediaProjectionService connected, now get MediaProjection")
                        val mgr = activity?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        val localSavedData = savedData
                        if (localSavedData != null) {
                            mediaProjection = mgr.getMediaProjection(savedResultCode, localSavedData)
                        startRecordWithProjection(mediaProjection, pendingResult)
                        } else {
                            Log.e(TAG, "savedData is null, cannot get MediaProjection")
                            pendingResult?.error("NO_PROJECTION", "savedData is null", null)
                        }
                        pendingResult = null
                        // 解绑服务，避免泄漏
                        if (isServiceBound) {
                            activity?.unbindService(this)
                            isServiceBound = false
                        }
                    }
                    override fun onServiceDisconnected(name: android.content.ComponentName?) {
                        Log.d(TAG, "MediaProjectionService disconnected")
                    }
                }
                val bound = activity!!.bindService(serviceIntent, serviceConnection!!, Context.BIND_AUTO_CREATE)
                isServiceBound = bound
                true
            } else {
                Log.e(TAG, "User denied screen capture or data is null")
                pendingResult?.error("NO_PROJECTION", "User denied screen capture", null)
                pendingResult = null
                false
            }
        }
    }
    override fun onDetachedFromActivity() { activity = null; Log.d(TAG, "Detached from activity") }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivityForConfigChanges() { activity = null; Log.d(TAG, "Detached from activity for config changes") }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "startRecord" -> {
                if (activity == null) {
                    Log.e(TAG, "No activity available")
                    result.error("NO_ACTIVITY", "No activity", null)
                    return
                }
                pendingResult = result
                val mgr = activity!!.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val intent = mgr.createScreenCaptureIntent()
                Log.d(TAG, "Launching screen capture intent")
                activity!!.startActivityForResult(intent, REQUEST_CODE)
            }
            "stopRecord" -> {
                Log.d(TAG, "stopRecord called")
                stopRecord(result)
            }
            "listRecordings" -> {
                try {
                    val dir = activity?.cacheDir
                    if (dir == null) {
                        result.error("NO_CACHE_DIR", "cacheDir is null", null)
                        return
                    }
                    val files = dir.listFiles { file -> file.extension == "pcm" }?.map {
                        mapOf(
                            "name" to it.name,
                            "size" to it.length(),
                            "lastModified" to it.lastModified(),
                            "path" to it.absolutePath
                        )
                    } ?: emptyList()
                    Log.d(TAG, "listRecordings: found ${files.size} files")
                    result.success(files)
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in listRecordings: ${e.message}", e)
                    result.error("LIST_FAILED", e.message, null)
                }
            }
            "startFloatingRecorder" -> {
                if (activity == null) {
                    result.error("NO_ACTIVITY", "No activity", null)
                    return
                }
                // 检查悬浮窗权限
                if (!Settings.canDrawOverlays(activity)) {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + activity!!.packageName))
                    activity!!.startActivity(intent)
                    result.error("NO_PERMISSION", "悬浮窗权限未授予", null)
                    return
                }
                val intent = Intent(activity, FloatingRecorderService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity!!.startForegroundService(intent)
                } else {
                    activity!!.startService(intent)
                }
                // 最小化APP
                activity!!.moveTaskToBack(true)
                result.success(null)
            }
            "stopFloatingRecorder" -> {
                if (activity == null) {
                    result.error("NO_ACTIVITY", "No activity", null)
                    return
                }
                val intent = Intent(activity, FloatingRecorderService::class.java)
                activity!!.stopService(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startRecordWithProjection(mediaProjection: MediaProjection?, result: MethodChannel.Result?) {
        // 新增：录音前清理残留资源
        synchronized(lock) {
            try {
                isRecording = false
                recordingThread?.let {
                    try { it.join(500) } catch (_: Exception) {}
                }
                try { recorder?.stop() } catch (_: Exception) {}
                try { recorder?.release() } catch (_: Exception) {}
                recorder = null
                recordingThread = null
                outputFilePath = null
            } catch (_: Exception) {}
        }
        if (mediaProjection == null) {
            Log.e(TAG, "MediaProjection is null, cannot start recording")
            result?.error("NO_PROJECTION", "MediaProjection is null", null)
            return
        }
        try {
            val audioFormat = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(44100)
                .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                .build()

            val bufferSize = AudioRecord.getMinBufferSize(
                44100,
                AudioFormat.CHANNEL_IN_STEREO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            val config = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .build()

            recorder = AudioRecord.Builder()
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(bufferSize)
                .setAudioPlaybackCaptureConfig(config)
                .build()

            val file = File(activity?.cacheDir, "system_record_${System.currentTimeMillis()}.pcm")
            outputFilePath = file.absolutePath

            recorder?.startRecording()
            isRecording = true
            Log.d(TAG, "Recording started, file: $outputFilePath")

            recordingThread = Thread {
                try {
                val os = FileOutputStream(file)
                val buffer = ByteArray(bufferSize)
                while (isRecording) {
                    val read = recorder?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        os.write(buffer, 0, read)
                    }
                }
                os.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in recordingThread: ${e.message}", e)
                }
                Log.d(TAG, "Recording thread finished")
                // 新增：线程结束时重置变量
                synchronized(lock) {
                    recordingThread = null
                }
            }
            recordingThread?.start()
            result?.success(outputFilePath)
        } catch (e: Exception) {
            Log.e(TAG, "Exception in startRecordWithProjection: ${e.message}", e)
            result?.error("START_FAILED", e.message, null)
        }
    }

    private fun stopRecord(result: MethodChannel.Result) {
        synchronized(lock) {
        try {
                if (!isRecording) {
                    Log.w(TAG, "stopRecord called but not recording")
                    result.success(outputFilePath)
                    outputFilePath = null // 新增
                    return
                }
            isRecording = false
                // 等待录音线程退出
                recordingThread?.let {
                    try {
                        it.join(1000) // 最多等1秒
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception while waiting for recordingThread to finish: ${e.message}", e)
                    }
                }
                try {
            recorder?.stop()
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in recorder.stop(): ${e.message}", e)
                }
                try {
            recorder?.release()
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in recorder.release(): ${e.message}", e)
                }
            recorder = null
            recordingThread = null
            Log.d(TAG, "Recording stopped, file: $outputFilePath")
            result.success(outputFilePath)
                outputFilePath = null // 新增
        } catch (e: Exception) {
            Log.e(TAG, "Exception in stopRecord: ${e.message}", e)
            result.error("STOP_FAILED", e.message, null)
                outputFilePath = null // 新增
            }
        }
    }
}