load("@container_structure_test//:defs.bzl", "container_structure_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rust_crate_index//:defs.bzl", "aliases", "all_crate_deps")
load("@rust_crate_index_fips//:defs.bzl", fips_aliases = "aliases", fips_all_crate_deps = "all_crate_deps")
load("@tar.bzl", "mutate", "tar")
load("//:multi_arch.bzl", "multi_arch")

rust_binary(
    name = "aws_lc_repro",
    srcs = ["src/main.rs"],
    aliases = select({
        "@rules_rust//rust/platform:darwin": aliases(),
        "//conditions:default": fips_aliases(),
    }),
    proc_macro_deps = select({
        "@rules_rust//rust/platform:darwin": all_crate_deps(proc_macro = True),
        "//conditions:default": fips_all_crate_deps(proc_macro = True),
    }),
    visibility = ["//visibility:public"],
    deps = select({
        "@rules_rust//rust/platform:darwin": all_crate_deps(),
        "//conditions:default": fips_all_crate_deps(),
    }),
)

tar(
    name = "aws_lc_repro.tar",
    srcs = [":aws_lc_repro"],
    mutate = mutate(strip_prefix = "aws_lc_repro/aws_lc_repro.runfiles"),
    compress = "gzip",
)

oci_image(
    name = "image.input",
    base = "@distroless_base",
    tars = [":aws_lc_repro.tar"],
    cmd = ["/aws_lc_repro"],
)

multi_arch(
    name = "image.amd64",
    image = ":image.input",
    platforms = ["@zig_sdk//platform:linux_amd64"],
)

multi_arch(
    name = "image.arm64",
    image = ":image.input",
    platforms = ["@zig_sdk//platform:linux_arm64"],
)

oci_image_index(
    name = "image",
    images = [":image.amd64"],
)

container_structure_test(
    name = "test.amd64",
    configs = ["test.json"],
    image = ":image.amd64",
    platform = "linux/amd64",
)

container_structure_test(
    name = "test.arm64",
    configs = ["test.json"],
    image = ":image.arm64",
    platform = "linux/arm64",
)

test_suite(
    name = "test",
    tests = [
        ":test.amd64",
        ":test.arm64",
    ],
)
