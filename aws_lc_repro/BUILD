"""
BUILD file for the aws_lc_repro application.

This file demonstrates:
1. Conditional compilation of Rust binaries with FIPS/non-FIPS crypto
2. Multi-architecture container image creation
3. Container structure testing for both FIPS and non-FIPS configurations

The primary purpose is to showcase how to build a Rust application that can
dynamically switch between cryptographic backends while maintaining the same
application logic, and package it into container images for deployment.
"""

load("@bazel_skylib//rules:native_binary.bzl", "native_test")
load("@container_structure_test//:defs.bzl", "container_structure_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rust_crate_index//:defs.bzl", "aliases", "all_crate_deps")
load("@rust_crate_index_fips//:defs.bzl", fips_aliases = "aliases", fips_all_crate_deps = "all_crate_deps")
load("@tar.bzl", "mutate", "tar")
load("//:multi_arch.bzl", "multi_arch")
load("//:fips_mode.bzl", "enable_fips")

# Main Rust binary that demonstrates FIPS/non-FIPS crypto selection.
# This binary uses select() to conditionally compile with either:
# - aws-lc-fips-sys dependencies when --//:fips=true
# - ring dependencies when --//:fips=false (default)
# The application logic remains identical; only the underlying crypto changes.
rust_binary(
    name = "aws_lc_repro",
    srcs = ["src/main.rs"],
    # Conditionally select crate aliases based on FIPS mode
    aliases = select({
        "//:fips_enabled": fips_aliases(),
        "//conditions:default": aliases(),
    }),
    # Conditionally select proc macro dependencies
    proc_macro_deps = select({
        "//:fips_enabled": fips_all_crate_deps(proc_macro = True),
        "//conditions:default": all_crate_deps(proc_macro = True),
    }),
    visibility = ["//visibility:public"],
    # Conditionally select regular dependencies
    deps = select({
        "//:fips_enabled": fips_all_crate_deps(),
        "//conditions:default": all_crate_deps(),
    }),
)

# Package the binary into a tar archive for container image creation.
# The strip_prefix mutation removes the runfiles directory structure, implicitly omitting the
# copy of the binary that lives outside the runfiles directory, and including the one that
# correctly locates the dynamic libraries inside the runfiles tree.
tar(
    name = "aws_lc_repro.tar",
    srcs = [":aws_lc_repro"],
    compress = "gzip",
    mutate = mutate(strip_prefix = "aws_lc_repro/aws_lc_repro.runfiles"),
)

# Base OCI container image with the application.
# There are many reasons to use distroless, but the main one here is just smaller images to make it
# easier to reproduce the core issue.
oci_image(
    name = "image.input",
    base = "@distroless_base",
    cmd = ["/aws_lc_repro"],
    tars = [":aws_lc_repro.tar"],
)

# AMD64 Linux container image.
# Uses the multi_arch transition to build specifically for x86_64 Linux,
# enabling cross-compilation from macOS or other host platforms.
multi_arch(
    name = "image.amd64",
    image = ":image.input",
    platforms = ["@zig_sdk//platform:linux_amd64"],
)

# AMD64 Linux container image with FIPS-compliant cryptography.
# This applies the FIPS transition to force aws-lc-fips-sys usage,
# ensuring the containerized application meets FIPS 140-2 requirements.
enable_fips(
    name = "image.amd64.fips",
    target = ":image.amd64",
)

# ARM64 Linux container image.
# Uses the multi_arch transition to build specifically for ARM64 Linux,
# enabling cross-compilation from macOS or other host platforms.
multi_arch(
    name = "image.arm64",
    image = ":image.input",
    platforms = ["@zig_sdk//platform:linux_arm64"],
)

# ARM64 Linux container image with FIPS-compliant cryptography.
# This applies the FIPS transition to force aws-lc-fips-sys usage,
# ensuring the containerized application meets FIPS 140-2 requirements.
enable_fips(
    name = "image.arm64.fips",
    target = ":image.arm64",
)

# Multi-architecture image index (manifest list).
# Allows a single image reference to work on multiple architectures.
# Container runtimes automatically select the appropriate image for the host.
oci_image_index(
    name = "image",
    images = [
        ":image.amd64",
        ":image.arm64",
    ],
)

# Multi-architecture FIPS-compliant image index.
# Allows a single image reference to work on multiple architectures.
# Container runtimes automatically select the appropriate image for the host.
oci_image_index(
    name = "image.fips",
    images = [
        ":image.amd64.fips",
        ":image.arm64.fips",
    ],
)

# Validates container image structure and behavior.
# Ensures the binary is correctly packaged and produces expected output when run in the container.
container_structure_test(
    name = "test.amd64.fips",
    configs = ["test.fips.json"],
    image = ":image.amd64.fips",
    platform = "linux/amd64",
)

container_structure_test(
    name = "test.arm64.fips",
    configs = ["test.fips.json"],
    image = ":image.arm64.fips",
    platform = "linux/arm64",
)

container_structure_test(
    name = "test.amd64",
    configs = ["test.nofips.json"],
    image = ":image.amd64",
    platform = "linux/amd64",
)

container_structure_test(
    name = "test.arm64",
    configs = ["test.nofips.json"],
    image = ":image.arm64",
    platform = "linux/arm64",
)

# Run the binary directly on the host platform.
# Useful for validating local development support.
native_test(
    name = "test.host",
    src = ":aws_lc_repro",
)

# Comprehensive test suite validating all build configurations.
# Tests both architectures (AMD64, ARM64) and both crypto backends (FIPS, non-FIPS).
test_suite(
    name = "test",
    tests = [
        ":test.amd64",
        ":test.amd64.fips",
        ":test.arm64",
        ":test.arm64.fips",
        ":test.host",
    ],
)
