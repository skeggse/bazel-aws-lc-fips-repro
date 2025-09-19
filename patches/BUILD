"""
BUILD file for aws-lc-fips-sys patches.

This directory contains patches that fix cross-compilation issues in aws-lc-fips-sys.
The patches are applied during the crate build process to enable proper
cross-platform builds, especially when building Linux binaries from macOS hosts.

The patches address:
- Go binary path configuration for the FIPS delocation process
- Ranlib tool compatibility issues during cross-compilation
"""

# Export patch files for use by the crates_repository rule.
# These patches are applied to aws-lc-fips-sys before its build script runs,
# fixing cross-compilation issues that would otherwise cause build failures.
exports_files(
    glob(["*.patch"]),
)
