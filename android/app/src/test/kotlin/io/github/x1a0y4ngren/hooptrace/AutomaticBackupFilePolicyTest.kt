package io.github.x1a0y4ngren.hooptrace

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AutomaticBackupFilePolicyTest {
    @Test
    fun rebrandOwnsBothPrefixesWithoutExpandingRetentionToManualFiles() {
        for (prefix in listOf("hoopito", "hooptrace")) {
            assertTrue(AutomaticBackupFilePolicy.isOwnedDocument("$prefix-auto-20261012.json", "application/json"))
            assertFalse(AutomaticBackupFilePolicy.isAutomaticBackupFile("$prefix-backup-20261012.json"))
            assertFalse(AutomaticBackupFilePolicy.isAutomaticBackupFile("../$prefix-auto-20261012.json"))
        }
    }

    @Test
    fun onlyAutomaticJsonDocumentsAreOwnedByRetention() {
        assertTrue(
            AutomaticBackupFilePolicy.isOwnedDocument(
                "hooptrace-auto-20260824.json",
                "application/json",
            ),
        )
        assertFalse(
            AutomaticBackupFilePolicy.isOwnedDocument(
                "hooptrace-auto-20260824.json",
                "vnd.android.document/directory",
            ),
        )
        assertFalse(
            AutomaticBackupFilePolicy.isOwnedDocument(
                "hooptrace-auto-20260824.json",
                "text/plain",
            ),
        )
        assertFalse(
            AutomaticBackupFilePolicy.isOwnedDocument(
                "notes.json",
                "application/json",
            ),
        )
    }

    @Test
    fun androidWindowPolicyUsesPlatformCapabilityBoundaries() {
        assertFalse(AndroidWindowPolicy.shouldEnablePredictiveBack(32))
        assertTrue(AndroidWindowPolicy.shouldEnablePredictiveBack(33))
        assertFalse(AndroidWindowPolicy.shouldUsePlatformEdgeToEdge(29))
        assertTrue(AndroidWindowPolicy.shouldUsePlatformEdgeToEdge(30))
    }
}
