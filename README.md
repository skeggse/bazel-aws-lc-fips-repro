# AWS-LC FIPS + Bazel + Cross-Compilation Issue

## TL;DR

**Problem:** Bazel builds fail when compiling Rust code that uses `aws-lc-fips-sys` due to the linker being unable to locate shared libraries (`.so`/`.dylib`) that ARE successfully built but are in the wrong location.

**Why it matters:** We're migrating from `ring` to `aws-lc-fips-sys` for FIPS compliance.

**Current blocker:** The libraries exist at `bazel-out/darwin_arm64-fastbuild/bin/external/rust_crate_index__aws-lc-fips-sys-0.13.7/_bs.out_dir/build/artifacts/` but the linker searches different paths.

## Prerequisites

- Bazel 7.6.0
- Internet connection (for downloading dependencies)
- macOS (for reproducing the exact issue)

## Quick Context

This repository demonstrates build failures when using:

- **aws-lc-fips-sys**: Rust bindings to AWS-LC (Amazon's fork of BoringSSL) with FIPS compliance
- **Bazel**: Build system with hermetic toolchains for reproducible builds
- **Zig toolchain**: Used for cross-compilation but has incompatibilities with traditional compiler behavior

The core issue is that while the AWS-LC libraries compile successfully, the final linking step fails because Bazel's sandboxing and path handling don't align with where the build script places the libraries.

## Reproduction & Errors

### 1. Cross-compilation to Linux (from macOS)

These commands attempt to build for Linux targets:

```bash
# Linux AMD64
bazel build --platforms=@zig_sdk//platform:linux_amd64 //aws_lc_repro

# Linux ARM64
bazel build --platforms=@zig_sdk//platform:linux_arm64 //aws_lc_repro
```

**Error output:**

```
error: linking with `external/zig_sdk/tools/x86_64-linux-gnu.2.31/c++` failed: exit status: 1
  = note: error: unable to find dynamic system library 'aws_lc_fips_0_13_7_crypto' using strategy 'no_fallback'. searched paths:
            bazel-out/darwin_arm64-fastbuild/bin/external/rust_macos_aarch64__x86_64-unknown-linux-gnu__stable_tools/rust_toolchain/lib/rustlib/x86_64-unknown-linux-gnu/lib/libaws_lc_fips_0_13_7_crypto.so
            /private/var/tmp/_bazel_eliskeggs/e580cc93b7a734e8234364ad5cffaba6/sandbox/darwin-sandbox/166/execroot/aws_lc_repro/bazel-out/darwin_arm64-fastbuild/bin/external/rust_crate_index__aws-lc-fips-sys-0.13.7/_bs.out_dir/build/artifacts/libaws_lc_fips_0_13_7_crypto.so
            bazel-out/darwin_arm64-fastbuild/bin/external/rust_macos_aarch64__x86_64-unknown-linux-gnu__stable_tools/rust_toolchain/lib/rustlib/x86_64-unknown-linux-gnu/lib/libaws_lc_fips_0_13_7_crypto.so
```

Note the second path it searches IS correct but due to sandboxing, the actual file is at a different sandbox path.

### 2. Native macOS Build Also Fails

```bash
bazel build //aws_lc_repro
```

**Error output:**

```
error: linking with `external/local_config_cc/cc_wrapper.sh` failed: exit status: 1
  = note: ld: warning: search path '.../aws-lc-fips-sys-0.13.7/_bs.out_dir/build/artifacts' not found
          ld: library 'aws_lc_fips_0_13_7_crypto' not found
          clang: error: linker command failed with exit code 1
```

The build successfully compiles the AWS-LC libraries but fails to link them. The libraries DO exist:

```bash
$ fd libaws_lc_fips_0_13_7_crypto.so bazel-out
bazel-out/darwin_arm64-fastbuild/bin/external/rust_crate_index__aws-lc-fips-sys-0.13.7/_bs.out_dir/build/artifacts/libaws_lc_fips_0_13_7_crypto.so
```

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
  - `cc_wrapper.sh` - Fixes Zig producing object files instead of assembly with `-S`
  - `ld_wrapper.sh` - Converts linker flags to Zig-compatible format
  - `ranlib_wrapper.sh` - Uses `ar` when ranlib isn't available

### Build Configuration

- `WORKSPACE` - Configures Rust toolchain, Zig CC toolchain, Go SDK
- `Cargo.toml` / `Cargo.lock` - Rust dependencies
- Uses forked `cc-rs` to handle Zig's `--target` format differences

## What's Been Tried

| Workaround                     | Purpose                                       | Result                                                          |
| ------------------------------ | --------------------------------------------- | --------------------------------------------------------------- |
| Custom wrapper scripts         | Adapt Zig compiler behavior to match LLVM/GCC | ✅ Build succeeds, ❌ Linking fails                             |
| Patches to aws-lc-fips-sys     | Better tool discovery and hermetic builds     | ✅ CMake runs, ❌ Library paths wrong                           |
| Forked cc-rs                   | Handle Zig target format                      | ✅ Compilation works                                            |
| Environment variable injection | Pass hermetic tool paths                      | ✅ Tools found correctly                                        |
| Dynamic linking                | Work around FIPS requirements                 | ❌ May be wrong approach, static might be better for rules_rust |
| `--spawn_strategy=local`       | Disable sandboxing to avoid path issues       | ❌ Still fails, libraries not found at link time               |

## Known Technical Issues

1. **Library Path Mismatch**: Libraries are built but Bazel's sandbox path doesn't match linker search paths
2. **Zig Compiler Quirks**:
   - Produces object files instead of assembly with `-S` flag
   - Expects `linux-gnu` instead of `unknown-linux-gnu` target format
3. **FIPS Delocation**: Go-based tools have specific requirements challenging for hermetic builds
4. **Sandbox Isolation**: Bazel's sandboxing prevents the linker from finding libraries in the build output directory

## Help Needed

**Primary Issue:** The linker cannot locate the shared libraries even though they exist. The build script successfully creates:

- `libaws_lc_fips_0_13_7_crypto.so`
- `libaws_lc_fips_0_13_7_rust_wrapper.so`

But they're at: `bazel-out/darwin_arm64-fastbuild/bin/external/rust_crate_index__aws-lc-fips-sys-0.13.7/_bs.out_dir/build/artifacts/`

While the linker searches sandbox paths that don't align with this location.

**Questions:**

1. How can we make Bazel/rules_rust recognize the build script's output directory?
2. Should we pursue static linking instead of dynamic linking for better rules_rust compatibility?
3. Is there a way to copy/symlink the libraries to where the linker expects them?

## Related Issues

- [Zig Issue #4911](https://github.com/ziglang/zig/issues/4911) - Target format compatibility
- [rules_rust Issue #2529](https://github.com/bazelbuild/rules_rust/issues/2529) - Zig toolchain integration
