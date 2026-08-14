package lb.bormental.junit5

import org.junit.platform.engine.FilterResult
import org.junit.platform.engine.discovery.DiscoverySelectors.selectClass
import org.junit.platform.launcher.PostDiscoveryFilter
import org.junit.platform.launcher.core.LauncherDiscoveryRequestBuilder
import org.junit.platform.launcher.core.LauncherFactory
import org.junit.platform.launcher.listeners.SummaryGeneratingListener
import org.junit.platform.reporting.legacy.xml.LegacyXmlReportGeneratingListener
import java.io.PrintWriter
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption.REPLACE_EXISTING
import kotlin.io.path.extension
import kotlin.io.path.listDirectoryEntries
import kotlin.io.path.readText
import kotlin.io.path.writeText
import kotlin.system.exitProcess

/**
 * Runs one test class on the JUnit Platform, the way Bazel expects a test to behave.
 *
 * Bazel's own test runner speaks JUnit 4 only, so java_test targets are declared with
 * use_testrunner = False and this class as the main one -- see //bzl:kt_tests.bzl. What Bazel
 * needs from a test is an exit code and, optionally, a JUnit xml report at $XML_OUTPUT_FILE;
 * both are produced here.
 *
 * Usage: JUnit5Runner <fully qualified test class>
 */
object JUnit5Runner {

    @JvmStatic
    fun main(args: Array<String>) {
        if (args.size != 1) {
            System.err.println("Usage: JUnit5Runner <fully qualified test class>")
            exitProcess(2)
        }
        val testClass = args[0]

        val request = LauncherDiscoveryRequestBuilder.request()
            .selectors(selectClass(testClass))
            .apply {
                // 'bazel test --test_filter=...', which is also how an IDE runs a single method.
                System.getenv("TESTBRIDGE_TEST_ONLY")?.let { filters(methodFilter(it)) }
            }
            .build()

        val reports = Files.createTempDirectory("junit-reports")
        val summary = SummaryGeneratingListener()

        LauncherFactory.create().execute(
            request,
            summary,
            LegacyXmlReportGeneratingListener(reports, PrintWriter(System.err)),
        )

        System.getenv("XML_OUTPUT_FILE")?.let { copyReport(reports, Path.of(it)) }

        val out = PrintWriter(System.out)
        summary.summary.printTo(out)
        summary.summary.printFailuresTo(out)
        out.flush()

        if (summary.summary.totalFailureCount > 0) exitProcess(1)
        if (summary.summary.testsFoundCount == 0L) {
            System.err.println("No tests found in $testClass")
            exitProcess(1)
        }
    }

    /**
     * Keeps the tests whose name matches the filter. A filter of the 'Class#method' shape
     * matches on the method part, which is what the IDE and --test_filter produce.
     */
    private fun methodFilter(filter: String): PostDiscoveryFilter {
        val pattern = Regex(filter.substringAfter('#', filter))
        return PostDiscoveryFilter { descriptor ->
            if (!descriptor.isTest || pattern.containsMatchIn(descriptor.displayName)) {
                FilterResult.included(null)
            } else {
                FilterResult.excluded("does not match $pattern")
            }
        }
    }

    /**
     * The legacy listener writes one file per engine; Bazel wants exactly one report. Engines
     * that had nothing to run are left out -- with one test class per target that normally
     * leaves a single file, and nothing has to be merged.
     */
    private fun copyReport(reports: Path, destination: Path) {
        val empty = Regex("<testsuite[^>]*tests=\"0\"")
        val written = reports.listDirectoryEntries()
            .filter { it.extension == "xml" && !empty.containsMatchIn(it.readText()) }
        when (written.size) {
            0 -> return
            1 -> Files.copy(written[0], destination, REPLACE_EXISTING)
            else -> destination.writeText(
                written.joinToString(
                    prefix = "<testsuites>\n",
                    separator = "\n",
                    postfix = "\n</testsuites>\n",
                ) { it.readText().substringAfter("?>").trim() },
            )
        }
    }
}
