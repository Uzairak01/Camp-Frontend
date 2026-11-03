package com.example.camp

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and the "camp/share" channel used by the emergency alert.
 *
 * Why this exists: url_launcher fires an implicit ACTION_VIEW for `sms:` links. Both the
 * system messaging app and WhatsApp claim that link, and WhatsApp answers with its
 * "number not registered" dialog. This channel sends explicit, unambiguous intents instead.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }

    /**
     * Opens the default SMS app's composer for exactly one [number], pre-filled with [body].
     *
     * Builds `ACTION_SENDTO smsto:<number>` with the `sms_body` extra and pins it to the
     * default SMS package so no chooser appears and WhatsApp can never intercept it.
     * Nothing is sent; the rider taps Send. Returns false on any failure so Dart can fall back.
     */
    private fun openSms(number: String, body: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(number)))
            intent.putExtra("sms_body", body)
            // Pin the intent to the default SMS app when the system reports one.
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
     *
     * The rider picks the app and the person inside that app. Returns false on any failure.
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
    }
}
