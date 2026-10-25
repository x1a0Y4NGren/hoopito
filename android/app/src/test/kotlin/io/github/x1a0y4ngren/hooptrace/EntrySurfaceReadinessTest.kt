package io.github.x1a0y4ngren.hooptrace

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EntrySurfaceReadinessTest {
    @Test
    fun waitsForInitialSurfaceAndRepliesToEachRequestOnce() {
        val readiness = EntrySurfaceReadiness()
        val replies = mutableListOf<Boolean>()
        readiness.waitUntilReady { replies += it }
        readiness.waitUntilReady { replies += it }
        assertTrue(replies.isEmpty())

        readiness.surfaceReady()
        readiness.surfaceReady()
        assertEquals(listOf(true, true), replies)
        readiness.waitUntilReady { replies += it }
        assertEquals(listOf(true, true, true), replies)
    }

    @Test
    fun aLostSurfaceRequiresFreshReadiness() {
        val readiness = EntrySurfaceReadiness()
        readiness.surfaceReady()
        readiness.surfaceLost()
        var replied = false
        readiness.waitUntilReady { replied = it }
        assertFalse(replied)
        readiness.surfaceReady()
        assertTrue(replied)
    }

    @Test
    fun disposalReleasesPendingRequestsAndRejectsLaterRequests() {
        val readiness = EntrySurfaceReadiness()
        val replies = mutableListOf<Boolean>()
        readiness.waitUntilReady { replies += it }
        readiness.dispose()
        readiness.surfaceReady()
        readiness.waitUntilReady { replies += it }
        assertEquals(listOf(false, false), replies)
    }
}
