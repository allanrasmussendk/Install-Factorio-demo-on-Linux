#!/bin/bash
#
# This script will install Factorio (Demo version)
#
# The script will download the latest Factorio demo version and extract it into the current directory.
# It will create a desktop icon for starting Factorio.
# A launch script and an uninstall script are also created in the current directory.
#
# This script can be executed without the use of sudo, but it will work a little better if sudo is used.
# (Except for "Allow launching", which might not work with sudo)
# If sudo is used Factorio will be installed into the proper installation directory and configured to run from there.
#
# Note: If the game is moved after installation, all installed files will break.
#
# WARNING / DISCLAIMER: Users be warned: The Factorio game is known as "Cractorio", because it is very addictive!! Run this script / install with caution.
# ---- PLAY RESPONSIBLY!! ----
#
# This script has been tested on Ubuntu 20.04.6 LTS, 24.04.1 LTS and 25.04 (Live USB).
#
# Version: 1.0.2
#

# Settings
# TRUE or FALSE. Default value is FALSE.
EXPERIMENTAL=FALSE
VERBOSE=FALSE

# Constants
DOWNLOAD_PAGE_URL=https://www.factorio.com/download
EXPERIMENTAL_DOWNLOAD_PAGE_URL=https://www.factorio.com/download/experimental
HTML_FILE_NAME=Download.html
CHECKSUM_PAGE_URL=https://www.factorio.com/download/sha256sums/
CHECKSUM_PAGE_FILE_NAME="sha512sums.txt"
EXTRACTED_GAME_DIRECTORY_NAME=factorio
FACTORIO_DESKTOP_FILE_NAME=factorio.desktop
FACTORIO_LAUNCHER_FILE_NAME=factorio.sh
FACTORIO_UNINSTALLER_FILE_NAME="uninstall factorio.sh"
COMPANY_INSTALL_PATH="/opt/Wube Software/"
SUDO_INSTALL_PATH="${COMPANY_INSTALL_PATH}Factorio/"
GLOBAL_TERMINAL_LINK_NAME="/usr/bin/factorio"
WEIRD_LINK_THAT_MAKES_STUFF_WORK="/usr/share/factorio"

GLOBAL_DESKTOP_DIRECTORY=/usr/local/share/applications/

COLOR_RED='\033[0;31m'
NO_COLOR='\033[0m'



echo "Checking OS..."
uname | grep -q Linux
if [[ $? != 0 ]] ; then
    echo "Incorrect operating system"
    uname
    echo "Installation of Factorio was not possible"
    sleep 5
    read -s -N 1 -p "Press any key to terminate"
    echo
    exit 1
fi



echo "Initializing..."

set -eEuo pipefail

exit_with_pause() {
    PARENT_COMMAND=$(cat /proc/$PPID/comm)
    if [[ "${PARENT_COMMAND}" != "bash" && "${PARENT_COMMAND}" != "sudo" && "${PARENT_COMMAND}" != "systemd" ]] ; then
        read -s -N 1 -p "Press any key to terminate"
        echo
    fi
    trap - EXIT
    exit $1
}

trap 'exit_with_pause ${?}' EXIT

CURRENT_PATH="${PWD}/"
if [[ "${VERBOSE}" == "TRUE" ]] ; then
    echo "CURRENT_PATH: ${CURRENT_PATH}"
fi

# "+x" is from https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
if [[ -z "${SUDO_USER+x}" ]] ; then 
    EXECUTED_BY_SUDO=FALSE
    CURRENT_USER=$(whoami)
    INSTALL_INTO_PATH="${CURRENT_PATH}"
else
    EXECUTED_BY_SUDO=TRUE
    CURRENT_USER="${SUDO_USER}"
    INSTALL_INTO_PATH="${SUDO_INSTALL_PATH}"
fi

if [[ "${VERBOSE}" == "TRUE" ]] ; then
    echo "EXECUTED_BY_SUDO: ${EXECUTED_BY_SUDO}"
    echo "CURRENT_USER: ${CURRENT_USER}"
    echo "INSTALL_INTO_PATH: ${INSTALL_INTO_PATH}"
fi

