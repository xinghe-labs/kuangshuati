package com.kuangshuati.kuangshuati

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.kuangshuati.app/updates"
    private val backupChannelName = "com.kuangshuati.app/backup"
    private val screenChannelName = "com.kuangshuati.app/screen"

    private val pickBackupRequestCode = 0x5B01
    private val saveBackupRequestCode = 0x5B02
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    private fun registerBackupChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backupChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "备份路径为空", null)
                        return@setMethodCallHandler
                    }
                    try {
                        shareBackup(
                            File(path),
                            call.argument<String>("name"),
                            call.argument<String>("mime"),
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("share_failed", error.message, null)
                    }
                }
                "saveFile" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_data", "备份数据为空", null)
                        return@setMethodCallHandler
                    }
                    pendingSaveBytes = bytes
                    pendingSaveResult = result
                    val name = call.argument<String>("name") ?: "kst-backup.gkbackup"
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        startActivityForResult(intent, saveBackupRequestCode)
                    } catch (error: Exception) {
                        pendingSaveBytes = null
                        pendingSaveResult = null
                        result.error("save_failed", error.message, null)
                    }
                }
                "pickFile" -> {
                    pendingPickResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, pickBackupRequestCode)
                    } catch (error: Exception) {
                        pendingPickResult = null
                        result.error("pick_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun shareBackup(file: File, name: String?, mime: String?) {
        require(file.isFile) { "备份文件不存在" }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime ?: "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!name.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, name)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "导出备份"))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickBackupRequestCode) {
            val pending = pendingPickResult
            pendingPickResult = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            val uri = data.data!!
            try {
                val bytes = readBytes(uri)
                pending.success(
                    mapOf(
                        "name" to displayName(uri),
                        "bytes" to bytes,
                    ),
                )
            } catch (error: Exception) {
                pending.error("read_failed", error.message, null)
            }
            return
        }
        if (requestCode == saveBackupRequestCode) {
            val pending = pendingSaveResult
            val bytes = pendingSaveBytes
            pendingSaveResult = null
            pendingSaveBytes = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
                pending.success(false)
                return
            }
            try {
                contentResolver.openOutputStream(data.data!!)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IllegalStateException("无法写入所选位置")
                pending.success(true)
            } catch (error: Exception) {
                pending.error("save_failed", error.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun readBytes(uri: Uri): ByteArray {
        val limit = 128L * 1024L * 1024L
        contentResolver.openInputStream(uri)?.use { stream ->
            val buffer = ByteArrayOutputStream()
            val chunk = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val read = stream.read(chunk)
                if (read <= 0) break
                total += read
                if (total > limit) throw IllegalStateException("备份文件超过 128MB")
                buffer.write(chunk, 0, read)
            }
            return buffer.toByteArray()
        }
        throw IllegalStateException("无法读取所选文件")
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                val name = cursor.getString(index)
                if (!name.isNullOrBlank()) return name
            }
        }
        return uri.lastPathSegment ?: "备份文件"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerBackupChannel(flutterEngine)
        // 做题时屏幕不能息屏：用户读一段长材料（上海卷单题材料常在 300 字
        // 以上）就会超过系统息屏时间（默认 30 秒），屏幕黑掉、需要重新
        // 解锁，作答节奏被直接打断。练习页进入时开、离开时关。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(
                                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                            )
                        } else {
                            window.clearFlags(
                                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                            )
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersion" -> {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(
                        mapOf(
                            "versionName" to (info.versionName ?: "未知"),
                            "versionCode" to info.longVersionCode,
                        ),
                    )
                }
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallPermissionSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName"),
                    )
                    startActivity(intent)
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "APK 路径为空", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(File(path))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("install_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun installApk(apk: File) {
        require(apk.isFile) { "更新文件不存在" }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
