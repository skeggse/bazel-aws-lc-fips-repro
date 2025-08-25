#!/bin/bash
# Wrapper script for C compiler to ensure -S flag produces assembly text output
# This works around zig compiler producing object files even with -S flag

exec "$CC" "$@"

# # Get the actual compiler from environment
# REAL_CC="${CC}"

# # Check if -S flag is present
# has_s_flag=false
# output_file=""
# updated_output=false
# next_is_output=false
# skip_next=false
# new_args=()

# for arg in "$@"; do
#     if [ "$arg" = "-S" ]; then
#         if [ "$next_is_output" = true ]; then
#             echo "Error: -S flag cannot be used with -o without an output file specified first."
#             exit 1
#         fi
#         has_s_flag=true
#         new_args+=("$arg")
#         continue
#     fi

#     if [ "$skip_next" = true ]; then
#         skip_next=false
#         continue
#     fi

#     if [ "$next_is_output" = true ]; then
#         output_file="$arg"
#         # If we have -S flag and output ends with .o, change it to .s
#         if [ "$has_s_flag" = true ] && [[ "$arg" == *.o ]]; then
#             new_args+=("${arg%.o}.s")
#             updated_output=true
#         else
#             new_args+=("$arg")
#         fi
#         next_is_output=false
#     elif [ "$arg" = "-o" ]; then
#         if [ "$updated_output" = true ]; then
#             echo "Error: Multiple -o flags are not supported in this wrapper."
#             exit 1
#         fi
#         new_args+=("$arg")
#         next_is_output=true
#     elif [ "$has_s_flag" ]; then
#         if [ "$arg" = "-c" ] || [ "$arg" == "-MD" ]; then
#             # Skip -c if -S is present
#             continue
#         fi
#         if [ "$arg" = "-MT" ] || [ "$arg" = "-MF" ]; then
#             # Skip -MT and -MF and their next arguments if -S is present
#             skip_next=true
#             continue
#         fi
#         new_args+=("$arg")
#     else
#         new_args+=("$arg")
#     fi
# done

# if [ "$updated_output" = false ]; then
#     exec "$REAL_CC" "$@"
# fi

# echo "Wrapper ran on $*" >> /tmp/cc_wrapper.log
# echo "  ${new_args[*]}" >> /tmp/cc_wrapper.log

# # Run the compiler with potentially modified arguments
# "$REAL_CC" "${new_args[@]}"
# result="$?"

# # We changed .o to .s, move the result back to .o location
# temp_output="${output_file%.o}.s"
# cp "$temp_output" /tmp/cc_wrapper_output
# if [ -f "$temp_output" ]; then
#     mv "$temp_output" "$output_file"
# fi

# # sleep 3600

# exit "$result"
