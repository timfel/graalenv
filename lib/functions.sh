# Some often used variables, probably fine to leave hidden

__graal_env_MX_SRC_DIR="$GRAALENV_DIR/mx"
__graal_env_MX_SCRIPT="$__graal_env_MX_SRC_DIR/mx"
__graal_env_GRAAL_SRC_DIR=$GRAALENV_DIR/graal-jvmci
__graal_env_GRAAL_INSTALL_PREFIX=$GRAALENV_DIR/products

# Commands, these are the highlevel commands available

function __graal_env_cmd_install() {
    if [ ! -e "$__graal_env_GRAAL_INSTALL_PREFIX/$1" ]; then
	mkdir -p "$__graal_env_GRAAL_INSTALL_PREFIX"
	__graal_env_clone_graal || return 1
	__graal_env_checkout_graal $1 || return 1
	__graal_env_build_graal || return 1
	new_product=$(__graal_env_built_home) || return 1
	mv "$new_product" "$__graal_env_GRAAL_INSTALL_PREFIX/$1" || return 1
    else
	echo "$1 is already installed"
    fi
    return 0
}

function __graal_env_cmd_uninstall() {
    rm -rf --one-filesystem "$__graal_env_GRAAL_INSTALL_PREFIX/$1"
}

function __graal_env_cmd_available() {
    __graal_env_clone_graal || return 1
    __graal_env_list_graal_tags
    return $?
}

function __graal_env_cmd_list() {
    __graal_env_list_installed
    return $?
}

function __graal_env_cmd_use() {
    export GRAALENV_HOME="$__graal_env_GRAAL_INSTALL_PREFIX/$1"
    export JAVA_HOME="$GRAALENV_HOME"
    if [ "$2" == "-u" ]; then
	__graal_env_cmd_update_env
    fi
}

function __graal_env_cmd_update_env() {
    local currentdir=`basename $(pwd)`
    local mxdir="mx.${currentdir}"
    local mxenv="${mxdir}/env"
    if [ -d "$mxdir" ]; then
	if [ -e "$mxenv" ]; then
	    if cat "$mxenv" | grep JAVA_HOME >/dev/null; then
		sed -i 's/^JAVA_HOME=.*//' "$mxenv"
	    fi
	fi
	echo JAVA_HOME="$GRAALENV_HOME" >> "mx.${currentdir}/env"
    fi
}

function __graal_env_cmd_help() {
    echo "Available commands:"
    for i in `typeset -F`; do
	if [[ "$i" == __graal_env_cmd_* ]]; then
	    echo ${i##__graal_env_cmd_}
	fi
    done
}

function __graal_env_cmd_mx() {
    __graal_env_mx "$@"
    return $?
}

# Implementation functions

__graal_env_determine_commands() {
    local commands=""
    source $GRAALENV_DIR/lib/functions.sh
    local i=0
    for func in `typeset -F`; do
	if [[ "$func" == __graal_env_cmd_* ]]; then
	    commands="$commands ${func##__graal_env_cmd_}"
	    ((i++))
	fi
    done
    echo "$commands"
}

__graal_env_unset_all() {
    for i in `typeset -F`; do
	if [[ "$i" == __graal_env_* ]]; then
	    unset -f $i
	fi
    done

    for i in `compgen -v`; do
	if [[ "$i" == __graal_env_* ]]; then
	    unset $i
	fi
    done
}

__graal_env_pushd() {
    command pushd "$@" > /dev/null
}

__graal_env_popd() {
    command popd "$@" > /dev/null
}

__graal_env_mx() {
    __graal_env_clone_mx
    $__graal_env_MX_SCRIPT "$@"
}

__graal_env_set_system_oracle() {
    if uname -a | grep x86_64 >/dev/null; then
	local ARCH_SUFFIX=amd64
    else
	local ARCH_SUFFIX=i386
    fi

    local found_java_home=""
    for java_home in $GRAALENV_ORACLE_JDK_PATHS; do
	if [ -d "$java_home" ]; then
	    found_java_home=$java_home
	    break
	fi
    done

    if [ -z "$found_java_home" ]; then
	echo "Don't know where the Oracle JDK is. Maybe set GRAALENV_ORACLE_JDK_PATHS to help?"
	return 1
    fi
    echo "$found_java_home"
}

__graal_env_clone_mx() {
    if [ ! -d "$__graal_env_MX_SRC_DIR" ]; then
	git clone "$GRAALENV_MX_REPOSITORY" "$__graal_env_MX_SRC_DIR"
    fi
}

__graal_env_clone_graal() {
    if [ ! -d "$__graal_env_GRAAL_SRC_DIR" ]; then
	hg clone "$GRAALENV_JVMCI_REPOSITORY" "$__graal_env_GRAAL_SRC_DIR"
    fi
}

__graal_env_checkout_graal() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_SRC_DIR" "__graal_env_inner_checkout_graal $1"
    return $?
}

__graal_env_inner_checkout_graal() {
    hg pull
    hg status -un -i | xargs rm 2>/dev/null
    if [ -n "$1" ]; then
	hg update -r $1 -C
	if [ $? -ne 0 ]; then
	    echo "Error getting graal revision $1"
	    return 1
	fi
    fi
    return 0
}

__graal_env_build_graal() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_SRC_DIR" __graal_env_inner_build_graal
    return $?
}

__graal_env_inner_build_graal() {
    if env | grep JAVA_HOME > /dev/null; then
	local old_java_home=$JAVA_HOME
    fi
    __graal_env_set_system_oracle
    if [ $? -ne 0 ]; then
	return 1
    fi
    export JAVA_HOME=$(__graal_env_set_system_oracle)
    echo "JAVA_HOME=$JAVA_HOME" > mx.jvmci/env
    __graal_env_mx clean
    __graal_env_mx build
    local exitcode=$?
    if [ -n "$old_java_home" ]; then
	export JAVA_HOME="$old_java_home"
    else
	unset JAVA_HOME
    fi
    return $exitcode
}

__graal_env_built_home() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_SRC_DIR" __graal_env_inner_built_home
    return $?
}

__graal_env_inner_built_home() {
    echo `__graal_env_mx jdkhome`
}

__graal_env_do_in_dir() {
    mkdir -p "$1"
    __graal_env_pushd "$1"
    $2
    local exitcode=$?
    __graal_env_popd
    return $exitcode
}

__graal_env_list_graal_tags() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_SRC_DIR" __graal_env_inner_list_graal_tags
    return $?
}

__graal_env_inner_list_graal_tags() {
    hg tags | grep jvmci | cut -d' ' -f 1
}

__graal_env_list_installed() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_INSTALL_PREFIX" __graal_env_inner_list_installed "$@"
    return $?
}

__graal_env_inner_list_installed() {
    for i in *; do
	if [ "$i" == "*" ]; then
	    echo "No graal env installed"
	else
	    if [ "$1" == "--porcelain" ] || [ -n "$JAVA_HOME" ]; then
		echo "$i"
	    else
		if [ "$(basename $JAVA_HOME)" == "$i" ]; then
		    echo "(*) $i"
		else
		    echo "$i"
		fi
	    fi
	fi
    done
}
