package com.example.new_flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.content.pm.PackageManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.view.Gravity
import android.view.ViewGroup.LayoutParams
import io.flutter.embedding.android.FlutterActivity
import android.widget.Toast
import android.util.Log

class MainActivity : FlutterActivity() {

    companion object {
        private const val MANAGE_STORAGE_PERMISSION_REQUEST_CODE = 101
        private const val UPDATE_PROGRESS_ACTION = "com.example.new_flutter_app.UPDATE_PROGRESS"
        private const val TAG = "MainActivity"  // ログ出力用タグ
    }

    private lateinit var progressTextView: TextView
    private lateinit var startButton: Button

    private val progressReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val progress = intent?.getStringExtra("progress") ?: "不明な進捗状況"
            updateProgress(progress)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        }

        progressTextView = TextView(this).apply {
            text = "アプリ起動！おめでとうございます！"
            textSize = 20f
            layoutParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        }
        layout.addView(progressTextView)

        startButton = Button(this).apply {
            text = "バックグラウンド開始"
            layoutParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        }
        layout.addView(startButton)

        setContentView(layout)

        startButton.setOnClickListener {
            if (ActivityCompat.checkSelfPermission(
                    this,
                    android.Manifest.permission.MANAGE_EXTERNAL_STORAGE
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions()
            } else {
                startBackgroundService()
            }
        }
    }

    private fun requestPermissions() {
        Log.d(TAG, "権限リクエストを送信")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!android.os.Environment.isExternalStorageManager()) {
                navigateToSettings()
            } else {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.MANAGE_EXTERNAL_STORAGE),
                    MANAGE_STORAGE_PERMISSION_REQUEST_CODE
                )
            }
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                MANAGE_STORAGE_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun navigateToSettings() {
        Log.d(TAG, "設定画面に遷移")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }

    private fun startBackgroundService() {
        try {
            Log.d(TAG, "バックグラウンドサービスを開始")
            val intent = Intent(this, MyBackgroundService::class.java)
            ContextCompat.startForegroundService(this, intent)
            progressTextView.text = "バックグラウンドで処理を開始しました。"
        } catch (e: Exception) {
            Log.e(TAG, "バックグラウンドサービスの開始に失敗", e)
            progressTextView.text = "バックグラウンドサービスを開始できません: ${e.message}"
        }
    }

    private fun updateProgress(progress: String) {
        runOnUiThread {
            progressTextView.text = "進捗状況: $progress"
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MANAGE_STORAGE_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "権限が許可されたのでサービスを開始")
                startBackgroundService()
                progressTextView.text = "権限が許可され、バックグラウンド処理を開始しました。"
            } else {
                Log.d(TAG, "権限が拒否された")
                progressTextView.text = "権限が必要です。設定画面から権限を許可してください。"
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (android.os.Environment.isExternalStorageManager()) {
                Log.d(TAG, "ストレージ権限が許可されているのでサービスを再確認")
                startBackgroundService()
                progressTextView.text = "バックグラウンド処理を開始しました。"
            }
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(UPDATE_PROGRESS_ACTION)
        registerReceiver(progressReceiver, filter)
    }

    override fun onStop() {
        super.onStop()
        unregisterReceiver(progressReceiver)
    }
}
