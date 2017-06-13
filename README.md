### graalenv

A simple version / environment manager for Graal JVMCI builds and the mx build
tool. Just put it somewhere and `source graalenv`. It tries not to pollute your
environment. Everything is implemented in functions that are hidden
away. (Except the commands and the autocompletion command). Bash completion is
automatically set up.

#### Commands

* **graalenv**: The version manager function. It takes the following arguments:
  * *available*: List available JVMCI versions. Basically just lists tags in the
    local repository.
  * *install*: Install one of the available JVMCI versions.
  * *list*: List locally installed versions.
  * *uninstall*: Remove one of the locally installed versions.
  * *mx*: Run an `mx` command.
  * *update_env*: If you're currently inside an mx project, update the
    `mx.project/env` file to set JAVA_HOME to the currently selected JVMCI
    version.
  * *use*: Select an installed JVMCI version. This sets JAVA_HOME. With the `-u`
    flag after the version, it also runs `update_env` directly.
* **mx**: Runs the mx command

#### Customization

Customization basically happens through overriding of environment variables
after sourcing the `graalenv` file.

Three constants might be interesting:
* **GRAALENV_ORACLE_JDK_PATHS** - An array of paths to search for an Oracle
  JDK. One of these is required, and this tool only searches in some standard
  locations.
* **GRAALENV_JVMCI_REPOSITORY** - Where to get the JVMCI sources. The clone is
  only done once, so you'll have to remove any old clone from the graalenv
  folder manually when changing this.
* **GRAALENV_MX_REPOSITORY** - Where to get the mx project sources. The clone is
  only done once, so you'll have to remove any old clone from the graalenv
  folder manually when changing this.
