package com.h4cks1lv3.iron_cadence

import java.io.*
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/** Versioned, bounded-memory authenticated stream. Every 64 KiB record authenticates
 * its index and length. A final authenticated empty record prevents truncation.
 * Random salt gives each archive its own key; nonces never repeat within a key. */
object BodyArchiveCodec {
    private val header = "PLABBODY2".toByteArray(Charsets.US_ASCII)
    private const val chunk = 65536
    private fun key(password: String, salt: ByteArray): SecretKeySpec {
        require(password.length in 10..256) { "Use a password of 10 to 256 characters." }
        val spec = PBEKeySpec(password.toCharArray(), salt, 210000, 256)
        val bytes = try { SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded }
                    finally { spec.clearPassword() }
        return SecretKeySpec(bytes, "AES").also { bytes.fill(0) }
    }
    private fun crypt(mode: Int, key: SecretKeySpec, prefix: ByteArray, index: Long, length: Int, data: ByteArray): ByteArray {
        val nonce = ByteBuffer.allocate(12).put(prefix).putLong(index).array()
        val aad = ByteBuffer.allocate(header.size + 12).put(header).putLong(index).putInt(length).array()
        return Cipher.getInstance("AES/GCM/NoPadding").run {
            init(mode, key, GCMParameterSpec(128, nonce)); updateAAD(aad); doFinal(data)
        }
    }
    fun encryptingStream(target: OutputStream, password: String): OutputStream {
        val random = SecureRandom()
        val salt = ByteArray(16).also(random::nextBytes)
        val prefix = ByteArray(4).also(random::nextBytes)
        val secret = key(password, salt)
        val out = DataOutputStream(target)
        out.write(header); out.write(salt); out.write(prefix)
        return object : OutputStream() {
            val buffer = ByteArray(chunk)
            var count = 0
            var index = 0L
            var closed = false
            fun emit(length: Int) {
                out.writeInt(length)
                out.write(crypt(Cipher.ENCRYPT_MODE, secret, prefix, index++, length, buffer.copyOf(length)))
                count = 0
            }
            override fun write(value: Int) { write(byteArrayOf(value.toByte()), 0, 1) }
            override fun write(bytes: ByteArray, offset: Int, length: Int) {
                check(!closed)
                require(offset >= 0 && length >= 0 && offset <= bytes.size - length)
                var at = offset; var remaining = length
                while (remaining > 0) {
                    val n = minOf(chunk - count, remaining)
                    bytes.copyInto(buffer, count, at, at + n)
                    count += n; at += n; remaining -= n
                    if (count == chunk) emit(count)
                }
            }
            override fun flush() { out.flush() }
            override fun close() {
                if (closed) return
                try { if (count > 0) emit(count); emit(0); out.flush() }
                finally { closed = true; buffer.fill(0); out.close() }
            }
        }
    }
    /** Caller stages output privately and discards it unless this returns successfully. */
    fun decrypt(source: InputStream, target: OutputStream, password: String, maxBytes: Long) {
        val input = DataInputStream(source)
        val actual = ByteArray(header.size); input.readFully(actual)
        require(actual.contentEquals(header)) { "Choose a Progression Lab body backup." }
        val salt = ByteArray(16); input.readFully(salt)
        val prefix = ByteArray(4); input.readFully(prefix)
        val secret = key(password, salt)
        var index = 0L; var count = 0L
        while (true) {
            val length = input.readInt()
            require(length in 0..chunk) { "Invalid encrypted record size." }
            count += length
            require(count <= maxBytes) { "The archive exceeds its size limit." }
            val encrypted = ByteArray(length + 16); input.readFully(encrypted)
            val plain = crypt(Cipher.DECRYPT_MODE, secret, prefix, index++, length, encrypted)
            if (length == 0) { require(input.read() == -1) { "Unexpected trailing archive data." }; return }
            target.write(plain); plain.fill(0)
        }
    }
}
