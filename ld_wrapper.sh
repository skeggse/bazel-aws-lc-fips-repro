#!/bin/bash
# Wrapper script for linker to convert bare linker flags to -Wl, prefixed flags
# This is needed when CMake passes raw linker flags to clang/zig

# Get the actual linker from environment
REAL_LD="${LD}"

new_args=()
for arg in "$@"; do
    case "$arg" in
        --whole-archive|--no-whole-archive|--start-group|--end-group)
            # These are linker flags that need -Wl, prefix when using clang/zig
            new_args+=("-Wl,$arg")
            ;;
        *)
            new_args+=("$arg")
            ;;
    esac
done

# Execute the real linker with modified arguments
exec "$REAL_LD" "${new_args[@]}"