# Some often used variables, probably fine to leave hidden

__graal_env_MX_SRC_DIR="$GRAALENV_DIR/mx"
__graal_env_MX_SCRIPT="$__graal_env_MX_SRC_DIR/mx"
__graal_env_GRAAL_SRC_DIR=$GRAALENV_DIR/graal-jvmci
__graal_env_GRAAL_INSTALL_PREFIX=$GRAALENV_DIR/products
__graal_env_NB_DOWNLOAD_DIR="$GRAALENV_DIR/netbeans_download"
__graal_env_NB_INSTALL_DIR="$GRAALENV_DIR/netbeans"

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

function __graal_env_cmd_selfupdate() {
    __graal_env_pushd "$GRAALENV_DIR"
    git pull
    __graal_env_popd
    source "$GRAALENV_DIR"/graalenv
}

function __graal_env_cmd_update_jvmci() {
    __graal_env_checkout_graal
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
    local javacmds=(jar java javac javadoc javah javap jvisualvm)
    local target="$1"
    if [ "$target" == "latest" ]; then
	target=`ls -t "$__graal_env_GRAAL_INSTALL_PREFIX/" | head -1`
    fi
    if [ "$target" == "system" ]; then
	for cmd in ${javacmds[@]}; do
	    unalias $cmd 2>/dev/null
	done
	unset GRAALENV_HOME
	unset JAVA_HOME
    else
	export GRAALENV_HOME="$__graal_env_GRAAL_INSTALL_PREFIX/$target"
	export JAVA_HOME="$GRAALENV_HOME"
	for cmd in ${javacmds[@]}; do
	    alias $cmd="$GRAALENV_HOME/bin/$cmd"
	done
    fi
    if [ "$2" == "-u" ]; then
	__graal_env_cmd_update_env
    fi
}

