"""One test target per test class, so that a test module needs no bookkeeping.

Bazel runs a java_test per test class, while Kotlin wants to compile a module in one go.
kt_test_suite does both: it compiles the sources once and then wires a test target to
every *Test.kt found, plus a test_suite over all of them.

Tests are written with JUnit 5. Bazel's built-in test runner only understands JUnit 4, so
the targets run //tools/junit5 instead. The vintage engine is on the runtime classpath, so
JUnit 4 tests -- the IntelliJ test framework, when we get there -- keep working; such a
module adds @libs//:junit_junit to its deps to compile against JUnit 4.
"""

load("@rules_java//java:defs.bzl", "java_test")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")
load("//bzl:packages.bzl", "module_package")

_RUNNER = "//tools/junit5"
_RUNNER_MAIN = "lb.bormental.junit5.JUnit5Runner"

_JUNIT5 = "@libs//:org_junit_jupiter_junit_jupiter"
_JUNIT5_ENGINES = [
    "@libs//:org_junit_jupiter_junit_jupiter_engine",
    "@libs//:org_junit_vintage_junit_vintage_engine",
]

def kt_test_suite(
        name,
        srcs,
        package_prefix = None,
        source_root = "src/",
        associates = [],
        deps = [],
        runtime_deps = [],
        **kwargs):
    """Declares the tests of one test module.

    Args:
      name: name of the test_suite that runs all of them.
      srcs: the test sources, and any helpers they use.
      package_prefix: the Kotlin package the sources start with; by default the one the
        module's name implies, see //bzl:packages.bzl.
      source_root: the part of the paths that is not the Kotlin package.
      associates: modules whose internal declarations the tests may use, as
        //modules/core -- the equivalent of a JPS test module seeing its production module.
      deps: compile dependencies; JUnit 5 is added automatically.
      runtime_deps: runtime-only dependencies.
      **kwargs: passed on to every test target, e.g. size or tags.
    """
    prefix = package_prefix or module_package()
    library = name + "_lib"

    kt_jvm_library(
        name = library,
        srcs = srcs,
        testonly = True,
        associates = associates,
        deps = deps + [_JUNIT5],
    )

    tests = []
    for src in srcs:
        if not src.endswith("Test.kt"):
            continue  # a helper, compiled into the library above
        if not src.startswith(source_root):
            fail("%s is expected to live under %s" % (src, source_root))
        test_name = src[len(source_root):-len(".kt")].replace("/", ".")
        test_class = prefix + "." + test_name
        java_test(
            name = test_name,
            args = [test_class],
            main_class = _RUNNER_MAIN,
            use_testrunner = False,
            runtime_deps = runtime_deps + [":" + library, _RUNNER] + _JUNIT5_ENGINES,
            **kwargs
        )
        tests.append(":" + test_name)

    if not tests:
        fail("No *Test.kt found in %s" % native.package_name())

    native.test_suite(name = name, tests = tests)
