package com.example.ui

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.graphics.Bitmap
import android.util.DisplayMetrics
import android.os.Handler
import android.os.Looper
import android.app.AlertDialog
import android.widget.Button
import android.content.pm.PackageManager
import android.app.Activity
import android.content.ComponentName
import android.hardware.display.DisplayManager
import java.io.File
import java.io.FileOutputStream

class FloatingWidgetService : Service() {
    companion object {
        var instance: FloatingWidgetService? = null
    }
    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var methodChannel: MethodChannel? = null

    // 1. Add fields for MediaProjection, overlays, and state
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureTarget: String = "current_app"
    private var overlayView: View? = null
    private var countdownHandler: Handler? = null
    private var countdownRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addFloatingWidget()
        setupFlutterChannel()
    }

    private fun setupFlutterChannel() {
        val engine = FlutterEngineCache.getInstance().get("my_engine_id")
        if (engine != null) {
            methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "floating_widget_channel")
        }
    }

    private fun addFloatingWidget() {
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val resId = resources.getIdentifier("floating_widget", "layout", packageName)
        floatingView = inflater.inflate(resId, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 100

        windowManager.addView(floatingView, params)

        // Drag and move
        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager.updateViewLayout(floatingView, params)
                        return true
                    }
                }
                return false
            }
        })

        // Collapsed and expanded views
        val geminiBtn = floatingView?.findViewById<ImageButton>(resources.getIdentifier("btn_gemini", "id", packageName))
        val expandedLayout = floatingView?.findViewById<View>(resources.getIdentifier("expanded_buttons", "id", packageName))

        geminiBtn?.setOnClickListener {
            geminiBtn.visibility = View.GONE
            expandedLayout?.visibility = View.VISIBLE
        }

        // OCR Button
        val ocrBtn = floatingView?.findViewById<ImageButton>(resources.getIdentifier("btn_ocr", "id", packageName))
        ocrBtn?.setOnClickListener {
            startScreenshotFlow()
        }

        // Camera Button
        val camBtn = floatingView?.findViewById<ImageButton>(resources.getIdentifier("btn_camera", "id", packageName))
        camBtn?.setOnClickListener {
            // Bring app to foreground
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)

            // Give the app a moment to come to foreground, then send the event
            floatingView?.postDelayed({
                methodChannel?.invokeMethod("openCamera", null)
            }, 500) // 500ms delay
        }

        // Close Button
        val closeBtn = floatingView?.findViewById<ImageButton>(resources.getIdentifier("btn_close", "id", packageName))
        closeBtn?.setOnClickListener {
            stopSelf()
        }

        // Upload Image Button
        val uploadBtn = floatingView?.findViewById<ImageButton>(resources.getIdentifier("btn_upload", "id", packageName))
        uploadBtn?.setOnClickListener {
            methodChannel?.invokeMethod("onUploadImage", null)
        }
    }

    // 2. Add method to show screen selection overlay
    private fun showScreenshotChoiceOverlay() {
        val inflater = LayoutInflater.from(this)
        val overlay = inflater.inflate(R.layout.screenshot_choice_dialog, null)
        overlayView = overlay
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        windowManager.addView(overlay, params)
        overlay.findViewById<Button>(R.id.btn_current_app).setOnClickListener {
            captureTarget = "current_app"
            removeOverlay()
            startMediaProjectionPermission()
        }
        overlay.findViewById<Button>(R.id.btn_another_app).setOnClickListener {
            captureTarget = "another_app"
            removeOverlay()
            startMediaProjectionPermission()
        }
        overlay.findViewById<Button>(R.id.btn_home_screen).setOnClickListener {
            captureTarget = "home_screen"
            removeOverlay()
            startMediaProjectionPermission()
        }
    }

    private fun removeOverlay() {
        overlayView?.let { windowManager.removeView(it) }
        overlayView = null
    }

    // 3. Add method to start MediaProjection permission (via hidden activity)
    private fun startMediaProjectionPermission() {
        // TODO: Implement MediaProjectionPermissionActivity as a hidden activity to request permission
        val intent = Intent(this, MediaProjectionPermissionActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // 4. Add method to be called by MediaProjectionPermissionActivity with result
    fun onMediaProjectionPermissionResult(resultCode: Int, data: Intent?) {
        if (resultCode == Activity.RESULT_OK && data != null) {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mpm.getMediaProjection(resultCode, data)
            if (captureTarget == "current_app") {
                takeScreenshot()
            } else {
                showCountdownAndTakeScreenshot()
            }
        }
    }

    private fun showCountdownAndTakeScreenshot() {
        val inflater = LayoutInflater.from(this)
        val overlay = inflater.inflate(R.layout.floating_capture_button, null)
        overlayView = overlay
        val btnCapture = overlay.findViewById<Button>(R.id.btn_capture_now)
        btnCapture.isEnabled = false
        btnCapture.text = "Capturing in 3..."
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        windowManager.addView(overlay, params)
        countdownHandler = Handler(Looper.getMainLooper())
        var seconds = 3
        countdownRunnable = object : Runnable {
            override fun run() {
                if (seconds > 1) {
                    seconds--
                    btnCapture.text = "Capturing in $seconds..."
                    countdownHandler?.postDelayed(this, 1000)
                } else {
                    removeOverlay()
                    takeScreenshot()
                }
            }
        }
        countdownHandler?.postDelayed(countdownRunnable!!, 1000)
        btnCapture.setOnClickListener {
            countdownHandler?.removeCallbacks(countdownRunnable!!)
            removeOverlay()
            takeScreenshot()
        }
    }

    private fun takeScreenshot() {
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi
        imageReader = ImageReader.newInstance(width, height, 0x1, 2)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface, null, null
        )
        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage()
            if (image != null) {
                val planes = image.planes
                val buffer = planes[0].buffer
                val pixelStride = planes[0].pixelStride
                val rowStride = planes[0].rowStride
                val rowPadding = rowStride - pixelStride * width
                val bitmap = Bitmap.createBitmap(
                    width + rowPadding / pixelStride,
                    height, Bitmap.Config.ARGB_8888
                )
                bitmap.copyPixelsFromBuffer(buffer)
                image.close()
                // Save bitmap to file
                val file = File(getExternalFilesDir(null), "screenshot_${System.currentTimeMillis()}.png")
                val fos = FileOutputStream(file)
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)
                fos.flush()
                fos.close()
                // Bring app to foreground
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                startActivity(launchIntent)
                // Send file path to Flutter
                methodChannel?.invokeMethod("onScreenshotPath", file.absolutePath)
            }
        }, null)
    }

    // 5. Add a public method to start the screenshot flow from the floating widget OCR button
    fun startScreenshotFlow() {
        showScreenshotChoiceOverlay()
    }

    // Public method to stop the overlay and service
    fun stopOverlay() {
        floatingView?.let { windowManager.removeView(it) }
        removeOverlay()
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingView?.let { windowManager.removeView(it) }
        removeOverlay()
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        if (instance == this) instance = null
    }
} 