DESKTOP_PATH=$(
    sudo -u "${CURRENT_USER}" -i bash -l <<'EOF'
        user_dirs_file=${XDG_CONFIG_HOME:-${HOME}/.config}/user-dirs.dirs
        [[ -s $user_dirs_file ]] && . "$user_dirs_file"
        printf '%s\n' "${XDG_DESKTOP_DIR:-${HOME}/Desktop}"
EOF
)

if [[ "${VERBOSE}" == "TRUE" ]] ; then
    echo "DESKTOP_PATH: ${DESKTOP_PATH}"
fi

if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    SETTINGS_PATH="$(realpath "${DESKTOP_PATH}/../.factorio/")/"
    if [[ "${VERBOSE}" == "TRUE" ]] ; then
        echo "SETTINGS_PATH: ${SETTINGS_PATH}"
    fi
fi

if [[ "${EXPERIMENTAL}" == "TRUE" ]] ; then
    DOWNLOAD_PAGE_URL=${EXPERIMENTAL_DOWNLOAD_PAGE_URL}
    echo "Downloading experimental version from: ${DOWNLOAD_PAGE_URL}" 
fi



# Downloading HTML page
if [[ ! -f "${HTML_FILE_NAME}" ]] ; then
    echo "Downloading HTML page..."
    set +e
    wget -q -O "${HTML_FILE_NAME}" "${DOWNLOAD_PAGE_URL}"
    RETURN=$?
    set -e
    if [[ ${RETURN} != 0 ]] ; then
        echo "Downloading HTML page failed. Check your Internet connection. Return: ${RETURN}."
        if [[ -f "${HTML_FILE_NAME}" ]] ; then
    	    rm "${HTML_FILE_NAME}"
    	fi
        exit_with_pause 2
    fi
fi

if [[ ! -f "${HTML_FILE_NAME}" ]] ; then
    echo "ERROR: Downloaded HTML page file is missing!"
    exit_with_pause 3
fi

DOWNLOADED_HTML=$(cat "${HTML_FILE_NAME}")



