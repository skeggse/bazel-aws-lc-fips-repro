# AWS-LC FIPS + Bazel + Cross-Compilation Issue

## TL;DR

**Problem:** While the original build and linking issues have been resolved, new runtime and container-related issues prevent successful execution of FIPS-compliant binaries.

**Why it matters:** `ring` is not FIPS-compliant, but `aws-lc-fips-sys` is.

**Current blockers:**

- FIPS module integrity check fails due to symbol address space issues
- Container structure tests cannot locate built images
- Shared libraries have undefined symbols in cross-compiled containers
- Library paths not properly resolved in container runfiles

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

Recent commits have resolved the initial build and linking issues, but new runtime and container-related problems have emerged.

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

### 2. Container Structure Test Execution Failure

Container structure tests fail with image lookup errors despite successful image creation:

```bash
$ bazel run //aws_lc_repro:test
```

**Error output:**

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

**Analysis:** The image is successfully loaded into podman but isn't accessible to the container structure test runtime.

**Next Steps:**

- Debug container runtime integration between Bazel and podman
- Verify image naming and tagging conventions
- Check if there's a mismatch in registry configuration

### 3. Undefined Symbols in Cross-Compiled Container Libraries

The built container contains shared libraries with undefined symbols:

```bash
# readelf -Ws /w/aws_lc_repro.runfiles/aws_lc_repro/_solib_k8/[...]/libaws_lc_fips_0_13_7_crypto.so

Symbol table '.dynsym' contains 3508 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
[...]
    92: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND aws_lc_fips_0_13_7_aes_hw_encrypt
[...]
```

**Analysis:** Critical AWS-LC FIPS symbols are not being properly linked into the shared library.

**Next Steps:**

- Review the cross-compilation linking process
- Check if all necessary object files are being included
- Verify symbol visibility settings in the build

### 4. Container Runfiles Library Path Resolution

The container has incorrect library path structure:

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

**Issues:**

- The `_U_A_A` prefixed paths indicate mangled/escaped paths that aren't being properly resolved
- Executables don't receive proper library paths
- Manual LD_LIBRARY_PATH setting is required

**Next Steps:**

- Investigate Bazel's runfiles tree generation for containers
- Review how library paths are being escaped/mangled
- Check if rules_oci needs specific configuration for shared libraries

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

2. **Container Testing Infrastructure**

   - Fix container runtime integration with podman/docker
   - Resolve image naming and registry configuration issues
   - Ensure container structure tests can locate built images

3. **Cross-Compilation Linking**

   - Resolve undefined symbols in shared libraries
   - Ensure all AWS-LC object files are properly linked
   - Review symbol visibility and export settings

4. **Runfiles Path Resolution**
   - Fix library path mangling in container runfiles
   - Configure proper LD_LIBRARY_PATH or RPATH settings
   - Investigate rules_oci shared library handling

## Resolved Issues (Historical Context)

The following issues have been resolved through recent commits but are preserved for reference:

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
