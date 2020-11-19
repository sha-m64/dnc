#!/usr/bin/env bash
set -ue

PRG_NAME="$0"

err() {
  if [[ -t 2 ]] # check whether stderr is a tty.
  then
    echo -ne "\\033[4;31mError\\033[0m: " >&2
  else
    echo -n "Error: " >&2
  fi

  echo "$*" >&2
}

warn() {
  if [[ -t 2 ]] # check whether stderr is a tty.
  then
    echo -ne "\\033[33mWarn\\033[0m: " >&2
  else
    echo -n "Warn: " >&2
  fi

  echo "$*" >&2

}

die() {
  err "$@"
  exit 1
}

required() {
  for pkg in "$@"
  do
    command -v "$pkg" >/dev/null 2>&1 || die "'$pkg' is required"
  done
}

usage() {
  cat <<HELP 
Usage: ${PRG_NAME} [--path=path/to/lib | --restore] libname 
  
  --path=LOCAL_LIB_PATH
      point libname to LOCAL_LIB_PATH. Doesn't verify the LOCAL_LIB_PATH is correct.

  --restore
      restore libname to one of previously changed values.

  With only libname as argument, tests for libname in package.json.

Note:
  * --path, --restore act as mutually exclusive flags
HELP
  exit 0
}

quote_escape() {
  echo "${1//\"/\\\"}"
}

find_node_pkg() {
  local wd="$1"

  if [[ $wd = "/" ]] || ! [[ -r "$wd" ]]
  then
    die "failed to locate package.json."
  fi

  if [[ -e "${wd}/package.json" ]]
  then
    echo "${wd}/package.json"
  else
    find_node_pkg "${wd%/*}"
  fi
}

probe() {
  local pkg="$1"
  local pkg_json="$2"

  if jq '.dependencies + .devDependencies + {} | keys | .[]' "$pkg_json" | grep -iw "$pkg" >/dev/null
  then
    local jqf
    jqf=$(jq 'if .dependencies'".\"$pkg\""' then "dependencies" else "devDependencies" end' "$pkg_json")
    echo "${jqf//\"}"
  else
    die "failed to find '$pkg' in ${pkg_json}."
  fi
}

if [[ $# -eq 1 ]] && [[ "$1" = "--help" ]]
then
  usage
fi

required npm jq

wd=${PWD:-$(pwd)}
pkg_json=$(find_node_pkg "$wd")
pkg_json_dir="${pkg_json%/*}"
data_dir="${pkg_json_dir}/.dnc"
changes_f="$data_dir/changes.json"

[[ -e "$data_dir" ]] || mkdir -m 700 "$data_dir"

if ! [[ -e "$changes_f" ]]
then
  echo "{}" > "$changes_f"
fi

if [[ $# -eq 1 ]]
then
  lib="$(quote_escape "$1")"
  lookup_path=$(probe "$lib" "$pkg_json")
  echo "found at $lookup_path"
elif [[ $# -eq 2 ]]; then

  [[ -w "$pkg_json" ]]

  if [[ "$1" = "--restore" ]]
  then
    lib="$(quote_escape "$2")"
    lookup_path=".$(probe "$lib" "$pkg_json").\"${lib}\""

    versions=()
     while read -r version
     do
       versions+=("$version")
     done < <(jq "${lookup_path}[]?" <"$changes_f")


     while true
     do
       for idx in "${!versions[@]}"
       do
         echo "[$idx] ${versions[$idx]}"
       done

       read -rp "selection: []> " selection
       case "$selection" in
         [0-9]|[1-9][0-9])
           if [[ "$selection" -lt "${#versions[@]}" ]]
           then
             json_tmp="$data_dir/json.tmp"
             jq "$lookup_path = ${versions[$selection]}" <"$pkg_json" >"$json_tmp"
             mv "$json_tmp" "$pkg_json"
             break
           fi
           ;;
         *)
           ;;
       esac
       echo
     done

  elif [[ "$1" = "--path="* ]]
  then
    relocate="$(quote_escape "${1#--path=}")"
    lib="$(quote_escape "$2")"
    lookup_path=".$(probe "$lib" "$pkg_json").\"${lib}\""
    old_version=$(jq "$lookup_path" <"$pkg_json")
    updated_version="\"file:$relocate\""

    if [[ "$old_version" != "$updated_version" ]]
    then
      # jq doesn't support in place editing.
      json_tmp="$data_dir/json.tmp"
      jq "$lookup_path = $updated_version" <"$pkg_json" >"$json_tmp"
      mv "$json_tmp" "$pkg_json"

      jq "$lookup_path = ([ ${lookup_path}[]?, $old_version ] | unique)" <"$changes_f" >"$json_tmp"
      mv "$json_tmp" "$changes_f"
    fi

  else
    usage
  fi

  (
    cd "$pkg_json_dir"
    npm install
  )

else
  usage
fi
