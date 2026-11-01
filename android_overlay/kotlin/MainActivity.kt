package __PACKAGE__

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The generated activity plus one method channel, `up/nfc_card`, that turns
 * the phone's business card on and off. See CardHceService.
 */
class MainActivity : FlutterActivity() {

    private val service by lazy { ComponentName(this, CardHceService::class.java) }

    private fun adapter(): NfcAdapter? = NfcAdapter.getDefaultAdapter(this)

    private fun supported(): Boolean =
        adapter() != null &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "up/nfc_card")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        mapOf(
                            "supported" to supported(),
                            "enabled" to (adapter()?.isEnabled == true),
                            "reads" to CardHceService.reads,
                        )
                    )
                    "start" -> {
                        val url = call.argument<String>("url")
                        if (url == null || !url.startsWith("https://")) {
                            result.error("bad_url", "https URL required", null)
                        } else {
                            CardHceService.url = url
                            prefer(true)
                            result.success(supported())
                        }
                    }
                    "stop" -> {
                        CardHceService.url = null
                        prefer(false)
                        result.success(null)
                    }
                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * While the card screen is open, this app answers the NDEF AID ahead of any
     * other app that claims it (another tag emulator, a reader utility).
     */
    private fun prefer(on: Boolean) {
        val nfc = adapter() ?: return
        if (!supported()) return
        try {
            val emulation = CardEmulation.getInstance(nfc)
            if (on) emulation.setPreferredService(this, service)
            else emulation.unsetPreferredService(this)
        } catch (e: Exception) {
            // Not fatal: without the preference, the service still answers
            // when it is the only one claiming the AID — the usual case.
        }
    }

    override fun onResume() {
        super.onResume()
        if (CardHceService.url != null) prefer(true)
    }

    override fun onPause() {
        prefer(false)
        super.onPause()
    }
}
