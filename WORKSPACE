workspace(name = "aws_lc_repro")


load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_python",
    sha256 = "fa532d635f29c038a64c8062724af700c30cf6b31174dd4fac120bc561a1a560",
    strip_prefix = "rules_python-1.5.1",
    url = "https://github.com/bazel-contrib/rules_python/releases/download/1.5.1/rules_python-1.5.1.tar.gz",
)

load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()


# Rules Rust
http_archive(
    name = "rules_rust",
    sha256 = "09e17b47c0150465631aa319f2742760a43ededab2e9c012f91d0ae2eff02268",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.59.2/rules_rust-0.59.2.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

RUST_VERSION = "1.86.0"

SUPPORTED_PLATFORMS = [
    "x86_64-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "aarch64-apple-darwin",
    "aarch64-unknown-linux-gnu",
]

rules_rust_dependencies()

# Crate Universe for managing Rust dependencies
load("@rules_rust//crate_universe:repositories.bzl", "crate_universe_dependencies")

rust_register_toolchains(
    edition = "2021",
    extra_target_triples = SUPPORTED_PLATFORMS,
    versions = [RUST_VERSION],
)

crate_universe_dependencies()

# Hermetic CC Toolchain (Zig)
http_archive(
    name = "hermetic_cc_toolchain",
    sha256 = "907745bf91555f77e8234c0b953371e6cac5ba715d1cf12ff641496dd1bce9d1",
    urls = [
        "https://mirror.bazel.build/github.com/uber/hermetic_cc_toolchain/releases/download/v3.1.1/hermetic_cc_toolchain-v3.1.1.tar.gz",
        "https://github.com/uber/hermetic_cc_toolchain/releases/download/v3.1.1/hermetic_cc_toolchain-v3.1.1.tar.gz",
    ],
)

load("@hermetic_cc_toolchain//toolchain:defs.bzl", zig_toolchains = "toolchains")

zig_toolchains()

http_archive(
    name = "aspect_bazel_lib",
    integrity = "sha256-NSKJX6E7l+iyfjtkIEVoKqQjOuGmsniq1qO0g1AdyfI=",
    strip_prefix = "bazel-lib-2.20.0",
    url = "https://github.com/bazel-contrib/bazel-lib/releases/download/v2.20.0/bazel-lib-v2.20.0.tar.gz",
)

load("@aspect_bazel_lib//lib:repositories.bzl", "register_coreutils_toolchains")

register_coreutils_toolchains()

# Register Zig toolchains for cross-compilation
register_toolchains(
    "@zig_sdk//toolchain:linux_amd64_gnu.2.31",
    "@zig_sdk//toolchain:linux_arm64_gnu.2.31",
)

# Rules Foreign CC for CMake support
http_archive(
    name = "rules_foreign_cc",
    sha256 = "32759728913c376ba45b0116869b71b68b1c2ebf8f2bcf7b41222bc07b773d73",
    strip_prefix = "rules_foreign_cc-0.15.1",
    url = "https://github.com/bazel-contrib/rules_foreign_cc/releases/download/0.15.1/rules_foreign_cc-0.15.1.tar.gz",
)

load("@rules_foreign_cc//foreign_cc:repositories.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies()

# Go SDK (needed for aws-lc-fips-sys build)
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "33acc4ae0f70502db4b893c9fc1dd7a9bf998c23e7ff2c4517741d4049a976f8",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.48.0/rules_go-v0.48.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.48.0/rules_go-v0.48.0.zip",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_download_sdk(
    name = "go_sdk",
    version = "1.24.4",
)

go_register_toolchains()

# Crate repository with aws-lc-fips-sys annotations
load("@rules_rust//crate_universe:defs.bzl", "crate", "crates_repository")

crates_repository(
    name = "rust_crate_index",
    annotations = {
        "aws-lc-fips-sys": [
            # Adapted from https://github.com/bazel-contrib/rules_foreign_cc/blob/main/examples/WORKSPACE.bazel.
            crate.annotation(
                # Setting build_script_data makes the files available when the rule runs.
                build_script_data = [
                    "@rules_foreign_cc//toolchains:current_cmake_toolchain",
                    "@go_sdk//:files",  # Provide the entire Go SDK
                    "@aws_lc_repro//:ranlib_wrapper.sh",
                    "@aws_lc_repro//:cc_wrapper.sh",
                    "@aws_lc_repro//:ld_wrapper.sh",
                ],
                build_script_env = {
                    # Provide Go binary path to the build script
                    "GO_BINARY": "$(execpath @go_sdk//:bin/go)",
                    # The toolchain supplies a value of $(CMAKE) which is an execroot-relative
                    # path, so we need to prefix it with $${pwd}/ because build scripts don't
                    # typically run in the execroot unlike most bazel rules, for improved
                    # compatibility with Cargo.
                    "CMAKE": "$${pwd}/$(CMAKE)",
                    # Provide the path to the ranlib wrapper script.
                    # This is used to ensure that the `ar` tool is used as a ranlib
                    # when cross-compiling, as the `ranlib` tool may not be available.
                    "RANLIB_WRAPPER": "$(execpath @aws_lc_repro//:ranlib_wrapper.sh)",
                    # Provide the path to the C compiler wrapper script.
                    # This works around zig compiler producing object files with -S flag
                    "CC_WRAPPER": "$(execpath @aws_lc_repro//:cc_wrapper.sh)",
                    # Provide the path to the linker wrapper script.
                    # This converts bare linker flags to -Wl, prefixed flags
                    "LD_WRAPPER": "$(execpath @aws_lc_repro//:ld_wrapper.sh)",
                    # It's pretty challenging to statically cross-compile this library using
                    # zig due to the delocation requirements for FIPS, so we instead
                    # dynamically link.
                    "AWS_LC_FIPS_SYS_STATIC": "0",
                },
                # Setting build_script_toolchains makes makefile variable substitution work so
                # that we can reference $(CMAKE) in attributes.
                build_script_toolchains = [
                    "@rules_foreign_cc//toolchains:current_cmake_toolchain",
                ],
                # Provide Go binary as a tool
                build_script_tools = ["@go_sdk//:bin/go"],
                patch_args = ["-p1"],
                # Apply patches for cross-compilation support
                patches = [
                    "@aws_lc_repro//patches/aws-lc-fips-sys-provide-go.patch",
                    "@aws_lc_repro//patches/aws-lc-fips-sys-use-ar-as-ranlib.patch",
                ],
            ),
        ],
    },
    cargo_lockfile = "//:Cargo.lock",
    isolated = True,  # Allow access to host cargo registry for index
    lockfile = "//:cargo-bazel-lock.json",
    manifests = [
        "//:Cargo.toml",
        "//:aws_lc_repro/Cargo.toml",
    ],
    rust_version = RUST_VERSION,
    supported_platform_triples = SUPPORTED_PLATFORMS,
)

load("@rust_crate_index//:defs.bzl", "crate_repositories")

crate_repositories()
