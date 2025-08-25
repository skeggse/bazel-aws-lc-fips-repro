load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rust_crate_index//:defs.bzl", "aliases", "all_crate_deps")

rust_binary(
    name = "aws_lc_repro",
    srcs = ["src/main.rs"],
    aliases = aliases(),
    proc_macro_deps = all_crate_deps(proc_macro = True),
    deps = all_crate_deps(),
    visibility = ["//visibility:public"],
)
