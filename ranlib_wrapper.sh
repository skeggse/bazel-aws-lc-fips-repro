#!/bin/bash
# Wrapper script to make 'ar' act like 'ranlib'
# ranlib is equivalent to 'ar s' - it updates the symbol table in an archive

# Get the AR tool from environment, or default to 'ar'
AR_TOOL="${AR:-ar}"

# ranlib just takes archive files as arguments, while 'ar s' needs the 's' command
# So we need to prepend 's' to the arguments
exec "$AR_TOOL" s "$@"