package io.github.x1a0y4ngren.hooptrace

import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest

/** Hash the private copy and bound every read, including a mutable external source. */
internal object AppUpdateFiles {
    fun copyAndVerify(source: File, destination: File, bytes: Long, sha256: String) {
        if (!source.isFile) throw FileNotFoundException()
        if (source.length() != bytes) throw SecurityException("Size mismatch")
        destination.outputStream().use { output ->
            source.inputStream().use { input ->
                val buffer = ByteArray(65536)
                var count = 0L
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    count += read
                    if (count > bytes) throw SecurityException("Size exceeded")
                    output.write(buffer, 0, read)
                }
                output.fd.sync()
            }
        }
        verify(destination, bytes, sha256)
    }

    fun verify(file: File, bytes: Long, sha256: String) {
        if (!file.isFile) throw FileNotFoundException()
        if (file.length() != bytes) throw SecurityException("Size mismatch")
        val digest = MessageDigest.getInstance("SHA-256")
        var count = 0L
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val size = input.read(buffer)
                if (size < 0) break
                count += size
                if (count > bytes) throw SecurityException("Size exceeded")
                digest.update(buffer, 0, size)
            }
        }
        if (count != bytes || digest.digest().joinToString("") { "%02x".format(it) } != sha256) {
            throw SecurityException("Hash mismatch")
        }
    }
}
