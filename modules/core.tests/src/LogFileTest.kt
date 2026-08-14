package lb.bormental.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class LogFileTest {

    @Test
    fun `an empty text has no lines`() {
        assertTrue(LogFile.read("").isEmpty)
    }

    @Test
    fun `lines are numbered from one`() {
        val log = LogFile.read("first\nsecond")

        assertEquals(listOf(LogLine(1, "first"), LogLine(2, "second")), log.lines)
    }

    @Test
    fun `a trailing line separator does not add a line`() {
        assertEquals(listOf(LogLine(1, "the only line")), LogFile.read("the only line\n").lines)
    }

    @Test
    fun `an empty line inside the text is kept`() {
        assertEquals(3, LogFile.read("first\n\nthird\n").lines.size)
    }
}
