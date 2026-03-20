package com.example.ui

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.LayoutInflater
import android.widget.Button
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.graphics.PixelFormat
import com.example.ui.R
import android.app.AlertDialog
import android.os.Handler
import android.os.Looper
import android.widget.TextView

class ScreenshotActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mpm.createScreenCaptureIntent(), 1001)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 1001) {
            // Call back to FloatingWidgetService
            val service = FloatingWidgetService.instance
            service?.onMediaProjectionPermissionResult(resultCode, data)
        }
        finish()
    }
}
