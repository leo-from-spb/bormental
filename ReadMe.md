Plugin Dr.Bormental for IntelliJ Idea
=====================================

This is a plugin for DataGrip developers, 
that plugin helps to look thru diagnostic log files and investigate problems related to DB Introspector.


Building
--------

The build is Bazel, not Gradle. Nothing but
[bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`) has to be installed;
it picks up the Bazel version from `.bazelversion`.

    bazel build //:plugin      # the installable zip: bazel-bin/Bormental-<version>.zip
    bazel test //...           # the checks
    ./tools/run-ide.sh         # start a local IDE with the plugin, in a sandbox

The zip can also be installed by hand: *Settings | Plugins | ⚙ | Install Plugin from Disk*.


### The platform to compile against

By default the pinned IntelliJ IDEA Community distribution named in `bzl/intellij_sdk.bzl` is
downloaded once (~670 MB, kept in the Bazel repository cache). To compile against an IDE that is
already installed instead — a DataGrip nightly, say — point `BORMENTAL_IDE_HOME` at it, either at
the IDE home or at the macOS `.app` bundle:

    echo 'common --repo_env=BORMENTAL_IDE_HOME=/Users/me/Applications/DataGrip Night.app' \
        >> .bazelrc.local

`.bazelrc.local` is not shared, so everyone can aim at their own IDE. `tools/run-ide.sh` reads the
same variable, and falls back to the first locally installed IDE it finds.


Layout
------

    MODULE.bazel                      Bazel dependencies (bzlmod)
    maven_install.json                the lock file of the Maven dependencies
    BUILD.bazel                       the distribution zip
    modules/core/                     reading and interpreting the logs, no IDE involved
    modules/core.tests/               its tests
    modules/plugin/                   the IDE side: plugin.xml, tool windows, actions
    bzl/intellij_sdk.bzl              makes the IntelliJ Platform a plain java dependency
    bzl/kt_tests.bzl                  kt_test_suite: a test target per test class
    bzl/packages.bzl                  how directories map to Kotlin packages
    bzl/plugin_version.bzl            the plugin version, checked against plugin.xml
    bzl/BUILD.bazel                   the Kotlin toolchain (Kotlin 2.3, JVM target 21)
    tools/junit5/                     the JUnit 5 entry point Bazel's test rules lack
    tools/run-ide.sh                  runIde, by hand


### Modules

A module is a directory under `modules/` with a `BUILD.bazel` of its own — in Bazel terms a
package. Sources live in its `src/`, resources next to it in `resources/`.

Directories inside `src/` do not repeat the Kotlin package. Everything in a module starts with
the module's own package, `lb.bormental.<module>`, and the rest of the path continues it:

    modules/core/src/LogFile.kt                       lb.bormental.core
    modules/core/src/language/Definition.kt           lb.bormental.core.language
    modules/core.tests/src/language/DefinitionTest.kt lb.bormental.core.language
    modules/plugin/src/BormentalToolWindowFactory.kt  lb.bormental.plugin

A test module shares the package of the module it tests — no `.tests` in the package name. Bazel
and Kotlin do not care about any of this; `bzl/packages.bzl` is where the convention is written
down, and `kt_test_suite` uses it to turn a file path into a test class name.

A new module is three steps: create `modules/<name>/BUILD.bazel` with a `kt_jvm_library`, let
`package(default_visibility = ...)` say who may depend on it, and — when it belongs in the
distribution — add its jar to `PLUGIN_MODULES` in the root `BUILD.bazel`.

Tests get a module of their own, `modules/<name>.tests/`, the way JPS test modules do. The
`associates` attribute is what lets them see the `internal` declarations of the module they test:

    kt_test_suite(
        name = "core.tests",
        srcs = glob(["src/**/*.kt"]),
        associates = ["//modules/core"],
    )

Tests are JUnit 5; `@libs//:org_junit_jupiter_junit_jupiter` is on their classpath by default.
The vintage engine is there too, so a JUnit 4 test runs as well — a module that wants to write
one (the IntelliJ test framework is JUnit 4 based) adds `@libs//:junit_junit` to its `deps`.

`kt_test_suite` compiles the sources once and then declares one test target per `*Test.kt`, plus
a suite over all of them:

    bazel test //...                                    # everything
    bazel test //modules/core.tests                     # one module
    bazel test //modules/core.tests:LogFileTest         # one class
    bazel test //modules/core.tests:language.DefinitionTest   # ... in a subpackage


### Notes on the Bazel setup

* There is no official Bazel ruleset for IntelliJ plugins, so the Gradle conveniences are absent:
  no `runIde` (hence `tools/run-ide.sh`), no `verifyPlugin`, no patching of `plugin.xml`. The
  version in `plugin.xml` is instead checked against `bzl/plugin_version.bzl` by
  `//modules/plugin:plugin_version_test`.
* Bazel's built-in test runner speaks JUnit 4 only, so test targets run `//tools/junit5` instead:
  fifty lines that hand a test class to the JUnit Platform and leave a report where Bazel looks
  for it. The alternative, `contrib_rules_jvm`, drags in gazelle, rules_go and protobuf.
* `@intellij_sdk//:sdk` is `neverlink`: platform jars are compiled against, never packaged. The
  Kotlin stdlib comes from the platform (`lib/util-8.jar`) for the same reason.
* Bundled plugins (`com.intellij.database` and friends) are not on the compile classpath yet. Add
  their directory names to `bundled_plugins` in `bzl/intellij_sdk.bzl` and depend on the generated
  `@intellij_sdk//:plugin_<name>` target.
* To open the project in an IDE with working resolution, the
  [Bazel plugin](https://plugins.jetbrains.com/plugin/22977-bazel) is needed; the checked-in
  `.idea` files predate the Bazel build.

