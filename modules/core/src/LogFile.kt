package lb.bormental.core

/** One line of a diagnostic log, numbered from 1 the way an editor numbers lines. */
data class LogLine(val number: Int, val text: String)

/**
 * The content of a diagnostic log file.
 *
 * Nothing is interpreted yet — the lines are kept as they were read. The parsing of the
 * DB introspector log format belongs here.
 */
class LogFile private constructor(val lines: List<LogLine>) {

    val isEmpty: Boolean
        get() = lines.isEmpty()

    companion object {

        val EMPTY: LogFile = LogFile(emptyList())

        fun read(text: String): LogFile {
            if (text.isEmpty()) return EMPTY
            val texts = text.lineSequence().toList()

            // A file that ends with a line separator does not have an extra empty line.
            val meaningful = if (texts.last().isEmpty()) texts.dropLast(1) else texts

            return LogFile(meaningful.mapIndexed { index, line -> LogLine(index + 1, line) })
        }
    }
}
