package io.github.x1a0y4ngren.hooptrace

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.file.Files

class AppUpdateFilesTest {
    private val abcHash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    @Test fun privateCopyRetainsVerifiedBytesWhenExternalSourceChanges() {
        val root = Files.createTempDirectory("app-update").toFile()
        try {
            val stage = File(root, "external.part").apply { writeText("abc") }
            val privateFile = File(root, "private.apk")
            AppUpdateFiles.copyAndVerify(stage, privateFile, 3, abcHash)
            stage.writeText("bad")
            AppUpdateFiles.verify(privateFile, 3, abcHash)
            assertEquals("abc", privateFile.readText())
        } finally { root.deleteRecursively() }
    }

    @Test fun changedPrivateCandidateMustFailFreshInstallVerification() {
        val root = Files.createTempDirectory("app-update").toFile()
        try {
            val candidate = File(root, "candidate.apk").apply { writeText("abc") }
            AppUpdateFiles.verify(candidate, 3, abcHash)
            candidate.writeText("bad")
            rejects { AppUpdateFiles.verify(candidate, 3, abcHash) }
            candidate.writeText("ab")
            rejects { AppUpdateFiles.verify(candidate, 3, abcHash) }
            candidate.writeText("abcd")
            rejects { AppUpdateFiles.verify(candidate, 3, abcHash) }
        } finally { root.deleteRecursively() }
    }

    @Test fun copyRejectsLengthAndDigestMismatch() {
        val root = Files.createTempDirectory("app-update").toFile()
        try {
            val stage = File(root, "external.part").apply { writeText("abcd") }
            val candidate = File(root, "candidate.apk")
            rejects { AppUpdateFiles.copyAndVerify(stage, candidate, 3, abcHash) }
            stage.writeText("bad")
            rejects { AppUpdateFiles.copyAndVerify(stage, candidate, 3, abcHash) }
        } finally { root.deleteRecursively() }
    }

    private fun rejects(action: () -> Unit) {
        try { action(); fail("Unverified content accepted") }
        catch (_: SecurityException) { }
    }
}
