package com.ufeel.heartrate.presentation
import com.ufeel.heartrate.HeartRateService

import android.Manifest
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts

class MainActivity : ComponentActivity() {

    private lateinit var button: Button

    private val permissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { granted ->
        if (granted[Manifest.permission.BODY_SENSORS] == true) {
            startForegroundService(Intent(this, HeartRateService::class.java))
            button.text = "Stop"
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        button = Button(this).apply {
            text = if (HeartRateService.running) "Stop" else "Start"
            setOnClickListener {
                if (HeartRateService.running) {
                    stopService(Intent(this@MainActivity, HeartRateService::class.java))
                    text = "Start"
                } else {
                    permissions.launch(
                        arrayOf(
                            Manifest.permission.BODY_SENSORS,
                            Manifest.permission.POST_NOTIFICATIONS
                        )
                    )
                }
            }
        }
        setContentView(button, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.CENTER))
    }
}
