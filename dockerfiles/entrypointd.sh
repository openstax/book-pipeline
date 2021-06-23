#!/bin/sh

# ***********************
# CUSTOM: Customization notes
# ***********************
#
# GOOGLE_SERVICE_ACCOUNT_CREDENTIALS is a string with JSON in it (curly-braces).
# secret-vars assume that curly-braces in environment variables contain values that will be replaced.
# So it fails because JSON contains double-quotes within the curly-braces.
# 
# The only change to this flie is the line that comments ". secret-vars"
#
# Source: https://github.com/sudo-bmitch/docker-base/blob/2bc11becb270195e6ab7f91f999c14f09456c1a7/bin/entrypointd.sh
#
#

# Copyright: Brandon Mitchell
# License: MIT

set -e
# Handle a kill signal before the final "exec" command runs
trap "{ exit 0; }" TERM INT

# strip off "/bin/sh -c" args from a string CMD
if [ $# -gt 1 ] && [ "$1" = "/bin/sh" ] && [ "$2" = "-c" ]; then
  shift 2
  eval "set -- $1"
fi

if [ -f /.volume-cache/volume-list.already-run ]; then
  rm /.volume-cache/volume-list.already-run
fi

# CUSTOM: This is the custom code
# . secret-vars

for ep in /etc/entrypoint.d/*; do
  ext="${ep##*.}"
  if [ "${ext}" = "env" ] && [ -f "${ep}" ]; then
    # source files ending in ".env"
    echo "Sourcing: ${ep} $@"
    set -a && . "${ep}" "$@" && set +a
  elif [ "${ext}" = "sh" ] && [ -x "${ep}" ]; then
    # run scripts ending in ".sh"
    echo "Running: ${ep} $@"
    "${ep}" "$@"
  fi
done

# load any cached volumes
if [ -f /.volume-cache/volume-list -a ! -f /.volume-cache/volume-list.already-run ]; then
  load-volume -a
fi

# Default to the prior entrypoint if defined
if [ -n "$ORIG_ENTRYPOINT" ]; then
  set -- "$ORIG_ENTRYPOINT" "$@"
fi

# run a shell if there is no command passed
if [ $# = 0 ]; then
  if [ -x /bin/bash ]; then
    set -- /bin/bash
  else
    set -- /bin/sh
  fi
fi

# include tini if requested
if [ -n "${USE_INIT}" ]; then
  set -- tini -- "$@"
fi

# include gosu with user if requested
if [ -n "${RUN_AS}" ] && [ "$(id -u)" = "0" ]; then
  set -- gosu "${RUN_AS}" "$@"
  # fix stdout/stderr permissions to allow non-root user
  chown --dereference "${RUN_AS}" "/proc/$$/fd/1" "/proc/$$/fd/2" || :
fi

# run command with exec to pass control
echo "Running CMD: $@"
exec "$@"