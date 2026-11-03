package io.github.x1a0y4ngren.hooptrace

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class AppUpdatePolicyTest {
    @Test fun onlyFailedPrimaryRetryTriggersPausedFailover() {
        assertTrue(AppUpdatePolicy.shouldFallbackPaused(false, 1))
        assertFalse(AppUpdatePolicy.shouldFallbackPaused(true, 1))
        for (reason in listOf(2, 3, 4)) {
            assertFalse(AppUpdatePolicy.shouldFallbackPaused(false, reason))
        }
    }
    @Test fun officialDownloadUrlsRequireExactReleasePathAndHttps() {
        assertTrue(AppUpdatePolicy.isOfficialUrl("https://hoopito.com/downloads/v2.1.0/Hoopito-v2.1.0-android.apk"))
        assertTrue(AppUpdatePolicy.isOfficialUrl("https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.1.0/Hoopito-v2.1.0-android.apk"))
        for (url in listOf("http://hoopito.com/downloads/a.apk", "https://hoopito.com.evil/downloads/a.apk", "https://user@hoopito.com/downloads/a.apk", "https://hoopito.com:444/downloads/a.apk", "https://github.com/evil/hoopito/releases/download/a.apk", "https://hoopito.com/downloads/../secret.apk")) {
            assertFalse(url, AppUpdatePolicy.isOfficialUrl(url))
        }
    }

    @Test fun signerSetMustBeExactNonemptyCurrentSigners() {
        assertTrue(AppUpdatePolicy.sameSigners(setOf("a", "b"), setOf("b", "a")))
        assertFalse(AppUpdatePolicy.sameSigners(emptySet(), emptySet()))
        assertFalse(AppUpdatePolicy.sameSigners(setOf("old"), setOf("old", "new")))
        assertFalse(AppUpdatePolicy.sameSigners(setOf("old"), setOf("new")))
    }

    @Test fun candidateMustMatchManifestAndUpgradeInstalledVersion() {
        assertTrue(AppUpdatePolicy.isUpgrade(6, 5))
        assertFalse(AppUpdatePolicy.isUpgrade(6, 6))
        assertFalse(AppUpdatePolicy.isUpgrade(6, 7))
        assertTrue(AppUpdatePolicy.matchesPackage("app", 6, "2.1", 24, "app", 6, "2.1", 24, 5, 24))
        assertFalse(AppUpdatePolicy.matchesPackage("app", 6, "2.1", 24, "evil", 6, "2.1", 24, 5, 24))
        assertFalse(AppUpdatePolicy.matchesPackage("app", 6, "2.1", 24, "app", 6, "other", 24, 5, 24))
        assertFalse(AppUpdatePolicy.matchesPackage("app", 6, "2.1", 24, "app", 6, "2.1", 25, 5, 24))
        assertFalse(AppUpdatePolicy.matchesPackage("app", 6, "2.1", 24, "app", 6, "2.1", 24, 6, 24))
    }

    @Test fun filesStayInDedicatedSubtreeAndNamesAreDigestOnly() {
        val root = File(System.getProperty("java.io.tmpdir"), "updates-test")
        assertEquals(File(root, "a".repeat(64) + ".apk").canonicalFile, AppUpdatePolicy.ownedFile(root, "a".repeat(64), ".apk"))
        try {
            AppUpdatePolicy.ownedFile(root, "../escape", ".apk")
            fail("Traversal must be rejected")
        } catch (_: IllegalArgumentException) { }
        assertFalse(AppUpdatePolicy.isOwnedName("other.apk"))
        assertTrue(AppUpdatePolicy.isOwnedName("a".repeat(64) + ".part"))
    }
}
