package __PACKAGE__

import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * The phone as an NFC Forum Type 4 tag with one NDEF URI record.
 *
 * Another phone held against this one reads the record the way it reads a
 * sticker: Android opens the link straight away, an iPhone shows it as a
 * notification. Nothing has to be installed on the other side.
 *
 * The link is set only while the "my card" screen is open, and cleared when it
 * closes — with no link, the NDEF file does not exist and a reader sees an
 * empty tag.
 */
class CardHceService : HostApduService() {

    companion object {
        /** Set from MainActivity over the method channel. */
        @Volatile
        var url: String? = null

        /** Bumped every time the card was read, for the screen to show. */
        @Volatile
        var reads: Int = 0

        private val OK = byteArrayOf(0x90.toByte(), 0x00)
        private val NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
        private val WRONG_P1P2 = byteArrayOf(0x6B, 0x00)
        private val UNKNOWN_INS = byteArrayOf(0x6D, 0x00)

        private val NDEF_AID = hex("D2760000850101")
        private val CC_FILE = hex("E103")
        private val NDEF_FILE = hex("E104")

        /** Capability Container, NFC Forum Type 4 Tag v2.0. Read-only. */
        private val CC = hex(
            "000F" +      // CCLEN
            "20" +        // mapping version 2.0
            "00FF" +      // MLe: max bytes per READ BINARY
            "00FF" +      // MLc: max bytes per UPDATE BINARY
            "0406" +      // NDEF File Control TLV
            "E104" +      // NDEF file id
            "0400" +      // max NDEF file size (1024)
            "00" +        // read access: granted
            "FF"          // write access: denied
        )

        private fun hex(s: String): ByteArray =
            ByteArray(s.length / 2) { s.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    }

    private enum class File { NONE, CC, NDEF }

    private var selected = File.NONE
    private var appSelected = false

    /** NLEN (2 bytes) + the NDEF message, built once per selection. */
    private var ndefFile: ByteArray? = null

    override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
        if (apdu.size < 4) return UNKNOWN_INS
        val ins = apdu[1].toInt() and 0xFF
        val p1 = apdu[2].toInt() and 0xFF
        val p2 = apdu[3].toInt() and 0xFF

        return when (ins) {
            0xA4 -> select(apdu, p1, p2)
            0xB0 -> readBinary(apdu, (p1 shl 8) or p2)
            else -> UNKNOWN_INS
        }
    }

    private fun select(apdu: ByteArray, p1: Int, p2: Int): ByteArray {
        if (apdu.size < 5) return NOT_FOUND
        val lc = apdu[4].toInt() and 0xFF
        if (apdu.size < 5 + lc) return NOT_FOUND
        val data = apdu.copyOfRange(5, 5 + lc)

        // SELECT by name: the NDEF application.
        if (p1 == 0x04) {
            if (!data.contentEquals(NDEF_AID)) return NOT_FOUND
            appSelected = true
            selected = File.NONE
            return OK
        }
        // SELECT by file id.
        if (p1 == 0x00 && p2 == 0x0C && appSelected) {
            return when {
                data.contentEquals(CC_FILE) -> {
                    selected = File.CC
                    OK
                }
                data.contentEquals(NDEF_FILE) -> {
                    val link = url ?: return NOT_FOUND
                    ndefFile = buildNdefFile(link)
                    selected = File.NDEF
                    reads += 1
                    OK
                }
                else -> NOT_FOUND
            }
        }
        return NOT_FOUND
    }

    private fun readBinary(apdu: ByteArray, offset: Int): ByteArray {
        val file = when (selected) {
            File.CC -> CC
            File.NDEF -> ndefFile ?: return NOT_FOUND
            File.NONE -> return NOT_FOUND
        }
        if (offset > file.size) return WRONG_P1P2
        val le = if (apdu.size >= 5) apdu[apdu.size - 1].toInt() and 0xFF else 0
        val length = minOf(if (le == 0) 256 else le, file.size - offset)
        return file.copyOfRange(offset, offset + length) + OK
    }

    private fun buildNdefFile(link: String): ByteArray {
        val message = NdefMessage(NdefRecord.createUri(Uri.parse(link))).toByteArray()
        val nlen = byteArrayOf((message.size shr 8).toByte(), message.size.toByte())
        return nlen + message
    }

    override fun onDeactivated(reason: Int) {
        selected = File.NONE
        appSelected = false
        ndefFile = null
    }
}
