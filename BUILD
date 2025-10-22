"""
Root BUILD file for aws-lc-repro project.

This file defines:
1. FIPS configuration flag and settings for conditional compilation
2. Test suites to validate FIPS/non-FIPS dependency separation
3. Export of utility scripts used by the build system

The primary purpose is to establish build-time configuration for choosing between
FIPS-compliant (aws-lc-fips-sys) and standard (ring) cryptographic libraries.
"""

load("@bazel_skylib//rules:native_binary.bzl", "native_test")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

# FIPS mode build flag.
# When enabled, builds use aws-lc-fips-sys for cryptography (FIPS 140-2 Level 1 validated).
# When disabled, builds use ring for cryptography (faster, simpler, but not FIPS validated).
# This flag enables conditional compilation across the entire build tree.
bool_flag(
    name = "fips",
    build_setting_default = False,
    visibility = ["//visibility:public"],
)

# Config setting that allows select() statements to choose between FIPS and non-FIPS targets.
# Use this in BUILD files to conditionally include different dependencies or configurations
# based on whether FIPS mode is enabled.
config_setting(
    name = "fips_enabled",
    flag_values = {":fips": "true"},
)

# Validates that non-FIPS builds correctly exclude AWS-LC dependencies.
# This test ensures clean separation between cryptographic backends by verifying
# that ring is present but aws-lc-* crates are absent from the dependency graph.
# This prevents accidental inclusion of FIPS libraries in non-FIPS builds,
# which would increase binary size and build complexity unnecessarily.
native_test(
    name = "test_nonfips_dependencies",
    src = "@jq",
    args = [
        "-e",
        "'.crates | map({key: .name, value: true}) | from_entries | {ring, \"aws-lc-sys\", \"aws-lc-fips-sys\", \"aws-lc-rs\"} | stderr | . == {\"ring\":true,\"aws-lc-sys\":null,\"aws-lc-fips-sys\":null,\"aws-lc-rs\":null}'",
        "$(location :cargo-bazel-nofips-lock.json)",
    ],
    data = [":cargo-bazel-nofips-lock.json"],
)

# Validates that FIPS builds correctly include AWS-LC and exclude ring.
# This test ensures FIPS compliance by verifying only validated cryptographic
# libraries are present in the dependency graph. Including ring would violate
# FIPS requirements as it's not a validated cryptographic module.
native_test(
    name = "test_fips_dependencies",
    src = "@jq",
    args = [
        "-e",
        "'.crates | map({key: .name, value: true}) | from_entries | {ring, \"aws-lc-sys\", \"aws-lc-fips-sys\", \"aws-lc-rs\"} | stderr | . == {\"ring\":null,\"aws-lc-sys\":true,\"aws-lc-fips-sys\":true,\"aws-lc-rs\":true}'",
        "$(location :cargo-bazel-fips-lock.json)",
    ],
    data = [":cargo-bazel-fips-lock.json"],
)

# Test suite for validating correct dependency resolution.
# These tests ensure the FIPS/non-FIPS build configuration correctly
# selects the appropriate cryptographic backend and excludes the other.
test_suite(
    name = "test_dependencies",
    tests = [
        ":test_fips_dependencies",
        ":test_nonfips_dependencies",
    ],
)

# Aggregate test suite for all tests in the repository.
# This allows running all tests with a single command, simplifying
# validation of both FIPS and non-FIPS configurations.
test_suite(
    name = "test",
    tests = [
        ":test_dependencies",
        "//aws_lc_repro:test",
    ],
)

# Export build support files for use by external repositories.
# The wrapper scripts work around cross-compilation issues with aws-lc-fips-sys.
# Cargo files are exported for crate_universe to process dependencies.
exports_files(
    glob(["*_wrapper.sh"]) + [
        "Cargo.toml",
        "Cargo.lock",
    ],
)
