#!/bin/bash

# Import Environment Variables
for f in ~/.env/*
do
    . $f
done

function print_deprecation_warning() {
       cat <<DEPRECATED
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  The use of deplist.txt is being deprecated and will soon
  go away. For the short term, we will continue to support
  installing the Node modules specified in the deplist.txt
  file. But please be aware that this will soon go away.

  It is highly recommended that you use the package.json
  file to specify dependencies on other Node modules.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
DEPRECATED

}

function is_node_module_installed() {
    module_name=${1:-""}
    if [ -n "$module_name" ]; then
        pushd "$OPENSHIFT_GEAR_DIR" > /dev/null
        if [ -d $m ] ; then
            popd
            return 0
        fi
        popd
    fi

    return 1
}

if [ -f "${OPENSHIFT_REPO_DIR}/.openshift/markers/force_clean_build" ]; then
    echo ".openshift/markers/force_clean_build found!  Recreating npm modules" 1>&2
    rm -rf "${OPENSHIFT_GEAR_DIR}"/node_modules/*
fi

if [ -f "${OPENSHIFT_REPO_DIR}"/deplist.txt ]; then
    mods=$(perl -ne 'print if /^\s*[^#\s]/' "${OPENSHIFT_REPO_DIR}"/deplist.txt)
    [ -n "$mods" ]  &&  print_deprecation_warning
    for m in $mods; do
        echo "Checking npm module: $m"
        echo
        if is_node_module_installed "$m"; then
            (cd "${OPENSHIFT_GEAR_DIR}"; npm update "$m")
        else
            (cd "${OPENSHIFT_GEAR_DIR}"; npm install "$m")
        fi
    done
fi

if [ -f "${OPENSHIFT_REPO_DIR}"/package.json ]; then
    (cd "${OPENSHIFT_REPO_DIR}"; npm install -d)
fi

# Run user build
user_build.sh
