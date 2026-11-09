package com.example.camp

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine, the "camp/share" channel for emergency alerts,
 * and the "camp/camera_permission" channel for explicit camera authorization.
 */
class MainActivity : FlutterActivity() {

    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // camp/share channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSms" -> {
                        val number = call.argument<String>("number")
                        val body = call.argument<String>("body")
                        result.success(
                            if (number.isNullOrBlank() || body == null) false
                            else openSms(number, body)
                        )
                    }
                    "shareText" -> {
                        val body = call.argument<String>("body")
                        result.success(if (body == null) false else shareText(body))
                    }
                    else -> result.notImplemented()
                }
            }

        // camp/camera_permission channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.CAMERA
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success("granted")
                        } else {
                            val prefs = getSharedPreferences("camp_prefs", Context.MODE_PRIVATE)
                            val requestedBefore = prefs.getBoolean("camera_requested", false)
                            if (requestedBefore && !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA)) {
                                result.success("permanentlyDenied")
                            } else {
                                result.success("denied")
                            }
                        }
                    }
                    "requestPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.CAMERA
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success("granted")
                        } else {
                            val prefs = getSharedPreferences("camp_prefs", Context.MODE_PRIVATE)
                            prefs.edit().putBoolean("camera_requested", true).apply()
                            pendingCameraPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.CAMERA),
                                CAMERA_PERMISSION_CODE
                            )
                        }
                    }
                    "openAppSettings" -> {
                        result.success(openAppSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            val callback = pendingCameraPermissionResult
            pendingCameraPermissionResult = null
            if (granted) {
                callback?.success("granted")
            } else {
                val permanentlyDenied = !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.CAMERA)
                callback?.success(if (permanentlyDenied) "permanentlyDenied" else "denied")
            }
        }
    }

    private fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Opens the default SMS app's composer for exactly one [number], pre-filled with [body].
     */
    private fun openSms(number: String, body: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(number)))
            intent.putExtra("sms_body", body)
            val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this)
            if (defaultSmsPackage != null) {
                intent.setPackage(defaultSmsPackage)
            }
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Shows the system share sheet ("Send alert with") for [body] as plain text.
     */
    private fun shareText(body: String): Boolean {
        return try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, body)
            }
            startActivity(Intent.createChooser(send, "Send alert with"))
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        /** Name of the platform channel shared with emergency_sos_helpers.dart. */
        private const val CHANNEL = "camp/share"

        /** Name of the camera permission channel shared with camera_permission_service.dart. */
        private const val CAMERA_CHANNEL = "camp/camera_permission"

        private const val CAMERA_PERMISSION_CODE = 1002
    }
}
