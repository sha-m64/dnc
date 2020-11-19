## DNC
=====
Manage dependencies

## LICENSE
=====
Refer LICENSE.md

## USAGE
====
Usage: ./dnc.sh [--path=path/to/lib | --restore] libname

  --path=LOCAL_LIB_PATH
      point libname to LOCAL_LIB_PATH. Doesn't verify the LOCAL_LIB_PATH is correct.

  --restore
      restore libname to one of previously changed values.

  With only libname as argument, tests for libname in package.json.

Note:
  * --path, --restore act as mutually exclusive flags
