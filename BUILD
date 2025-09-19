load("@bazel_skylib//rules:native_binary.bzl", "native_test")

# Test that the nonfips dependencies include `ring` but not `aws-lc`.
native_test(
    name = "test_nonfips_dependencies",
    src = "@jq",
    data = [":cargo-bazel-nofips-lock.json"],
    args = [
        "-e",
        "'.crates | map({key: .name, value: true}) | from_entries | {ring, \"aws-lc-sys\", \"aws-lc-fips-sys\", \"aws-lc-rs\"} | stderr | . == {\"ring\":true,\"aws-lc-sys\":null,\"aws-lc-fips-sys\":null,\"aws-lc-rs\":null}'",
        "$(location :cargo-bazel-nofips-lock.json)"
    ],
)

# Test that the fips dependencies include `aws-lc-sys-fips` but not `ring`.
native_test(
    name = "test_fips_dependencies",
    src = "@jq",
    data = [":cargo-bazel-fips-lock.json"],
    args = [
        "-e",
        "'.crates | map({key: .name, value: true}) | from_entries | {ring, \"aws-lc-sys\", \"aws-lc-fips-sys\", \"aws-lc-rs\"} | stderr | . == {\"ring\":null,\"aws-lc-sys\":true,\"aws-lc-sys-fips\":true,\"aws-lc-rs\":true}'",
        "$(location :cargo-bazel-fips-lock.json)"
    ],
)

test_suite(
    name = "test_dependencies",
    tests = [
        ":test_nonfips_dependencies",
        ":test_fips_dependencies",
    ],
)

# Export files needed for patches
exports_files(
    glob(["*_wrapper.sh"]) + [
        "Cargo.toml",
        "Cargo.lock",
    ],
)
