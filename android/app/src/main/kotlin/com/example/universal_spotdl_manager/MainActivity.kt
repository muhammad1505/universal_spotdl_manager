package com.example.universal_spotdl_manager

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val methodChannelName = "usm/android_system"
    private val repairLogsChannelName = "usm/termux_repair_logs"

    private var repairLogSink: EventChannel.EventSink? = null
    private val repairExecutor = Executors.newSingleThreadExecutor()
    private val executionCounter = AtomicInteger(1000)

    @Volatile
    private var isRepairRunning: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, repairLogsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    repairLogSink = events
                }

                override fun onCancel(arguments: Any?) {
                    repairLogSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPackageInstalled" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(isPackageInstalled(packageName))
                    }

                    "openPackage" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val opened = openPackage(packageName)
                        result.success(opened)
                    }

                    "repairTermuxEnvironment" -> {
                        if (isRepairRunning) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        isRepairRunning = true
                        result.success(true)
                        repairExecutor.execute {
                            runTermuxRepair()
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun runTermuxRepair() {
        try {
            val termuxPackage = findInstalledTermuxPackage()
            if (termuxPackage == null) {
                emitLog("[error] Termux tidak ditemukan (com.termux/com.termux.nightly)")
                emitDone(false)
                return
            }

            emitLog("[info] Termux package terdeteksi: $termuxPackage")

            val runCommandPermission = "com.termux.permission.RUN_COMMAND"
            val permissionGranted =
                checkSelfPermission(runCommandPermission) == PackageManager.PERMISSION_GRANTED

            if (!permissionGranted) {
                emitLog("[error] Permission com.termux.permission.RUN_COMMAND belum diizinkan")
                emitLog("[hint] Buka Settings > Apps > Universal SpotDL > Permissions > Additional permissions > Run commands in Termux environment")
                emitDone(false)
                return
            }

            emitLog("[info] Menjalankan setup otomatis di Termux (background)")
            emitLog("[hint] Pastikan di Termux: allow-external-apps=true pada ~/.termux/termux.properties")

            emitLog("[precheck 1/2] Validasi bridge RUN_COMMAND ke Termux")
            val bridgeProbe = runTermuxCommand(
                packageName = termuxPackage,
                shellCommand = "echo __USM_TERMUX_BRIDGE_OK__",
                timeoutSeconds = 30
            )
            val bridgeOutput = "${bridgeProbe.stdout}\n${bridgeProbe.stderr}"
            val bridgeMarkerFound = bridgeOutput.contains("__USM_TERMUX_BRIDGE_OK__")

            if (bridgeProbe.stdout.isNotBlank()) {
                emitLogLines("[stdout]", bridgeProbe.stdout)
            }
            if (bridgeProbe.stderr.isNotBlank()) {
                emitLogLines("[stderr]", bridgeProbe.stderr)
            }

            if (!bridgeProbe.success && !bridgeMarkerFound) {
                emitLog("[error] Gagal komunikasi ke Termux. exit=${bridgeProbe.exitCode}, err=${bridgeProbe.errCode}, msg=${bridgeProbe.errMsg}")
                if (looksLikeExternalAppsBlocked(bridgeProbe)) {
                    emitAllowExternalAppsHint()
                }
                emitDone(false)
                return
            }

            emitLog("[precheck 2/2] Validasi allow-external-apps di Termux")
            val allowExternalAppsCheck = runTermuxCommand(
                packageName = termuxPackage,
                shellCommand = """
                    if [ -f ~/.termux/termux.properties ] && grep -Eiq '^[[:space:]]*allow-external-apps[[:space:]]*=[[:space:]]*true([[:space:]]|$)' ~/.termux/termux.properties; then
                      echo "__USM_ALLOW_EXTERNAL_APPS__=true"
                    else
                      echo "__USM_ALLOW_EXTERNAL_APPS__=false"
                    fi
                """.trimIndent(),
                timeoutSeconds = 30
            )

            val allowCheckOutput =
                "${allowExternalAppsCheck.stdout}\n${allowExternalAppsCheck.stderr}".lowercase()
            val allowExternalAppsEnabled = allowCheckOutput.contains("__usm_allow_external_apps__=true")

            if (allowExternalAppsCheck.stdout.isNotBlank()) {
                emitLogLines("[stdout]", allowExternalAppsCheck.stdout)
            }
            if (allowExternalAppsCheck.stderr.isNotBlank()) {
                emitLogLines("[stderr]", allowExternalAppsCheck.stderr)
            }

            if (!allowExternalAppsCheck.success && !allowExternalAppsEnabled) {
                emitLog("[error] Gagal cek allow-external-apps. exit=${allowExternalAppsCheck.exitCode}, err=${allowExternalAppsCheck.errCode}, msg=${allowExternalAppsCheck.errMsg}")
                if (looksLikeExternalAppsBlocked(allowExternalAppsCheck)) {
                    emitAllowExternalAppsHint()
                }
                emitDone(false)
                return
            }

            if (!allowExternalAppsEnabled) {
                emitLog("[error] allow-external-apps belum aktif di Termux")
                emitAllowExternalAppsHint()
                emitDone(false)
                return
            }

            val commands = listOf(
                "pkg update -y",
                "pkg install -y python ffmpeg",
                "python -m pip install -U pip",
                "python -m pip install -U spotdl",
                "python --version",
                "ffmpeg -version | head -n 1",
                "spotdl --version"
            )

            val total = commands.size
            for ((index, command) in commands.withIndex()) {
                emitLog("[step ${index + 1}/$total] $command")
                val result = runTermuxCommand(
                    packageName = termuxPackage,
                    shellCommand = command,
                    timeoutSeconds = if (index < 4) 900 else 120
                )

                if (result.stdout.isNotBlank()) {
                    emitLogLines("[stdout]", result.stdout)
                }
                if (result.stderr.isNotBlank()) {
                    emitLogLines("[stderr]", result.stderr)
                }

                if (!result.success) {
                    emitLog("[error] Command gagal. exit=${result.exitCode}, err=${result.errCode}, msg=${result.errMsg}")
                    if (looksLikeExternalAppsBlocked(result)) {
                        emitAllowExternalAppsHint()
                    }
                    emitDone(false)
                    return
                }
            }

            emitLog("[ok] Setup environment Termux selesai")
            emitDone(true)
        } catch (e: Exception) {
            emitLog("[error] Repair crash: ${e.message}")
            emitDone(false)
        } finally {
            isRepairRunning = false
        }
    }

    private fun runTermuxCommand(
        packageName: String,
        shellCommand: String,
        timeoutSeconds: Long
    ): TermuxCommandResult {
        val actionResult = "usm.termux.RESULT.${System.currentTimeMillis()}.${executionCounter.incrementAndGet()}"
        val callbackIntent = Intent(actionResult)

        val requestCode = executionCounter.incrementAndGet()
        val pendingIntentFlags = PendingIntent.FLAG_ONE_SHOT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            callbackIntent,
            pendingIntentFlags
        )

        val latch = CountDownLatch(1)
        val resultHolder = TermuxCommandResult(
            success = false,
            exitCode = -1,
            errCode = -1,
            errMsg = "Timeout waiting result",
            stdout = "",
            stderr = ""
        )

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) {
                    latch.countDown()
                    return
                }

                val bundle = extractPluginResultBundle(intent)
                if (bundle == null) {
                    resultHolder.success = false
                    resultHolder.errMsg = "Result bundle kosong (allow-external-apps mungkin belum aktif)"
                    latch.countDown()
                    return
                }

                resultHolder.stdout = findBundleString(bundle, "STDOUT", "RESULT_STDOUT")
                resultHolder.stderr = findBundleString(bundle, "STDERR", "RESULT_STDERR")
                resultHolder.exitCode = findBundleInt(
                    bundle,
                    -1,
                    "EXIT_CODE",
                    "EXITCODE",
                    "RESULT_EXIT_CODE"
                )
                resultHolder.errCode = findBundleInt(
                    bundle,
                    -1,
                    "_ERR",
                    "ERR",
                    "ERR_CODE",
                    "ERROR_CODE",
                    "RESULT_ERR"
                )
                resultHolder.errMsg = findBundleString(
                    bundle,
                    "ERRMSG",
                    "ERR_MSG",
                    "ERROR_MESSAGE"
                )

                resultHolder.success = resultHolder.exitCode == 0 &&
                    (resultHolder.errCode == -1 || resultHolder.errCode == 0 || resultHolder.errCode == ActivityResultOk)

                if (!resultHolder.success && resultHolder.errMsg.isBlank()) {
                    val keys = bundle.keySet().joinToString(",")
                    resultHolder.errMsg = "Result keys: $keys"
                }

                latch.countDown()
            }
        }

        try {
            val filter = IntentFilter(actionResult)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(receiver, filter)
            }

            val intent = Intent().apply {
                val termuxPrefix = "/data/data/$packageName/files/usr"
                val termuxHome = "/data/data/$packageName/files/home"
                val preparedCommand =
                    "export PREFIX='$termuxPrefix'; " +
                        "export PATH='$termuxPrefix/bin':\$PATH; " +
                        shellCommand

                setClassName(packageName, "com.termux.app.RunCommandService")
                action = "com.termux.RUN_COMMAND"
                putExtra("com.termux.RUN_COMMAND_PATH", "$termuxPrefix/bin/bash")
                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", preparedCommand))
                putExtra("com.termux.RUN_COMMAND_WORKDIR", termuxHome)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pendingIntent)
            }

            startService(intent)

            val completed = latch.await(timeoutSeconds, TimeUnit.SECONDS)
            if (!completed) {
                resultHolder.success = false
                resultHolder.errMsg = "Timeout setelah $timeoutSeconds detik"
            }
        } catch (se: SecurityException) {
            resultHolder.success = false
            resultHolder.errMsg = "SecurityException: ${se.message}"
        } catch (e: Exception) {
            resultHolder.success = false
            resultHolder.errMsg = "Exception: ${e.message}"
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
            pendingIntent.cancel()
        }

        return resultHolder
    }

    private fun extractPluginResultBundle(intent: Intent): Bundle? {
        val extras = intent.extras ?: return null

        for (key in extras.keySet()) {
            if (key.contains("PLUGIN_RESULT_BUNDLE", ignoreCase = true) ||
                key.contains("plugin_result_bundle", ignoreCase = true)
            ) {
                val bundle = extras.getBundle(key)
                if (bundle != null) return bundle
            }
        }

        return extras
    }

    private fun findBundleString(bundle: Bundle, vararg keyParts: String): String {
        val normalizedKeyParts = keyParts.map { normalizeBundleKey(it) }
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (normalizedKeyParts.any { normalized.contains(it) }) {
                return bundle.getString(key) ?: bundle.get(key)?.toString().orEmpty()
            }
        }
        return ""
    }

    private fun findBundleInt(bundle: Bundle, defaultValue: Int, vararg keyParts: String): Int {
        val normalizedKeyParts = keyParts.map { normalizeBundleKey(it) }
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (normalizedKeyParts.any { normalized.contains(it) }) {
                val value = bundle.get(key)
                when (value) {
                    is Int -> return value
                    is Long -> return value.toInt()
                    is String -> {
                        val parsed = value.toIntOrNull()
                        if (parsed != null) {
                            return parsed
                        }
                    }
                }
            }
        }
        return defaultValue
    }

    private fun normalizeBundleKey(raw: String): String {
        return raw.lowercase().filter { it.isLetterOrDigit() }
    }

    private fun looksLikeExternalAppsBlocked(result: TermuxCommandResult): Boolean {
        val detail = "${result.errMsg}\n${result.stderr}\n${result.stdout}".lowercase()
        return detail.contains("allow-external-apps") ||
            detail.contains("external app") ||
            detail.contains("result bundle kosong") ||
            detail.contains("timeout waiting result") ||
            (result.exitCode == -1 && result.errCode == -1)
    }

    private fun emitAllowExternalAppsHint() {
        emitLog("[hint] Aktifkan allow-external-apps di Termux:")
        emitLog("[hint] 1) buka Termux")
        emitLog("[hint] 2) jalankan: mkdir -p ~/.termux")
        emitLog("[hint] 3) jalankan: echo 'allow-external-apps=true' >> ~/.termux/termux.properties")
        emitLog("[hint] 4) jalankan: termux-reload-settings")
        emitLog("[hint] 5) force close Universal SpotDL lalu coba Repair lagi")
    }

    private fun emitLogLines(prefix: String, raw: String) {
        val lines = raw.lines().filter { it.isNotBlank() }
        val bounded = if (lines.size > 20) lines.takeLast(20) else lines
        for (line in bounded) {
            emitLog("$prefix $line")
        }
    }

    private fun emitLog(message: String) {
        runOnUiThread {
            repairLogSink?.success(message)
        }
    }

    private fun emitDone(success: Boolean) {
        runOnUiThread {
            repairLogSink?.success("__DONE__:${if (success) "success" else "failed"}")
        }
    }

    private fun findInstalledTermuxPackage(): String? {
        val candidates = listOf("com.termux", "com.termux.nightly")
        for (candidate in candidates) {
            if (isPackageInstalled(candidate)) {
                return candidate
            }
        }
        return null
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openPackage(packageName: String): Boolean {
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                false
            } else {
                startActivity(launchIntent)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private class TermuxCommandResult(
        var success: Boolean,
        var exitCode: Int,
        var errCode: Int,
        var errMsg: String,
        var stdout: String,
        var stderr: String
    )

    companion object {
        private const val ActivityResultOk = -1
    }
}
