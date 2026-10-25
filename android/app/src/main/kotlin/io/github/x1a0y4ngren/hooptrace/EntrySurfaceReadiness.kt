package io.github.x1a0y4ngren.hooptrace

/** Main-thread readiness for the initial surface; no database or image work. */
internal class EntrySurfaceReadiness {
    private var ready = false
    private var disposed = false
    private val pending = mutableListOf<(Boolean) -> Unit>()

    fun waitUntilReady(reply: (Boolean) -> Unit) {
        when {
            disposed -> reply(false)
            ready -> reply(true)
            else -> pending += reply
        }
    }

    fun surfaceReady() {
        if (disposed) return
        ready = true
        completePending(true)
    }

    fun surfaceLost() {
        ready = false
    }

    fun dispose() {
        disposed = true
        ready = false
        completePending(false)
    }

    private fun completePending(value: Boolean) {
        val replies = pending.toList()
        pending.clear()
        replies.forEach { it(value) }
    }
}
