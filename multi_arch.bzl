"""
Starlark rule for multi-architecture builds.

This module provides a configuration transition that enables building the same
target for multiple CPU architectures and operating systems.

The primary purpose is enabling cross-compilation from a single host (e.g., macOS)
to multiple target platforms (Linux AMD64, Linux ARM64) without requiring multiple
build invocations or complex command-line configurations that invalidate the cache.
"""

def _multiarch_transition(_settings, attr):
    """
    Transition function that configures platform-specific builds.

    This creates separate build configurations for each specified platform,
    allowing Bazel to build the same target multiple times with different
    toolchains and platform settings.

    Args:
        _settings: Current build settings (unused)
        attr: Rule attributes containing platforms list

    Returns:
        List of configurations, one per target platform
    """
    return [
        {"//command_line_option:platforms": str(platform)}
        for platform in attr.platforms
    ]

multiarch_transition = transition(
    implementation = _multiarch_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _impl(ctx):
    """
    Rule implementation that applies platform transition to a target.

    Passes through the files from the transitioned target, which will have
    been built for the specified platform(s).

    Args:
        ctx: Rule context containing the transitioned target

    Returns:
        DefaultInfo with files from the platform-specific target
    """
    return DefaultInfo(files = depset(ctx.files.image))

multi_arch = rule(
    implementation = _impl,
    attrs = {
        "image": attr.label(cfg = multiarch_transition),
        "platforms": attr.label_list(),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = """
    Rule that builds a target for specific platform(s).

    This rule applies a configuration transition that sets the target platform,
    enabling cross-compilation from the host platform to different architectures.
    Commonly used for building Linux containers from macOS development machines.

    Example:
        multi_arch(
            name = "my_app_linux_amd64",
            image = ":my_app",
            platforms = ["@zig_sdk//platform:linux_amd64"],
        )

    This builds my_app specifically for Linux AMD64, regardless of the host platform.
    The Zig toolchain handles the cross-compilation details.
    """,
)
