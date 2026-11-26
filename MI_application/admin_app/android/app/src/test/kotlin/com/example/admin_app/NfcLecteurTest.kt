package com.example.admin_app

import org.junit.Assert.assertEquals
import org.junit.Test

class NfcLecteurTest {
    @Test
    fun formatsUidInReaderByteOrderAsUppercaseColonSeparatedHex() {
        val uid = formatNfcUid(
            byteArrayOf(0x00, 0x0a, 0x7f, 0x80.toByte(), 0xff.toByte()),
        )

        assertEquals("00:0A:7F:80:FF", uid)
    }
}
