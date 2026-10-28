package io.github.x1a0y4ngren.hooptrace

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class AppUpdatePreparedFileTest {
    @Test fun launchRequiresSameGenerationAndExistingUnchangedPrivateFile() {
        val file = File.createTempFile("update-prepared", ".apk")
        try {
            file.writeText("verified")
            val prepared = AppUpdatePreparedFile.capture(file, 7)
            assertTrue(prepared.matches(7))
            assertFalse(prepared.matches(8))
            file.writeText("modified length")
            assertFalse(prepared.matches(7))
            file.delete()
            assertFalse(prepared.matches(7))
        } finally { file.delete() }
    }
    @Test fun timestampChangeInvalidatesEqualLengthReplacement() {
        val file = File.createTempFile("update-prepared", ".apk")
        try {
            file.writeText("verified")
            val prepared = AppUpdatePreparedFile.capture(file, 7)
            assertTrue(file.setLastModified(file.lastModified() + 5000))
            assertFalse(prepared.matches(7))
        } finally { file.delete() }
    }
}