echo "Calculating download URL (and version)...."
if [[ "${DOWNLOADED_HTML}" =~ \<a\ href=\"(/get-download/([^/]+)/demo/linux64)\" ]] ; then
    DOWNLOAD_URL=${BASH_REMATCH[1]}
    VERSION=${BASH_REMATCH[2]}
    if [[ "${VERBOSE}" == "TRUE" ]] ; then
        echo "DOWNLOAD_URL: ${DOWNLOAD_URL}"
        echo "VERSION: ${VERSION}"
    fi
    
    if [[ "${DOWNLOAD_URL}" =~ ^\.* ]] ; then
         if [[ "${DOWNLOAD_PAGE_URL}" =~ (http(s?)://[^/]+) ]] ; then
             BASE_URL=${BASH_REMATCH[1]}
             if [[ "${VERBOSE}" == "TRUE" ]] ; then
                 echo "BASE_URL: ${BASE_URL}"
             fi
             DOWNLOAD_URL=${BASE_URL}${DOWNLOAD_URL}
         else
             echo "Base URL not found ${DOWNLOAD_PAGE_URL}"
             exit_with_pause 4
         fi
    else
        DOWNLOAD_URL=${DOWNLOAD_PAGE_URL}${DOWNLOAD_URL}
    fi
    
    if [[ "${VERBOSE}" == "TRUE" ]] ; then
        echo "DOWNLOAD_URL: ${DOWNLOAD_URL}"
    fi
else
    echo "ERROR: Download URL not found!"
    exit_with_pause 5
fi



# Download installation file
# Note: This name must match the name in the checksum page (CHECKSUM_PAGE_URL)
DOWNLOADED_TAR_XZ_FILE_NAME="factorio-demo_linux_${VERSION}.tar.xz"
if [[ ! -f "${DOWNLOADED_TAR_XZ_FILE_NAME}" ]] ; then
    echo "Downloading... (Note: This may take several minutes depending on your internet connection)"
    set +e
    wget -q --show-progress -O "${DOWNLOADED_TAR_XZ_FILE_NAME}" "${DOWNLOAD_URL}"
    RETURN=$?
    set -e
    if [[ ${RETURN} != 0 ]] ; then
        echo "Downloading tar xz file failed. Return: ${RETURN}."
        exit_with_pause 6
    fi
fi

if [[ ! -f "${DOWNLOADED_TAR_XZ_FILE_NAME}" ]] ; then
    echo "ERROR: Downloaded tar xz file is missing!"
    exit_with_pause 7
fi



# Checking installation file
if [[ ! -f "${CHECKSUM_PAGE_FILE_NAME}" ]] ; then
    echo "Downloading checksum page..."
    set +e
    wget -q -O "${CHECKSUM_PAGE_FILE_NAME}" "${CHECKSUM_PAGE_URL}"
    RETURN=$?
    set -e
    if [[ ${RETURN} != 0 ]] ; then
        echo "Downloading checksum page failed. Check your Internet connection. Return: ${RETURN}."
        if [[ -f "${CHECKSUM_PAGE_FILE_NAME}" ]] ; then
    	    rm "${CHECKSUM_PAGE_FILE_NAME}"
    	fi
        exit_with_pause 8
    fi
fi

if [[ ! -f "${CHECKSUM_PAGE_FILE_NAME}" ]] ; then
    echo "ERROR: Downloaded checksum page file is missing!"
    exit_with_pause 9
fi


echo "Calculating expected checksum of downloaded installation file..."
# A simpler solution might be: sha256sum -c --ignore-missing "${CHECKSUM_PAGE_FILE_NAME}"
CHECKSUM_EXPECTED=$(grep "${DOWNLOADED_TAR_XZ_FILE_NAME}" "${CHECKSUM_PAGE_FILE_NAME}")
if [[ "${VERBOSE}" == "TRUE" ]] ; then
    echo "CHECKSUM_EXPECTED: ${CHECKSUM_EXPECTED}"
fi


echo "Calculating actual checksum of downloaded installation file (Note: This may take a while depending on your CPU speed)..."
set +e
CHECKSUM_ACTUAL=$(sha256sum "${DOWNLOADED_TAR_XZ_FILE_NAME}")
RETURN=$?
set -e
if [[ ${RETURN} != 0 ]] ; then
    echo "sha256sum failed. Return: ${RETURN}."
    exit_with_pause 10
fi

if [[ "${VERBOSE}" == "TRUE" ]] ; then
    echo "CHECKSUM_ACTUAL  : ${CHECKSUM_ACTUAL}"
fi


echo "Checking checksum of downloaded installation file..."
if [[ ${CHECKSUM_ACTUAL} != ${CHECKSUM_EXPECTED} ]] ; then
    echo -e "${COLOR_RED}ERROR: Checksums don't match${NO_COLOR}" 1>&2
    echo "CHECKSUM_EXPECTED: ${CHECKSUM_EXPECTED}" 1>&2
    echo "CHECKSUM_ACTUAL  : ${CHECKSUM_ACTUAL}" 1>&2
    exit_with_pause 11
fi


if [[ ! -d "${INSTALL_INTO_PATH}" ]] ; then
    mkdir -p "${INSTALL_INTO_PATH}"
fi


# Extracting the downloaded installation file
if [[ ! -d "${INSTALL_INTO_PATH}${EXTRACTED_GAME_DIRECTORY_NAME}" ]] ; then
    echo "The downloaded file will now be extracted. (Note: This may take several minutes depending on your hard drive / SSD speed)"
    echo -n "Extracting"
    set +e
    tar xf "${DOWNLOADED_TAR_XZ_FILE_NAME}" -C "${INSTALL_INTO_PATH}" --checkpoint=.1000
    RETURN=$?
    set -e
    if [[ ${RETURN} != 0 ]] ; then
        echo "Extracting tar xz file failed. Return: ${RETURN}."
        exit_with_pause 12
    fi
    echo "done"
    if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
        chown -R ${CURRENT_USER}:${CURRENT_USER} "${INSTALL_INTO_PATH}${EXTRACTED_GAME_DIRECTORY_NAME}"
    fi
fi

if [[ ! -d "${INSTALL_INTO_PATH}${EXTRACTED_GAME_DIRECTORY_NAME}" ]] ; then
    echo "ERROR: Extracted game directory is missing!"
    exit_with_pause 13
fi



echo "Creating desktop file..."
echo "[Desktop Entry]" > "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Version=1.0" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Type=Application" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Name=Factorio\n(Demo ver ${VERSION})" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Exec=\"${INSTALL_INTO_PATH}${FACTORIO_LAUNCHER_FILE_NAME}\"" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Terminal=false" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Icon=${INSTALL_INTO_PATH}factorio/data/core/graphics/factorio.png" >> "${FACTORIO_DESKTOP_FILE_NAME}"

# Add uninstall action to desktop file
echo "StartupNotify=true" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Actions=uninstall" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "[Desktop Action uninstall]" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Name=Uninstall Factorio" >> "${FACTORIO_DESKTOP_FILE_NAME}"
echo "Exec=gnome-terminal -x \"${INSTALL_INTO_PATH}${FACTORIO_UNINSTALLER_FILE_NAME}\"" >> "${FACTORIO_DESKTOP_FILE_NAME}"

set +e
desktop-file-validate "${FACTORIO_DESKTOP_FILE_NAME}"
RETURN=$?
set -e
if [[ ${RETURN} != 0 ]] ; then
    echo "Validating created desktop file failed. Return: ${RETURN}."
    exit_with_pause 14
fi

# Copy desktop file and make it executable
cp "${FACTORIO_DESKTOP_FILE_NAME}" "${DESKTOP_PATH}/"
chmod 744 "${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}"

# Set "Allow launching" to true for the desktop file.
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    if [[ -d "/home/${CURRENT_USER}/.dbus" ]] ; then
        # This command makes the "Unable to create /home/allan/.dbus/session-bus" bug go away.
        chown ${CURRENT_USER}:${CURRENT_USER} -R /home/${CURRENT_USER}/.dbus
    fi
    
    # The dbus-x11 package contains the dbus-launch command.
    set +e
    dpkg -s dbus-x11 >/dev/null 2>/dev/null
    RETURN=$?
    set -e
    if [[ ${RETURN} != 0 ]] ; then
       echo "dbus-x11 is not installed. Installing..."
       set +e
       apt install dbus-x11 >/dev/null 2>/dev/null
       RETURN=$?
       set -e
       if [[ ${RETURN} != 0 ]] ; then
          echo "apt install dbus-x11 failed. Return: ${RETURN}."
          exit_with_pause 15
       fi
    fi
    
    # This tends to work under sudo
    # See hack at the end of this script
    sudo -u "${CURRENT_USER}" -g "${CURRENT_USER}" dbus-launch gio set "${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}" metadata::trusted true
else
#   This doesn't work under sudo => Error message: "gio: Setting attribute metadata::trusted not supported"
    gio set "${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}" metadata::trusted true
fi
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    chown ${CURRENT_USER}:${CURRENT_USER} "${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}"
fi

if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    echo "Making the desktop file global..."
    if [[ ! -e "${GLOBAL_DESKTOP_DIRECTORY}" ]] ; then
         mkdir "${GLOBAL_DESKTOP_DIRECTORY}"
    fi
    cp "${FACTORIO_DESKTOP_FILE_NAME}" "${GLOBAL_DESKTOP_DIRECTORY}"
    chmod 644 "${GLOBAL_DESKTOP_DIRECTORY}${FACTORIO_DESKTOP_FILE_NAME}"
    
    if [[ ! -L "${GLOBAL_TERMINAL_LINK_NAME}" ]] ; then
        echo "Creating global terminal link..."
        ln -s "${INSTALL_INTO_PATH}${FACTORIO_LAUNCHER_FILE_NAME}" "${GLOBAL_TERMINAL_LINK_NAME}"
    fi
fi

# Creating launcher file
write_exit_with_pause_function() {
    OUTPUT_FILE_NAME=$1
    echo "exit_with_pause() {" >> "${OUTPUT_FILE_NAME}"
    echo "    PARENT_COMMAND=\$(cat /proc/\$PPID/comm)" >> "${OUTPUT_FILE_NAME}"
    echo "    if [[ ! \"\${PARENT_COMMAND}\" == \"bash\" && ! \"\${PARENT_COMMAND}\" == \"sudo\" && ! \"\${PARENT_COMMAND}\" == \"systemd\" ]] ; then" >> "${OUTPUT_FILE_NAME}"
    echo "        read -s -N 1 -p \"Press any key stop\"" >> "${OUTPUT_FILE_NAME}"
    echo "        echo" >> "${OUTPUT_FILE_NAME}"
    echo "    fi" >> "${OUTPUT_FILE_NAME}"
    echo "    exit \$1" >> "${OUTPUT_FILE_NAME}"
    echo "}" >> "${OUTPUT_FILE_NAME}"
    echo "" >> "${OUTPUT_FILE_NAME}"
}

echo "Creating launcher file..."
echo "#!/bin/bash" > "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "# This script will launch Factorio (Demo version ${VERSION})" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "" >> "${FACTORIO_LAUNCHER_FILE_NAME}"

write_exit_with_pause_function "${FACTORIO_LAUNCHER_FILE_NAME}"

if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    # See https://forums.factorio.com/viewtopic.php?t=56454
    # Adding the --executable-path makes stuff work.
    # Must be set to a value to work, but the actually value doesn't matter. Weird!
    echo "\"${INSTALL_INTO_PATH}factorio/bin/x64/factorio\" --executable-path ${WEIRD_LINK_THAT_MAKES_STUFF_WORK}/data" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
else
    echo "\"${INSTALL_INTO_PATH}factorio/bin/x64/factorio\"" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
fi
echo "RETURN=\$?" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "if [[ \${RETURN} != 0 ]] ; then" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "    echo \"Launching Factorio (Demo version ${VERSION}) failed with exit code: \${RETURN}.\"" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "    if [[ -f /usr/bin/notify-send ]] ; then"  >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "        /usr/bin/notify-send -i \"${INSTALL_INTO_PATH}factorio/data/core/graphics/factorio.png\" \"Factorio\" \"Launch of Factorio failed. Return: \${RETURN}.\"" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "    fi"  >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "    exit_with_pause 1" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "fi" >> "${FACTORIO_LAUNCHER_FILE_NAME}"
echo "" >> "${FACTORIO_LAUNCHER_FILE_NAME}"

echo "exit_with_pause 0" >> "${FACTORIO_LAUNCHER_FILE_NAME}"

chmod 744 "${FACTORIO_LAUNCHER_FILE_NAME}"
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    chown ${CURRENT_USER}:${CURRENT_USER} "${FACTORIO_LAUNCHER_FILE_NAME}"

    # Move launcher to installation directory
    mv "${FACTORIO_LAUNCHER_FILE_NAME}" "${INSTALL_INTO_PATH}"
    chmod 744 "${INSTALL_INTO_PATH}${FACTORIO_LAUNCHER_FILE_NAME}"
    chown ${CURRENT_USER}:${CURRENT_USER} "${INSTALL_INTO_PATH}${FACTORIO_LAUNCHER_FILE_NAME}"
fi



echo "Creating uninstaller script file..."
echo "#!/bin/bash" > "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

echo "set -eEuo pipefail" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

write_exit_with_pause_function "${FACTORIO_UNINSTALLER_FILE_NAME}"

echo "if [[ -z \"\${SUDO_USER+x}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
#   NOTE: The ' in next line is because !" is used in commands to refer to the command line history. See https://serverfault.com/questions/208265/what-is-bash-event-not-found
    echo '    echo "ERROR: This script must be executed using sudo!"' >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    echo \"Rerunning using sudo...\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    sudo \"${INSTALL_INTO_PATH}/${FACTORIO_UNINSTALLER_FILE_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    exit_with_pause 1" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
else
    echo "    CURRENT_USER=\$(whoami)" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
fi
echo "else" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "    CURRENT_USER=\${SUDO_USER}" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

echo "read -N 1 -p 'Uninstall Factorio and DELETE saved games (y=yes n=no)? ' answer" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "echo ''" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "if [[ \"\$answer\" != 'y' ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "    echo 'Canceled'" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "    exit_with_pause 2" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

echo "echo 'Uninstalling...'" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
# Remove "installed" game (uninstall script)
echo "rm -r --interactive=never \"${INSTALL_INTO_PATH}${EXTRACTED_GAME_DIRECTORY_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "DESKTOP_PATH=\$(" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "    sudo -u \"\${CURRENT_USER}\" -i bash -l <<'EOF'" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "        user_dirs_file=\${XDG_CONFIG_HOME:-\${HOME}/.config}/user-dirs.dirs" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "        [[ -s \$user_dirs_file ]] && . \"\$user_dirs_file\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "        printf '%s\n' \"\${XDG_DESKTOP_DIR:-\${HOME}/Desktop}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "EOF" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo ")" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

# Remove desktop file (uninstall script)
echo "if [[ -f \"${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "    rm \"${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

# Remove global links (uninstall script)
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    echo "if [[ -f \"${GLOBAL_DESKTOP_DIRECTORY}${FACTORIO_DESKTOP_FILE_NAME}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    rm \"${GLOBAL_DESKTOP_DIRECTORY}${FACTORIO_DESKTOP_FILE_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "if [[ -L \"${GLOBAL_TERMINAL_LINK_NAME}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    rm \"${GLOBAL_TERMINAL_LINK_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
fi

# Remove weird link that makes stuff work (uninstall script)
# See https://forums.factorio.com/viewtopic.php?t=56454
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    echo "if [[ -L \"${WEIRD_LINK_THAT_MAKES_STUFF_WORK}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    rm \"${WEIRD_LINK_THAT_MAKES_STUFF_WORK}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
fi

# Remove settings and saved games (uninstall script)
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    echo "if [[ -e \"${SETTINGS_PATH}\" ]] ; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    rm -r --interactive=never \"${SETTINGS_PATH}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
fi

# Remove launcher file (uninstall script)
echo "rm \"${INSTALL_INTO_PATH}${FACTORIO_LAUNCHER_FILE_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "echo \"The uninstallation of Factorio was successfully completed\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
# Add removal of the uninstall script file to the uninstaller script
echo "rm \"${INSTALL_INTO_PATH}${FACTORIO_UNINSTALLER_FILE_NAME}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"

if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    # Add removal of now empty installation directory to the uninstaller script
    echo "rmdir \"${INSTALL_INTO_PATH}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    # Remove parent parent directory if empty
    # Code copied from https://superuser.com/questions/352289/bash-scripting-test-for-empty-directory
    # and modified
    echo "if [[ ! -n \"\$(ls -A \"${COMPANY_INSTALL_PATH}\")\" ]]; then" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "    rmdir \"${COMPANY_INSTALL_PATH}\"" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "fi" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
    echo "" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
fi

echo "exit_with_pause 0" >> "${FACTORIO_UNINSTALLER_FILE_NAME}"
# End of adding lines the uninstaller script

# Make the newly create uninstall script file executable by all users
chmod 744 "${FACTORIO_UNINSTALLER_FILE_NAME}"
if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    chown ${CURRENT_USER}:${CURRENT_USER} "${FACTORIO_UNINSTALLER_FILE_NAME}"

    # Move uninstall script to installation directory
    mv "${FACTORIO_UNINSTALLER_FILE_NAME}" "${INSTALL_INTO_PATH}"
    chmod 744 "${INSTALL_INTO_PATH}${FACTORIO_UNINSTALLER_FILE_NAME}"
    chown ${CURRENT_USER}:${CURRENT_USER} "${INSTALL_INTO_PATH}${FACTORIO_UNINSTALLER_FILE_NAME}"
fi

if [[ "${EXECUTED_BY_SUDO}" == "TRUE" ]] ; then
    echo "Creating link..."
    # Create a weird link that makes stuff work
    # See https://forums.factorio.com/viewtopic.php?t=56454
    if [[ ! -L "${WEIRD_LINK_THAT_MAKES_STUFF_WORK}" ]] ; then
       ln -s "${INSTALL_INTO_PATH}${EXTRACTED_GAME_DIRECTORY_NAME}/data/" "${WEIRD_LINK_THAT_MAKES_STUFF_WORK}"
    fi
fi

echo "Cleaning up..."
rm "${HTML_FILE_NAME}"
rm "${DOWNLOADED_TAR_XZ_FILE_NAME}"
rm "${CHECKSUM_PAGE_FILE_NAME}"
rm "${FACTORIO_DESKTOP_FILE_NAME}"


echo "Almost done..."

# Hack that tries to fix that the desktop file sometimes is not updated to be "Executable" and "Allow Launching".
# This is probably a race condition bug.
# "Execute as program" seems to get broken by the sudo ... dbus-launch gio set ... command above. Try to fix that as well.
sleep 3
touch "${DESKTOP_PATH}/${FACTORIO_DESKTOP_FILE_NAME}"

echo "The installation of Factorio (Demo version ${VERSION}) is complete."