function __graal_env_cmd_update_env() {
    local suite=$(__graal_env_get_suite)
    local mxdir="mx.${suite}"
    local mxenv="${mxdir}/env"
    if [ -d "$mxdir" ]; then
	if [ -e "$mxenv" ]; then
	    if cat "$mxenv" | grep JAVA_HOME >/dev/null; then
		sed -i 's/^JAVA_HOME=.*//' "$mxenv"
	    fi
	fi
	if [ -n "$JAVA_HOME" ]; then
	    echo JAVA_HOME="$GRAALENV_HOME" >> "${mxenv}"
	fi
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

function __graal_env_get_suite() {
    for d in `find . -maxdepth 1 -type d -name "mx.*"`; do
        if [ d != "./mx.imports" ]; then
            # binary imports are not a suite
            echo ${d##*.}
            return
        fi
    done
}

function __graal_env_cmd_format() {
    local suite=$(__graal_env_get_suite)
    local ECLIPSE_EXE=""
    if ! grep ECLIPSE_EXE "mx.${suite}/env"; then
        if [ -z "$ECLIPSE_EXE" ]; then
            local currentdir=$(pwd)
            ECLIPSE_EXE=`find ${currentdir} -executable -type f -name "eclipse" | head -1`
            if [ -z "$ECLIPSE_EXE" ]; then
                currentdir=`dirname ${currentdir}`
                ECLIPSE_EXE=`find ${currentdir} -executable -type f -name "eclipse" | head -1`
                if [ -z "$ECLIPSE_EXE" ]; then
                    currentdir=`dirname ${currentdir}`
                    ECLIPSE_EXE=`find ${currentdir} -executable -type f -name "eclipse" | head -1`
                fi
                if [ -z "$ECLIPSE_EXE" ]; then
                    # give up
                    echo "Could not find eclipse binary here or at most two directories up"
                    return -1
                fi
            fi
        fi
        echo ECLIPSE_EXE="$ECLIPSE_EXE" >> "mx.${currentdir}/env"
    fi
    __graal_env_mx eclipseformat
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

__graal_env_cmd_update_mx() {
    if [ ! -d "$__graal_env_MX_SRC_DIR" ]; then
	git clone "$GRAALENV_MX_REPOSITORY" "$__graal_env_MX_SRC_DIR"
	return $?
    else
	__graal_env_pushd "$__graal_env_MX_SRC_DIR"
	git pull
	local exitcode=$?
	__graal_env_popd
	return $exitcode
    fi
}

__graal_env_clone_graal() {
    if [ ! -d "$__graal_env_GRAAL_SRC_DIR" ]; then
	git clone "$GRAALENV_JVMCI_REPOSITORY" "$__graal_env_GRAAL_SRC_DIR"
    fi
}

__graal_env_checkout_graal() {
    __graal_env_do_in_dir "$__graal_env_GRAAL_SRC_DIR" "__graal_env_inner_checkout_graal $1"
    return $?
}

__graal_env_inner_checkout_graal() {
    git pull
    git clean -fdx
    if [ -n "$1" ]; then
	git checkout $1
        git clean -fdx
	if [ $? -ne 0 ]; then
	    echo "Error getting graal revision $1"
	    return 1
	fi
    else
	git clean -fdx
	if [ $? -ne 0 ]; then
	    echo "Error getting updating graal"
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
    local default_dynamic_imps=$DEFAULT_DYNAMIC_IMPORTS
    unset DEFAULT_DYNAMIC_IMPORTS
    __graal_env_mx clean
    __graal_env_mx --vm=server build -DFULL_DEBUG_SYMBOLS=0
    local exitcode=$?
    DEFAULT_DYNAMIC_IMPORTS=$default_dynamic_imps
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
    git tag -l | grep jvmci | cut -d' ' -f 1
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
	    if [ "$1" == "--porcelain" ] || [ -z "$JAVA_HOME" ]; then
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
    if [ -z "$JAVA_HOME" ]; then
	echo "(*) system"
    else
	echo "system"
    fi
}

__graal_env_update_netbeans() {
    echo "Updating Netbeans..."
    mkdir -p "$__graal_env_NB_DOWNLOAD_DIR"
    mkdir -p "$__graal_env_NB_INSTALL_DIR"
    # download and extract
    local zipfile=`curl -L http://bits.netbeans.org/download/trunk/nightly/latest/zip | grep javase\.zip | cut -f 2 -d'"'`
    __graal_env_pushd "$__graal_env_NB_DOWNLOAD_DIR"
    wget -c "http://bits.netbeans.org/download/trunk/nightly/latest/zip/${zipfile}"
    unzip -uoq "$zipfile" -d "$__graal_env_NB_INSTALL_DIR"
    # remove any older zipfiles
    for i in *.zip; do
	if [ "$i" != "$zipfile" ]; then
	    rm "$i"
	fi
    done
    __graal_env_popd

    # if we have only a netbeans subfolder, remove that
    __graal_env_pushd "$__graal_env_NB_INSTALL_DIR"
    if [ "$(ls)" == "netbeans" ]; then
	mv netbeans/* .
	rmdir netbeans
    fi
    sed -i 's/netbeans_default_options="\(.*\)"/netbeans_default_options="\1 -J-Dswing.aatext=true -J-Dawt.useSystemAAFontSettings=on -J-DCachingArchiveProvider.disableCtSym=true"/' etc/netbeans.conf
    sed -i 's/-J-Dnetbeans.logger.console=true/-J-Dnetbeans.logger.console=false/' etc/netbeans.conf
    sed -i 's/-J-Dplugin.manager.check.updates=false/-J-Dplugin.manager.check.updates=true/' etc/netbeans.conf
    __graal_env_popd

    echo "Current netbeans space usage: "
    du -hc -d 1 $__graal_env_NB_INSTALL_DIR
}

__graal_env_netbeans() {
    if [ ! -e "${__graal_env_NB_INSTALL_DIR}/bin/netbeans" ]; then
	__graal_env_update_netbeans
    fi
    "${__graal_env_NB_INSTALL_DIR}/bin/netbeans" "$@"
}
