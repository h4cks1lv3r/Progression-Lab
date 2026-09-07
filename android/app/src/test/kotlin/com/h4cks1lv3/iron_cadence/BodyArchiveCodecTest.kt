package com.h4cks1lv3.iron_cadence
import org.junit.Assert.*
import org.junit.Test
import java.io.*
import java.util.zip.*

class BodyArchiveCodecTest {
    private val password = "a test password, not a real secret"
    private fun encode(bytes: ByteArray): ByteArray = ByteArrayOutputStream().also { out -> BodyArchiveCodec.encryptingStream(out,password).use { it.write(bytes) } }.toByteArray()
    private fun decode(bytes: ByteArray, pass: String = password, max: Long = 20_000_000): ByteArray = ByteArrayOutputStream().also { BodyArchiveCodec.decrypt(ByteArrayInputStream(bytes),it,pass,max) }.toByteArray()
    private fun rejected(work: () -> Unit) { try { work() } catch(_: Exception) { return }; fail("Invalid archive was accepted") }
    @Test fun roundTripBoundariesAndRandomizedCiphertext() {
        for(size in listOf(0,1,65535,65536,65537,131072)) {
            val bytes = ByteArray(size) { (it % 251).toByte() }
            val encoded = encode(bytes)
            assertArrayEquals(bytes,decode(encoded))
            assertFalse(encoded.contentEquals(encode(bytes)))
        }
    }
    @Test fun wrongPasswordTamperTruncationReorderingAndTrailingBytesFail() {
        val encoded = encode(ByteArray(180000) { (it % 239).toByte() })
        rejected { decode(encoded,"incorrect password") }
        for(at in listOf(0,12,25,31,1000,encoded.lastIndex)) {
            val changed = encoded.copyOf(); changed[at]=(changed[at].toInt() xor 1).toByte()
            rejected { decode(changed) }
        }
        for(size in listOf(0,8,28,encoded.size-1,encoded.size-20)) rejected { decode(encoded.copyOf(size)) }
        val reordered = encoded.copyOf(); val offset=29; val record=4+65536+16
        encoded.copyInto(reordered, offset, offset+record, offset+2*record)
        encoded.copyInto(reordered, offset+record, offset, offset+record)
        rejected { decode(reordered) }
        rejected { decode(encoded+byteArrayOf(0)) }
        rejected { decode(encoded,max=1000) }
    }
    @Test fun archiveWithMoreThan64AssetsStreamsAndRestoresExactly() {
        val out=ByteArrayOutputStream()
        ZipOutputStream(BodyArchiveCodec.encryptingStream(out,password)).use { zip ->
            repeat(130) { i -> zip.putNextEntry(ZipEntry("p_$i.jpg")); zip.write(ByteArray(10000) { (it+i).toByte() }); zip.closeEntry() }
        }
        var count=0
        ZipInputStream(ByteArrayInputStream(decode(out.toByteArray()))).use { zip ->
            while(true) {
                val entry=zip.nextEntry ?: break
                assertEquals("p_$count.jpg",entry.name)
                assertArrayEquals(ByteArray(10000) { (it+count).toByte() },zip.readBytes())
                count++
            }
        }
        assertEquals(130,count)
    }
}
