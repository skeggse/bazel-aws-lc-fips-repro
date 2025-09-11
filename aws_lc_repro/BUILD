load("@container_structure_test//:defs.bzl", "container_structure_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rust_crate_index//:defs.bzl", "aliases", "all_crate_deps")
load("@tar.bzl", "mutate", "tar")
load("//:multi_arch.bzl", "multi_arch")

rust_binary(
    name = "aws_lc_repro",
    srcs = ["src/main.rs"],
    aliases = aliases(),
    proc_macro_deps = all_crate_deps(proc_macro = True),
    visibility = ["//visibility:public"],
    deps = all_crate_deps(),
)

tar(
    name = "aws_lc_repro.tar",
    srcs = [":aws_lc_repro"],
    mutate = mutate(strip_prefix = "aws_lc_repro"),
    compress = "gzip",
)

oci_image(
    name = "image.input",
    base = "@distroless_base",
    tars = [":aws_lc_repro.tar"],
    cmd = ["/aws_lc_repro"],
)

multi_arch(
    name = "image.transition",
    image = ":image.input",
    platforms = [
        # Label("//tools/starlark/oci/platforms:linux_amd64"),
        # Label("//tools/starlark/oci/platforms:linux_arm64"),
        "@zig_sdk//platform:linux_amd64",
    ],
)

oci_image_index(
    name = "image",
    images = [":image.transition"],
)

container_structure_test(
    name = "test",
    configs = ["test.json"],
    image = ":image.transition",
)
