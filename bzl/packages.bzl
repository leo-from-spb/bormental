"""The rule that maps Bazel packages to Kotlin packages.

Directories inside a module do not repeat the Kotlin package: everything under a module's
src/ starts with the module's own package, so that paths stay short.

    modules/core/src/language/Definition.kt          lb.bormental.core.language
    modules/core.tests/src/language/DefinitionTest.kt    the same package, so that tests
                                                         sit next to what they test
    modules/plugin/src/BormentalToolWindowFactory.kt lb.bormental.plugin
"""

ROOT_PACKAGE = "lb.bormental"

def module_package(bazel_package = None):
    """The Kotlin package the sources of a module start with.

    Args:
      bazel_package: the module, as modules/core; the current package by default.

    Returns:
      The package prefix, as lb.bormental.core.
    """
    package = bazel_package or native.package_name()
    module = package.split("/")[-1]

    # A test module shares the package of the module it tests.
    if module.endswith(".tests"):
        module = module[:-len(".tests")]

    if not module:
        fail("%s is not a module directory." % package)

    return ROOT_PACKAGE + "." + module
