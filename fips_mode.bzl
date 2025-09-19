"""
Starlark rule for enabling FIPS mode on build targets.

This module provides a configuration transition that forces targets to build
with FIPS-compliant cryptography (aws-lc-fips-sys) regardless of the global
build configuration. This is essential for creating FIPS-compliant artifacts
alongside non-FIPS artifacts in the same build.

The primary use case is building container images where some need FIPS compliance
for deployment in regulated environments, while others use standard crypto for
better performance in non-regulated environments.
"""

def _fips_transition(_settings, _attr):
    """
    Transition function that enables FIPS mode for a target.

    This forces the //:fips build flag to True, causing all transitive dependencies
    to use aws-lc-fips-sys instead of ring for cryptographic operations.

    Args:
        _settings: Current build settings (unused)
        _attr: Rule attributes (unused)

    Returns:
        Dictionary setting //:fips flag to True
    """
    return [{"//:fips": True}]

fips_transition = transition(
    implementation = _fips_transition,
    inputs = [],
    outputs = ["//:fips"],
)

def _impl(ctx):
    """
    Rule implementation that applies FIPS transition to a target.

    Simply passes through the files from the transitioned target,
    which will have been built with FIPS mode enabled.

    Args:
        ctx: Rule context containing the transitioned target

    Returns:
        DefaultInfo with files from the FIPS-enabled target
    """
    return DefaultInfo(files = depset(ctx.files.target))

enable_fips = rule(
    implementation = _impl,
    attrs = {
        "target": attr.label(cfg = fips_transition),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = """
    Rule that forces a target to build with FIPS-compliant cryptography.

    This rule applies a configuration transition that sets the //:fips flag to true,
    causing the target and all its dependencies to use aws-lc-fips-sys instead of ring.

    Example:
        enable_fips(
            name = "my_app_fips",
            target = ":my_app",
        )

    This creates a FIPS-compliant version of my_app without requiring global configuration changes.
    """,
)
