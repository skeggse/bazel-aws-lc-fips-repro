# AWS-LC FIPS + Bazel + Cross-Compilation Issue

## TL;DR

**Problem:** AWS-LC FIPS module fails integrity checks when building with Bazel due to symbol address space issues in the host toolchain compilation.

**Why it matters:** `ring` is not FIPS-compliant, but `aws-lc-fips-sys` is.

**Current blockers:**

- FIPS module integrity check fails due to symbol address space issues when compiling with host toolchain
- Host toolchain is used instead of cross-compiling toolchain when compiling for the current platform

## Prerequisites

- Bazel 7.6.0
- Internet connection (for downloading dependencies)
- macOS (for reproducing the exact issue)

## Quick Context

This repository demonstrates issues when using:

- **aws-lc-fips-sys**: Rust bindings to AWS-LC (Amazon's fork of BoringSSL) with FIPS compliance
- **Bazel**: Build system with hermetic toolchains for reproducible builds
- **Zig toolchain**: Used for cross-compilation but has incompatibilities with traditional compiler behavior
- **container-structure-test**: Testing framework for validating container images, facing runtime integration issues

Recent commits have resolved the cross-compilation build and linking issues. The remaining issue is that the FIPS module integrity check fails when using the host toolchain.

## Current Issues & Reproduction

### 1. FIPS Module Symbol Address Space Issue

Running the binary with host C++ toolchain results in FIPS integrity check failure:

```bash
$ bazel run //aws_lc_repro
```

**Error output:**

```
FIPS module doesn't span expected symbol (AES_encrypt). Expected 0x102ef7298 <= 0x102e11b00 < 0x102ef72a0
Abort trap: 6
```

**Analysis:** This appears to be related to relocation handling in the FIPS module, as described in AWS-LC's FIPS documentation (section "Integrity Test" > "Linux Shared build"). The FIPS module expects all cryptographic symbols to be within a specific address range for integrity verification.

**Next Steps:**

- Investigate relocation handling in the build process
- Review linker flags and how symbols are being positioned
- Consider if static linking would resolve this issue

### 2. Host Toolchain vs Cross-Compilation Toolchain

When building for the current platform (e.g., macOS on macOS), Bazel uses the host toolchain instead of the cross-compiling toolchain. This causes inconsistent behavior between native and cross-compiled builds.

**Analysis:** The host toolchain compilation path differs from the cross-compilation path, leading to different symbol layouts and potential FIPS integrity check failures.

**Next Steps:**

- Force use of cross-compilation toolchain even for current platform
- Investigate toolchain selection logic in Bazel
- Compare symbol layouts between host and cross-compiled binaries

## Debugging Recommendations

When debugging this issue, use these Bazel flags for more visibility:

```bash
bazel build \
  --sandbox_debug \
  --verbose_failures \
  --subcommands \
  --toolchain_resolution_debug=@bazel_tools//tools/cpp:toolchain_type \
  --@rules_rust//cargo/settings:debug_std_streams_output_group=true \
  //aws_lc_repro
```

## Repository Structure

### Core Application

- `aws_lc_repro/` - Rust binary that calls AWS-LC to print version
  - Simple test case to verify linking works

### Compatibility Layer

- **Patches** - Modifications to make aws-lc-fips-sys work with Bazel:

  - `aws-lc-fips-sys-provide-go.patch` - Accepts Go path via environment
  - `aws-lc-fips-sys-use-ar-as-ranlib.patch` - Handles cross-compilation tools

- **Wrapper Scripts** - Work around Zig compiler differences:

  - `ld_wrapper.sh` - Converts linker flags to Zig-compatible format
  - `ranlib_wrapper.sh` - Uses `ar` when ranlib isn't available

### Build Configuration

- `WORKSPACE` - Configures Rust toolchain, Zig CC toolchain, Go SDK
- `Cargo.toml` / `Cargo.lock` - Rust dependencies
- Uses forked `cc-rs` to handle Zig's `--target` format differences

## Overall Action Items

1. **FIPS Module Integrity (Priority 1)**

   - Debug symbol relocation and address space layout
   - Investigate if static linking would resolve the integrity check
   - Review AWS-LC FIPS documentation for Bazel-specific guidance

2. **Toolchain Selection**

   - Force use of cross-compilation toolchain even for current platform
   - Investigate why host toolchain is selected for native builds
   - Compare symbol layouts between different toolchain builds

## Resolved Issues (Historical Context)

The following issues have been resolved through recent commits but are preserved for reference:

### Container Structure Test Execution (Resolved)

Previously, container structure tests failed with image lookup errors because the `structure_test` binary was trying to use the wrong platform.

```bash
$ bazel run //aws_lc_repro:test
```

**Previous error output:**

```
exec ${PAGER:-/usr/bin/less} "$0" || exit 1
Executing tests from //aws_lc_repro:test
-----------------------------------------------------------------------------
Loaded  cst.oci.local/sha256-b8cf81a4fff1635b8ec55544461230a2cea815442d8aef018d1cd27f4fd4bdc3:sha256-b8cf81a4fff1635b8ec55544461230a2cea815442d8aef018d1cd27f4fd4bdc3

==================================
====== Test file: test.json ======
==================================
=== RUN: Command Test: execute fips binary
--- FAIL
duration: 2.474125ms
Error: Error creating container: API error (404): no such image: cst.oci.local/sha256-b8cf81a4fff1635b8ec55544461230a2cea815442d8aef018d1cd27f4fd4bdc3:sha256-b8cf81a4fff1635b8ec55544461230a2cea815442d8aef018d1cd27f4fd4bdc3: image not known

FAIL
```

**Resolution:** Fixed by explicitly setting the `platform` attribute and upgrading the container-structure-test rules to support that attribute.

### Undefined Symbols in Cross-Compiled Libraries (Resolved)

Previously, cross-compiled containers had shared libraries with undefined symbols like `aws_lc_fips_0_13_7_aes_hw_encrypt`.

**Previous issue:**

```bash
# readelf -Ws /w/aws_lc_repro.runfiles/aws_lc_repro/_solib_k8/[...]/libaws_lc_fips_0_13_7_crypto.so

Symbol table '.dynsym' contains 3508 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
[...]
    92: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND aws_lc_fips_0_13_7_aes_hw_encrypt
[...]
```

Critical AWS-LC FIPS symbols were not being properly linked into the shared library.

**Resolution:** Fixed by upgrading Zig from 0.12 to 0.14.0, which improved linking behavior.

### Container Runfiles Library Path Resolution (Resolved)

Previously, the container had incorrect library path structure with mangled/escaped paths, causing executables to fail to find their shared libraries.

**Previous issue:**

```
/aws_lc_repro.runfiles
├── _repo_mapping
├── aws_lc_repro
│   ├── _solib_k8
│   │   ├── _U_A_Arust_Ucrate_Uindex_U_Uaws-lc-fips-sys-0.13.7_S_S_Ccrypto___Uexternal_Srust_Ucrate_Uindex_U_Uaws-lc-fips-sys-0.13.7
│   │   │   └── libaws_lc_fips_0_13_7_crypto.so
│   │   └── _U_A_Arust_Ucrate_Uindex_U_Uaws-lc-fips-sys-0.13.7_S_S_Crust_Uwrapper___Uexternal_Srust_Ucrate_Uindex_U_Uaws-lc-fips-sys-0.13.7
│   │       └── libaws_lc_fips_0_13_7_rust_wrapper.so
│   └── aws_lc_repro
│       └── aws_lc_repro
└── aws_lc_repro
```

The `_U_A_A` prefixed paths indicated mangled/escaped paths that weren't being properly resolved. Executables didn't receive proper library paths, requiring manual LD_LIBRARY_PATH setting.

**Resolution:** Fixed by explicitly using the `aws_lc_repro` executable inside the `aws_lc_repro.runfiles` directory instead of the one outside the runfiles.

### Previously: Build and Linking Failures

**Original Problem:** Bazel builds failed when compiling Rust code using `aws-lc-fips-sys` due to the linker being unable to locate shared libraries that were successfully built but in the wrong location.

**Resolution:** Fixed through wrapper scripts and build configuration updates in recent commits.

#### Cross-compilation Issues (Resolved)

Previously failed with:

```
error: unable to find dynamic system library 'aws_lc_fips_0_13_7_crypto' using strategy 'no_fallback'
```

#### Native macOS Build (Resolved)

Previously failed with:

```
ld: library 'aws_lc_fips_0_13_7_crypto' not found
```

#### Runtime Library Loading (Partially Resolved)

Previously failed with:

```
dyld[82196]: Library not loaded: @rpath/libaws_lc_fips_0_13_7_crypto.dylib
```

### Known Technical Challenges

1. **Zig Compiler Quirks** (Addressed via wrappers and forks):

   - Expects different `--target` format than LLVM (e.g., `x86_64-linux-gnu` instead of `x86_64-unknown-linux-gnu`)
   - Requires `-Wl,` prefix for certain linker flags when passed to clang/zig (handled by `ld_wrapper.sh`)
   - Lacks traditional `ranlib` tool, requiring `ar s` as substitute (handled by `ranlib_wrapper.sh`)

2. **Static Linking Limitations**: FIPS module delocation fails with assembly errors when attempting static linking, requiring dynamic linking approach.

### Previous Workarounds Applied

| Workaround                     | Purpose                                       | Status         |
| ------------------------------ | --------------------------------------------- | -------------- |
| Custom wrapper scripts         | Adapt Zig compiler behavior to match LLVM/GCC | ✅ Implemented |
| Patches to aws-lc-fips-sys     | Better tool discovery and hermetic builds     | ✅ Applied     |
| Forked cc-rs                   | Handle Zig target format                      | ✅ In use      |
| Environment variable injection | Pass hermetic tool paths                      | ✅ Configured  |

## Related Issues & Resources

- [Zig Issue #4911](https://github.com/ziglang/zig/issues/4911) - Target format compatibility
- [rules_rust Issue #2529](https://github.com/bazelbuild/rules_rust/issues/2529) - Zig toolchain integration
- [AWS-LC FIPS Documentation](https://github.com/aws/aws-lc/blob/main/crypto/fipsmodule/FIPS.md) - FIPS module requirements and integrity testing
