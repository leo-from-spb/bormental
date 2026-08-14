"""One test target per test class, so that a test module needs no bookkeeping.

Bazel runs a java_test per test class, while Kotlin wants to compile a module in one go.
kt_test_suite does both: it compiles the sources once and then wires a test target to
every *Test.kt found, plus a test_suite over all of them.
"""

load("@rules_java//java:defs.bzl", "java_test")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library")
load("//bzl:packages.bzl", "module_package")

_JUNIT = "@libs//:junit_junit"

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
      deps: compile dependencies; JUnit is added automatically.
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
        deps = deps + [_JUNIT],
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
            test_class = test_class,
            runtime_deps = runtime_deps + [":" + library],
            **kwargs
        )
        tests.append(":" + test_name)

    if not tests:
        fail("No *Test.kt found in %s" % native.package_name())

    native.test_suite(name = name, tests = tests)
