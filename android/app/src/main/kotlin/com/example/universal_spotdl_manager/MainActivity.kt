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

                    "executeTermuxCommand" -> {
                        val command = call.argument<String>("command")
                        val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 300
                        if (command.isNullOrBlank()) {
                            result.error("INVALID_ARG", "command is required", null)
                            return@setMethodCallHandler
                        }

                        // Run on background thread to avoid blocking the UI thread
                        repairExecutor.execute {
                            val termuxPackage = findInstalledTermuxPackage()
                            if (termuxPackage == null) {
                                runOnUiThread {
                                    result.error("TERMUX_NOT_FOUND", "Termux not installed", null)
                                }
                                return@execute
                            }

                            val cmdResult = runTermuxCommand(
                                packageName = termuxPackage,
                                shellCommand = command,
                                timeoutSeconds = timeoutSeconds.toLong()
                            )

                            runOnUiThread {
                                result.success(mapOf(
                                    "stdout" to cmdResult.stdout,
                                    "stderr" to cmdResult.stderr,
                                    "exitCode" to cmdResult.exitCode,
                                    "errCode" to cmdResult.errCode,
                                    "errMsg" to cmdResult.errMsg,
                                    "success" to cmdResult.success
                                ))
                            }
                        }
                    }

                    "findTermuxPackage" -> {
                        val pkg = findInstalledTermuxPackage()
                        result.success(pkg)
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
            val termuxVersion = getPackageVersionName(termuxPackage)
            if (!termuxVersion.isNullOrBlank()) {
                emitLog("[info] Termux version: $termuxVersion")
            }

            if (!isVersionAtLeast(termuxVersion, 0, 109)) {
                emitLog("[error] Versi Termux terlalu lama untuk result callback RUN_COMMAND")
                emitLog("[hint] Update Termux ke versi >= 0.109 (disarankan dari F-Droid/GitHub resmi)")
                emitDone(false)
                return
            }

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
            val bridgeAckOnly = bridgeProbe.callbackResultCode == ActivityResultOk &&
                bridgeProbe.exitCode == -1

            if (bridgeProbe.stdout.isNotBlank()) {
                emitLogLines("[stdout]", bridgeProbe.stdout)
            }
            if (bridgeProbe.stderr.isNotBlank()) {
                emitLogLines("[stderr]", bridgeProbe.stderr)
            }

            emitLog("[debug] bridge: success=${bridgeProbe.success}, exit=${bridgeProbe.exitCode}, err=${bridgeProbe.errCode}, ack=${bridgeAckOnly}, marker=${bridgeMarkerFound}, minimal=${bridgeProbe.minimalPayloadOnly}")

            // Hard fail ONLY if no callback was received at all (timeout/security error)
            if (!bridgeProbe.success && !bridgeMarkerFound && !bridgeAckOnly) {
                val errMsg = bridgeProbe.errMsg
                if (errMsg.contains("Timeout", ignoreCase = true) ||
                    errMsg.contains("SecurityException", ignoreCase = true)
                ) {
                    emitLog("[error] Gagal komunikasi ke Termux: ${bridgeProbe.errMsg}")
                    if (looksLikeExternalAppsBlocked(bridgeProbe)) {
                        emitAllowExternalAppsHint()
                    }
                    emitDone(false)
                    return
                }
                // Got a callback but with unexpected data — log warning and try to proceed
                emitLog("[warn] Bridge callback tidak standar. exit=${bridgeProbe.exitCode}, err=${bridgeProbe.errCode}, msg=${bridgeProbe.errMsg}")
                emitLog("[warn] Mencoba lanjut ke setup command...")
            }

            if (bridgeAckOnly && bridgeProbe.minimalPayloadOnly) {
                // Termux acknowledged the command but didn't return output.
                // This is common on some Termux versions or when result bundle is minimal.
                // Instead of failing, proceed to setup commands.
                emitLog("[warn] Callback Termux hanya berisi key 'result'. Ini normal pada beberapa versi Termux.")
                emitLog("[info] Melanjutkan setup tanpa validasi output...")
            } else if (bridgeAckOnly) {
                emitLog("[warn] Callback tanpa stdout/exit detail. Lanjut proses setup.")
            } else if (bridgeMarkerFound) {
                emitLog("[ok] Bridge RUN_COMMAND ke Termux berhasil")
            }

            // Precheck 2/2: try to verify allow-external-apps, but don't block on it
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

            emitLog("[debug] allow-external-apps: success=${allowExternalAppsCheck.success}, enabled=${allowExternalAppsEnabled}, exit=${allowExternalAppsCheck.exitCode}")

            if (allowExternalAppsEnabled) {
                emitLog("[ok] allow-external-apps sudah aktif")
            } else if (allowExternalAppsCheck.success && !allowExternalAppsEnabled) {
                // Command ran but allow-external-apps is not set — setup will fix it
                emitLog("[warn] allow-external-apps belum aktif. Setup command akan mengaktifkannya.")
            } else {
                // Couldn't check (minimal callback or error) — proceed anyway
                emitLog("[warn] Tidak bisa verifikasi allow-external-apps dari callback. Lanjut ke setup.")
            }

            // Always proceed to setup commands — they will configure everything needed
            val setupOk = executeSetupCommands(termuxPackage)
            emitDone(setupOk)
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

                // Diagnostic: log all raw extra keys for debugging
                val rawExtras = intent.extras
                val rawKeyDump = rawExtras?.keySet()?.joinToString(", ") { key ->
                    val value = rawExtras.get(key)
                    val type = value?.javaClass?.simpleName ?: "null"
                    "$key($type)"
                } ?: "(no extras)"
                android.util.Log.d("USM_Termux", "Raw intent extras: $rawKeyDump")

                val bundle = extractPluginResultBundle(intent)
                if (bundle == null) {
                    resultHolder.success = false
                    resultHolder.errMsg = "Result bundle kosong (allow-external-apps mungkin belum aktif)"
                    latch.countDown()
                    return
                }

                // Diagnostic: log plugin result bundle keys
                val bundleKeyDump = bundle.keySet().joinToString(", ") { key ->
                    val value = bundle.get(key)
                    val type = value?.javaClass?.simpleName ?: "null"
                    "$key($type)=$value"
                }
                android.util.Log.d("USM_Termux", "Plugin result bundle: $bundleKeyDump")

                resultHolder.stdout = findBundleString(bundle, "STDOUT", "RESULT_STDOUT", "stdout")
                resultHolder.stderr = findBundleString(bundle, "STDERR", "RESULT_STDERR", "stderr")
                resultHolder.exitCode = findBundleInt(
                    bundle,
                    -1,
                    "EXIT_CODE",
                    "EXITCODE",
                    "RESULT_EXIT_CODE",
                    "exit_code"
                )
                resultHolder.errCode = findBundleInt(
                    bundle,
                    -1,
                    "_ERR",
                    "ERR",
                    "ERR_CODE",
                    "ERROR_CODE",
                    "RESULT_ERR",
                    "err"
                )
                resultHolder.errMsg = findBundleString(
                    bundle,
                    "ERRMSG",
                    "ERR_MSG",
                    "ERROR_MESSAGE",
                    "errmsg"
                )
                resultHolder.callbackResultCode = findBundleIntExact(
                    intent.extras,
                    "result",
                    "result_code"
                )

                if (resultHolder.exitCode == -1) {
                    val topLevelExit = findBundleIntExact(
                        intent.extras,
                        "exit_code",
                        "result_code"
                    )
                    if (topLevelExit != null) {
                        resultHolder.exitCode = topLevelExit
                    } else {
                        val genericResult = findBundleIntExact(intent.extras, "result")
                        if (genericResult != null && genericResult >= 0) {
                            resultHolder.exitCode = genericResult
                        }
                    }
                }

                if (resultHolder.errCode == -1) {
                    val topLevelErr = findBundleIntExact(intent.extras, "err", "error")
                    if (topLevelErr != null && topLevelErr < 0) {
                        resultHolder.errCode = topLevelErr
                    }
                }

                resultHolder.success = resultHolder.exitCode == 0 &&
                    (resultHolder.errCode == -1 || resultHolder.errCode == 0 || resultHolder.errCode == ActivityResultOk)

                // Rescue: some Termux variants return only callback-level RESULT_OK
                // without populating stdout/exit_code in the bundle.
                if (!resultHolder.success &&
                    resultHolder.exitCode == -1 &&
                    (resultHolder.errCode == ActivityResultOk || resultHolder.errCode == -1) &&
                    resultHolder.errMsg.isBlank()
                ) {
                    resultHolder.success = true
                }

                resultHolder.minimalPayloadOnly = bundle.keySet().size <= 1 &&
                    bundle.keySet().all {
                        val n = normalizeBundleKey(it)
                        n == "result" || n == "resultcode"
                    }

                if (!resultHolder.success && resultHolder.errMsg.isBlank()) {
                    val details = bundle.keySet().joinToString(",") { key ->
                        val value = bundle.get(key)
                        val type = value?.javaClass?.simpleName ?: "null"
                        "$key($type)=$value"
                    }
                    resultHolder.errMsg = "Result keys: $details"
                }

                latch.countDown()
            }
        }

        try {
            val filter = IntentFilter(actionResult)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // RECEIVER_EXPORTED is required because Termux (external app)
                // delivers the command result via this broadcast receiver.
                // Security: the action string is unique per execution (timestamp+counter)
                // so other apps cannot guess/spoof the callback.
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
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
            val normalized = normalizeBundleKey(key)
            if ((normalized == "result" ||
                    normalized == "pluginresultbundle" ||
                    normalized.contains("pluginresultbundle")) &&
                extras.get(key) is Bundle
            ) {
                return extras.getBundle(key)
            }
        }

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

        // Pass 1: exact match (normalized key == normalized keyPart)
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (normalizedKeyParts.any { normalized == it }) {
                val value = bundle.get(key)
                if (value is String) return value
                // Skip non-String values for exact match to avoid picking up _length Int keys
            }
        }

        // Pass 2: contains match, but skip keys with length/size/count/original
        val excludePatterns = listOf("length", "size", "count", "original")
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (excludePatterns.any { normalized.contains(it) }) continue
            if (normalizedKeyParts.any { normalized.contains(it) }) {
                return bundle.getString(key) ?: bundle.get(key)?.toString().orEmpty()
            }
        }

        return ""
    }

    private fun findBundleInt(bundle: Bundle, defaultValue: Int, vararg keyParts: String): Int {
        val normalizedKeyParts = keyParts.map { normalizeBundleKey(it) }

        // Pass 1: exact match (normalized key == normalized keyPart)
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (normalizedKeyParts.any { normalized == it }) {
                val value = bundle.get(key)
                when (value) {
                    is Int -> return value
                    is Long -> return value.toInt()
                    is String -> {
                        val parsed = value.toIntOrNull()
                        if (parsed != null) return parsed
                    }
                }
            }
        }

        // Pass 2: contains match, but skip keys with length/size/count/original
        val excludePatterns = listOf("length", "size", "count", "original")
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (excludePatterns.any { normalized.contains(it) }) continue
            if (normalizedKeyParts.any { normalized.contains(it) }) {
                val value = bundle.get(key)
                when (value) {
                    is Int -> return value
                    is Long -> return value.toInt()
                    is String -> {
                        val parsed = value.toIntOrNull()
                        if (parsed != null) return parsed
                    }
                }
            }
        }

        return defaultValue
    }

    private fun findBundleIntExact(bundle: Bundle?, vararg exactKeys: String): Int? {
        if (bundle == null) {
            return null
        }

        val normalizedExactKeys = exactKeys.map { normalizeBundleKey(it) }
        for (key in bundle.keySet()) {
            val normalized = normalizeBundleKey(key)
            if (normalizedExactKeys.any { normalized == it }) {
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

        return null
    }

    private fun normalizeBundleKey(raw: String): String {
        return raw.lowercase().filter { it.isLetterOrDigit() }
    }

    private fun looksLikeExternalAppsBlocked(result: TermuxCommandResult): Boolean {
        val detail = "${result.errMsg}\n${result.stderr}\n${result.stdout}".lowercase()
        // Check explicit mentions of allow-external-apps
        if (detail.contains("allow-external-apps") ||
            detail.contains("external app") ||
            detail.contains("result bundle kosong")
        ) {
            return true
        }
        // Minimal payload with default error values strongly suggests
        // allow-external-apps is not enabled.
        if (result.exitCode == -1 && result.errCode == -1 && result.minimalPayloadOnly) {
            return true
        }
        return false
    }

    private fun emitAllowExternalAppsHint() {
        emitLog("[hint] Aktifkan allow-external-apps di Termux:")
        emitLog("[hint] 1) buka Termux")
        emitLog("[hint] 2) jalankan: mkdir -p ~/.termux")
        emitLog("[hint] 3) jalankan: echo 'allow-external-apps=true' >> ~/.termux/termux.properties")
        emitLog("[hint] 4) jalankan: termux-reload-settings")
        emitLog("[hint] 5) force close Universal SpotDL lalu coba Repair lagi")
    }

    private fun emitTermuxBootstrapHint(packageName: String) {
        emitLog("[hint] Buka Termux minimal sekali sampai muncul prompt shell (bootstrap install)")
        if (openPackage(packageName)) {
            emitLog("[hint] Termux dibuka otomatis. Setelah siap, kembali ke app ini dan klik Repair lagi.")
        } else {
            emitLog("[hint] Tidak bisa auto-open Termux. Buka manual lalu coba Repair lagi.")
        }
        emitLog("[hint] Pastikan folder init Termux sudah ada dan permission 0700:")
        emitLog("[hint] mkdir -p ~/.termux ~/.termux/tasker")
        emitLog("[hint] chmod 700 ~/.termux ~/.termux/tasker")
    }

    private fun executeSetupCommands(packageName: String): Boolean {
        // Pair<command, timeoutSeconds>
        // pip install needs very long timeout — Rust compilation on ARM can take 30-60+ min
        val commands = listOf(
            Pair("mkdir -p ~/.termux ~/.termux/tasker && chmod 700 ~/.termux ~/.termux/tasker && (grep -Eq '^[[:space:]]*allow-external-apps[[:space:]]*=' ~/.termux/termux.properties 2>/dev/null && sed -Ei 's/^[[:space:]]*allow-external-apps[[:space:]]*=.*/allow-external-apps=true/' ~/.termux/termux.properties || echo 'allow-external-apps=true' >> ~/.termux/termux.properties) && termux-reload-settings >/dev/null 2>&1 || true", 120L),
            Pair("pkg update -y", 900L),
            Pair("pkg install -y python ffmpeg rust binutils", 900L),
            Pair("pip install --upgrade --no-cache-dir spotdl", 3600L),
            Pair("python --version", 30L),
            Pair("ffmpeg -version | head -n 1", 30L),
            Pair("spotdl --version", 30L)
        )

        // Steps 0-3 are install steps (critical), 4-6 are verification steps (non-critical)
        val installStepCount = 4

        val total = commands.size
        for ((index, entry) in commands.withIndex()) {
            val (command, timeout) = entry
            emitLog("[step ${index + 1}/$total] $command")
            val result = runTermuxCommand(
                packageName = packageName,
                shellCommand = command,
                timeoutSeconds = timeout
            )

            if (result.stdout.isNotBlank()) {
                emitLogLines("[stdout]", result.stdout)
            }
            if (result.stderr.isNotBlank()) {
                emitLogLines("[stderr]", result.stderr)
            }

            emitLog("[debug] step ${index + 1}: success=${result.success}, exit=${result.exitCode}, err=${result.errCode}")

            if (!result.success) {
                val errMsg = result.errMsg
                // Hard fail on timeout or security errors
                if (errMsg.contains("Timeout", ignoreCase = true) ||
                    errMsg.contains("SecurityException", ignoreCase = true)
                ) {
                    emitLog("[error] Command gagal: ${result.errMsg}")
                    if (looksLikeExternalAppsBlocked(result)) {
                        emitAllowExternalAppsHint()
                    }
                    return false
                }

                if (index < installStepCount) {
                    // Install step failed with real exit code
                    if (result.exitCode > 0) {
                        emitLog("[error] Install step gagal (exit=${result.exitCode}). Cek stderr di atas.")
                        return false
                    }
                    // Exit code unknown (-1) but callback received — try to continue
                    emitLog("[warn] Callback tidak lengkap, tapi command mungkin berhasil. Lanjut...")
                } else {
                    // Verification step — just warn, don't abort
                    emitLog("[warn] Verifikasi '${command.split(" ").first()}' gagal (exit=${result.exitCode}). Mungkin belum terinstall.")
                }
            }
        }

        emitLog("[ok] Setup environment Termux selesai")
        return true
    }

    private fun getPackageVersionName(packageName: String): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                ).versionName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0).versionName
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isVersionAtLeast(versionName: String?, minMajor: Int, minMinor: Int): Boolean {
        if (versionName.isNullOrBlank()) {
            return true
        }

        val numbers = Regex("\\d+").findAll(versionName).map { it.value.toInt() }.toList()
        if (numbers.isEmpty()) {
            return true
        }

        val major = numbers.getOrElse(0) { 0 }
        val minor = numbers.getOrElse(1) { 0 }
        if (major != minMajor) {
            return major > minMajor
        }
        return minor >= minMinor
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
        var stderr: String,
        var callbackResultCode: Int? = null,
        var minimalPayloadOnly: Boolean = false
    )

    companion object {
        private const val ActivityResultOk = -1
    }
}
