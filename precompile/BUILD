load("@tar.bzl", "tar")
load("//:multi_arch.bzl", "multi_arch")

tar(
    name = "precompile.tar",
    srcs = [
        "@rust_crate_index_fips__aws-lc-fips-sys-0.13.9//:libaws_lc_fips_0_13_9_crypto.so",
        "@rust_crate_index_fips__aws-lc-fips-sys-0.13.9//:libaws_lc_fips_0_13_9_rust_wrapper.so",
    ],
    compress = "gzip",
)

# Usage:
#   bazel build //precompile
#
# This will produce two tarballs, one for linux_amd64 and one for linux_arm64.
#
# You can pretty quickly determine which is why by running
#   tar -Oxzf bazel-out/darwin_arm64-fastbuild-ST-2f11d9e50307/bin/precompile/precompile.tar.tar.gz libaws_lc_fips_0_13_9_crypto.so | file -
#
# which will produce one of these outputs:
#   /dev/stdin: ELF 64-bit LSB shared object, x86-64 [...]
#   /dev/stdin: ELF 64-bit LSB shared object, ARM aarch64 [...]
multi_arch(
    name = "precompile",
    image = ":precompile.tar",
    platforms = [
        "@zig_sdk//platform:linux_amd64",
        "@zig_sdk//platform:linux_arm64",
    ],
)
