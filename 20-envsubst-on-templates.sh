#!/bin/sh
#
# Copyright (C) 2011-2023 F5, Inc.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

ME=$(basename "$0")

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

add_stream_block() {
  local conffile="/etc/nginx/nginx.conf"

  if grep -q -E "\s*stream\s*\{" "$conffile"; then
    entrypoint_log "$ME: $conffile contains a stream block; include $stream_output_dir/*.conf to enable stream templates"
  else
    # check if the file can be modified, e.g. not on a r/o filesystem
    touch "$conffile" 2>/dev/null || { entrypoint_log "$ME: info: can not modify $conffile (read-only file system?)"; exit 0; }
    entrypoint_log "$ME: Appending stream block to $conffile to include $stream_output_dir/*.conf"
    cat << END >> "$conffile"
# added by "$ME" on "$(date)"
stream {
  include $stream_output_dir/*.conf;
}
END
  fi
}

auto_envsubst() {
  local template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
  local suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
  local output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"
  local stream_suffix="${NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX:-.stream-template}"
  local stream_output_dir="${NGINX_ENVSUBST_STREAM_OUTPUT_DIR:-/etc/nginx/stream-conf.d}"
  local filter="${NGINX_ENVSUBST_FILTER:-}"

  local template defined_envs relative_path output_path subdir
  defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" < /dev/null ))
  [ -d "$template_dir" ] || return 0
  if [ ! -w "$output_dir" ]; then
    entrypoint_log "$ME: ERROR: $template_dir exists, but $output_dir is not writable"
    return 0
  fi
  find "$template_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
    relative_path="${template#"$template_dir/"}"
    output_path="$output_dir/${relative_path%"$suffix"}"
    subdir=$(dirname "$relative_path")
    # create a subdirectory where the template file exists
    mkdir -p "$output_dir/$subdir"
    entrypoint_log "$ME: Running envsubst on $template to $output_path"
    envsubst "$defined_envs" < "$template" > "$output_path"
  done

  # Print the first file with the stream suffix, this will be false if there are none
  if test -n "$(find "$template_dir" -name "*$stream_suffix" -print -quit)"; then
    mkdir -p "$stream_output_dir"
    if [ ! -w "$stream_output_dir" ]; then
      entrypoint_log "$ME: ERROR: $template_dir exists, but $stream_output_dir is not writable"
      return 0
    fi
    add_stream_block
    find "$template_dir" -follow -type f -name "*$stream_suffix" -print | while read -r template; do
      relative_path="${template#"$template_dir/"}"
      output_path="$stream_output_dir/${relative_path%"$stream_suffix"}"
      subdir=$(dirname "$relative_path")
      # create a subdirectory where the template file exists
      mkdir -p "$stream_output_dir/$subdir"
      entrypoint_log "$ME: Running envsubst on $template to $output_path"
      envsubst "$defined_envs" < "$template" > "$output_path"
    done
  fi
}

auto_envsubst

exit 0
