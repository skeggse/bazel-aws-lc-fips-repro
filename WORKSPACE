"""
This WORKSPACE file configures a Bazel build environment for cross-platform Rust development
with support for FIPS-compliant cryptography libraries.

The primary purpose is to demonstrate and reproduce issues with AWS-LC FIPS (Federal Information
Processing Standards) compliant cryptographic libraries in a Rust/Bazel environment. This setup
enables switching between FIPS and non-FIPS cryptographic backends at build time.

Key capabilities:
- Cross-platform builds for Linux and macOS (x86_64 and ARM64)
- Selective FIPS compliance using aws-lc-fips-sys or ring for cryptography
- Container image creation with distroless base images
- Hermetic C/C++ toolchain using Zig for reproducible cross-compilation
"""

workspace(name = "aws_lc_repro")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Python rules are required for build tooling and test infrastructure.
http_archive(
    name = "rules_python",
    sha256 = "fa532d635f29c038a64c8062724af700c30cf6b31174dd4fac120bc561a1a560",
    strip_prefix = "rules_python-1.5.1",
    url = "https://github.com/bazel-contrib/rules_python/releases/download/1.5.1/rules_python-1.5.1.tar.gz",
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

# Rules Rust provides the core Rust build infrastructure for Bazel.
http_archive(
    # This version of rules_rust isn't super important - works with both 0.60.0 and 0.64.0.
    name = "rules_rust",
    integrity = "sha256-2GH766nwQzOgrmnkSO6D1pF/JC3bt/41xo/CEqarpUY=",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.64.0/rules_rust-0.64.0.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

# Rust toolchain version used across all builds.
RUST_VERSION = "1.86.0"

# Target platforms for cross-compilation.
SUPPORTED_PLATFORMS = [
    "x86_64-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "aarch64-apple-darwin",
    "aarch64-unknown-linux-gnu",
]

rules_rust_dependencies()

# Crate Universe enables Bazel to understand and build Cargo dependencies.
load("@rules_rust//crate_universe:repositories.bzl", "crate_universe_dependencies")

rust_register_toolchains(
    edition = "2021",
    extra_target_triples = SUPPORTED_PLATFORMS,
    sha256s = {
        "rustc-1.86.0-aarch64-apple-darwin.tar.xz": "23b8f52102249a47ab5bc859d54c9a3cb588a3259ba3f00f557d50edeca4fde9",
        "clippy-1.86.0-aarch64-apple-darwin.tar.xz": "239fa3a604b124f0312f2af08537874a1227dba63385484b468cca62e7c4f2f2",
        "cargo-1.86.0-aarch64-apple-darwin.tar.xz": "3cb13873d48c3e1e4cc684d42c245226a11fba52af6b047c3346ed654e7a05c0",
        "rustfmt-1.86.0-aarch64-apple-darwin.tar.xz": "45e2d3543ea1abc2aa5dad894452c848bf2c75df83c8b175c418166baee09d37",
        "llvm-tools-1.86.0-aarch64-apple-darwin.tar.xz": "04d3618c686845853585f036e3211eb9e18f2d290f4610a7a78bdc1fcce1ebd9",
        "rust-std-1.86.0-aarch64-apple-darwin.tar.xz": "0fb121fb3b8fa9027d79ff598500a7e5cd086ddbc3557482ed3fdda00832c61b",
    },
    versions = [RUST_VERSION],
)

crate_universe_dependencies()

# Hermetic CC Toolchain provides reproducible C/C++ compilation using Zig.
# This is essential for cross-compiling various C targets.
# The hermetic nature ensures builds are reproducible across different host systems.
http_archive(
    name = "hermetic_cc_toolchain",
    # It incorporates changes from the following PR to fix cc target parsing (previously
    # handled with asana/cc-rs).
    # https://github.com/uber/hermetic_cc_toolchain/pull/223
    sha256 = "4d672641c118e288f523159c9c678396ea122dd32fab05f67519b54b759886b4",
    strip_prefix = "hermetic_cc_toolchain-e906f270fa38c1fe0b2db346717d2f2cd90da123",
    url = "https://github.com/uber/hermetic_cc_toolchain/archive/e906f270fa38c1fe0b2db346717d2f2cd90da123.tar.gz",
)

load("@hermetic_cc_toolchain//toolchain:defs.bzl", zig_toolchains = "toolchains")

zig_toolchains()

http_archive(
    name = "aspect_bazel_lib",
    sha256 = "f525668442e4b19ae10d77e0b5ad15de5807025f321954dfb7065c0fe2429ec1",
    strip_prefix = "bazel-lib-2.21.1",
    url = "https://github.com/bazel-contrib/bazel-lib/releases/download/v2.21.1/bazel-lib-v2.21.1.tar.gz",
)

load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies", "aspect_bazel_lib_register_toolchains")

aspect_bazel_lib_dependencies()

aspect_bazel_lib_register_toolchains()

# Back-port https://github.com/bazelbuild/bazel-central-registry/blob/main/modules/gawk/5.3.2.bcr.1/source.json
# to WORKSPACE semantics. Workaround for https://github.com/bazel-contrib/tar.bzl/issues/61.
http_archive(
    name = "gawk",
    integrity = "sha256-+MNIZQnecFGSE4sA7ywAu73Q6Eww1cB9I/xzqdxMycw=",
    remote_file_integrity = {
        "BUILD.bazel": "sha256-dt89+9IJ3UzQvoKzyXOiBoF6ok/4u4G0cb0Ja+plFy0=",
        "posix/config_darwin.h": "sha256-gPVRlvtdXPw4Ikwd5S89wPPw5AaiB2HTHa1KOtj40mU=",
        "posix/config_linux.h": "sha256-iEaeXYBUCvprsIEEi5ipwqt0JV8d73+rLgoBYTegC6Q=",
    },
    remote_file_urls = {
        f: ["https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/refs/heads/main/modules/gawk/5.3.2.bcr.1/overlay/" + f]
        for f in [
            "BUILD.bazel",
            "posix/config_darwin.h",
            "posix/config_linux.h",
        ]
    },
    strip_prefix = "gawk-5.3.2",
    urls = ["https://ftpmirror.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz"],
)

http_archive(
    name = "tar.bzl",
    sha256 = "29a3c99c28deca5f8245e2fc32ffdb99c1ea69316462718f3bebfff441d36e4a",
    strip_prefix = "tar.bzl-0.5.6",
    url = "https://github.com/bazel-contrib/tar.bzl/releases/download/v0.5.6/tar.bzl-v0.5.6.tar.gz",
)

# Register Zig toolchains for cross-compilation.
# These toolchains enable building Linux binaries from macOS hosts,
# which is crucial for container image creation in CI/CD pipelines.
#
# The trailing version numbers here correspond to glibc versions, but their exact role is unclear.
# Zig complains with the following error, but omitting the version breaks in other ways.
#
#   "Build Script Warning: zig: error: version '.2.31' in target triple 'x86_64-unknown-linux-gnu.2.31' is invalid"
register_toolchains(
    "@zig_sdk//toolchain:linux_amd64_gnu.2.31",
    "@zig_sdk//toolchain:linux_arm64_gnu.2.31",
)

# Rules Foreign CC enables building CMake projects within Bazel.
# This is required because aws-lc-fips-sys uses CMake to build the
# underlying AWS-LC cryptographic library written in C.
http_archive(
    name = "rules_foreign_cc",
    sha256 = "32759728913c376ba45b0116869b71b68b1c2ebf8f2bcf7b41222bc07b773d73",
    strip_prefix = "rules_foreign_cc-0.15.1",
    url = "https://github.com/bazel-contrib/rules_foreign_cc/releases/download/0.15.1/rules_foreign_cc-0.15.1.tar.gz",
)

load("@rules_foreign_cc//foreign_cc:repositories.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies()

# Go SDK is required for building aws-lc-fips-sys.
# The AWS-LC FIPS module uses Go for its delocation process, which is necessary to meet FIPS 140-2
# Level 1 requirements for cryptographic module integrity. We may not actually use the delocator
# due to building a shared library instead of a static library, but we haven't bothered tweaking
# the build script to avoid the Go dependency.
http_archive(
    # This version of rules_go isn't super important - works with both v0.48.0 and v0.57.0.
    name = "io_bazel_rules_go",
    sha256 = "a729c8ed2447c90fe140077689079ca0acfb7580ec41637f312d650ce9d93d96",
    url = "https://github.com/bazelbuild/rules_go/releases/download/v0.57.0/rules_go-v0.57.0.zip",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_download_sdk(
    # This version of Go isn't super important - both 1.24.4 and 1.25.1 work.
    name = "go_sdk",
    sdks = {
        "darwin_amd64": ("go1.25.1.darwin-amd64.tar.gz", "1d622468f767a1b9fe1e1e67bd6ce6744d04e0c68712adc689748bbeccb126bb"),
        "darwin_arm64": ("go1.25.1.darwin-arm64.tar.gz", "68deebb214f39d542e518ebb0598a406ab1b5a22bba8ec9ade9f55fb4dd94a6c"),
        "linux_amd64": ("go1.25.1.linux-amd64.tar.gz", "7716a0d940a0f6ae8e1f3b3f4f36299dc53e31b16840dbd171254312c41ca12e"),
        "linux_arm64": ("go1.25.1.linux-arm64.tar.gz", "65a3e34fb2126f55b34e1edfc709121660e1be2dee6bdf405fc399a63a95a87d"),
    },
    version = "1.25.1",
)

go_register_toolchains()

# Dual crate repositories enable switching between FIPS and non-FIPS crypto.
# This separation is necessary because aws-lc-fips-sys and ring perform the same function, and we
# cannot ship `ring` in a FIPS-compliant binary.
load("@rules_rust//crate_universe:defs.bzl", "crate", "crates_repository")

# FIPS crate repository uses aws-lc-fips-sys for cryptographic operations.
# This provides FIPS 140-2 Level 1 validated cryptography but requires
# additional build complexity (CMake, Go, dynamic linking).
crates_repository(
    name = "rust_crate_index_fips",
    annotations = {
        "ring": [
            crate.annotation(
                override_targets = {
                    "lib": "//:doesnotcompile",
                },
            ),
        ],
        "aws-lc-fips-sys": [
            # Inspired by https://github.com/bazel-contrib/rules_foreign_cc/blob/main/examples/WORKSPACE.bazel.
            crate.annotation(
                additive_build_file = "@aws_lc_repro//:aws_lc_fips_sys.bazel",
                # Setting build_script_data makes the files available when the rule runs.
                build_script_data = [
                    "@rules_foreign_cc//toolchains:current_cmake_toolchain",
                    "@go_sdk//:files",  # Provide the entire Go SDK
                    "@aws_lc_repro//:ranlib_wrapper.sh",
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
                    "@aws_lc_repro//patches:aws-lc-fips-sys-provide-go.patch",
                    "@aws_lc_repro//patches:aws-lc-fips-sys-use-ar-as-ranlib.patch",
                ],
                # Include extra targets as dependencies.
                deps = [
                    ":crypto",
                    ":rust_wrapper",
                ],
            ),
        ],
    },
    cargo_lockfile = "//:Cargo.fips.lock",
    isolated = True,  # Allow access to host cargo registry for index
    lockfile = "//:cargo-bazel-fips-lock.json",
    manifests = ["//:Cargo.toml"],
    packages = {
        "rustls": crate.spec(
            default_features = False,
            features = [
                "fips",
                "std",
                "prefer-post-quantum",
                "logging",
                "tls12",
            ],
            package = "rustls",
            version = "0.23.31",
        ),
    },
    rust_version = RUST_VERSION,
    supported_platform_triples = SUPPORTED_PLATFORMS,
)

# Non-FIPS crate repository uses ring for cryptographic operations.
# Ring is faster to build and has fewer dependencies but is not FIPS validated.
# We default to non-FIPS on macOS because FIPS support there is experimental
# and the additional build complexity isn't justified.
crates_repository(
    name = "rust_crate_index",
    cargo_lockfile = "//:Cargo.lock",
    isolated = True,  # Allow access to host cargo registry for index
    lockfile = "//:cargo-bazel-nofips-lock.json",
    manifests = ["//:Cargo.toml"],
    packages = {
        "rustls": crate.spec(
            default_features = False,
            features = [
                "prefer-post-quantum",
                "std",
                "logging",
                "tls12",
            ],
            package = "rustls",
            version = "0.23.31",
        ),
    },
    rust_version = RUST_VERSION,
    supported_platform_triples = SUPPORTED_PLATFORMS,
)

load("@rust_crate_index//:defs.bzl", "crate_repositories")
load("@rust_crate_index_fips//:defs.bzl", crate_repositories_fips = "crate_repositories")

crate_repositories()

crate_repositories_fips()

http_archive(
    name = "rules_oci",
    sha256 = "5994ec0e8df92c319ef5da5e1f9b514628ceb8fc5824b4234f2fe635abb8cc2e",
    strip_prefix = "rules_oci-2.2.6",
    url = "https://github.com/bazel-contrib/rules_oci/releases/download/v2.2.6/rules_oci-v2.2.6.tar.gz",
)

load("@rules_oci//oci:dependencies.bzl", "rules_oci_dependencies")

rules_oci_dependencies()

load("@rules_oci//oci:repositories.bzl", "oci_register_toolchains")

oci_register_toolchains(name = "oci")

load("@rules_oci//oci:pull.bzl", "oci_pull")

oci_pull(
    name = "distroless_base",
    digest = "sha256:ccaef5ee2f1850270d453fdf700a5392534f8d1a8ca2acda391fbb6a06b81c86",
    image = "gcr.io/distroless/base",
    platforms = [
        "linux/amd64",
        "linux/arm64",
    ],
)

http_archive(
    name = "container_structure_test",
    # This is a pinned version of container-structure-test's Bazel rules that implements the
    # platform attribute.
    # https://github.com/GoogleContainerTools/container-structure-test/pull/469
    #
    # Pending https://github.com/GoogleContainerTools/container-structure-test/issues/466
    sha256 = "272624bb01c85cfac2d34aefabf2d0d3f97347b2e0bc5eef3e803fa247b38503",
    strip_prefix = "container-structure-test-56c7201716d770c0f820a9c19207ba2ea77c34f8",
    url = "https://github.com/GoogleContainerTools/container-structure-test/archive/56c7201716d770c0f820a9c19207ba2ea77c34f8.tar.gz",
)

load("@container_structure_test//:repositories.bzl", "container_structure_test_register_toolchain")

container_structure_test_register_toolchain(name = "cst")
