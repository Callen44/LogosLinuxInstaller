#!/usr/bin/env bash
TITLE="${FLPRODUCT}.sh"
VERSION="${LOGOS_SCRIPT_VERSION}"
AUTHOR="${LOGOS_SCRIPT_AUTHOR}"
# generated by "${LOGOS_SCRIPT_VERSION}" script from https://github.com/ferion11/LogosLinuxInstaller

# BEGIN ENVIRONMENT
HERE="\$(dirname "\$(readlink -f "\${0}")")"

# Save IFS
IFS_TMP=\${IFS}
IFS=$'\n'

# Set config path if the user does not supply one at CLI.
if [ -z "\${CONFIG_PATH}" ]; then
	CONFIG_PATH="\${HOME}/.config/Logos_on_Linux/Logos_on_Linux.conf"; export CONFIG_PATH;
fi

# Source the config path, else use the values saved from when the script was run
# in case the config file's generation failed. This should maintain functionality
# from before the addition of the config file and after.
if [ -f \${CONFIG_PATH} ]; then
	set -a;
	source \${CONFIG_PATH};
	set +a;
	if [ -z "\${FLPRODUCT}" ] || [ -z "\${WINEPREFIX}" ] || [ -z "\${WINE_EXE}" ] || [ -z "\${WINESERVER_EXE}" ] || [ -z "\${LOGOS_EXE}" ] || [ -z "\${LOGOS_DIR}" ]; then
		echo "controlPanel.sh needs these variables set in the config file:"
		echo "- FLPRODUCT"
		echo "- WINEPREFIX"
		echo "- WINE_EXE"
		echo "- WINESERVER_EXE"
		echo "- LOGOS_EXE"
		echo "- LOGOS_DIR"
		echo "Config file incomplete. Exiting." >&2 && exit 1;
	fi
else
	[ -x "\${HERE}/data/bin/wine64" ] && export PATH="\${HERE}/data/bin:\${PATH}"
	export WINEPREFIX="\${HERE}/data/wine64_bottle"; export WINEPREFIX;
	export WINE_EXE="${WINE_EXE}"; export WINE_EXE;
	export WINESERVER_EXE="${WINESERVER_EXE}"; export WINESERVER_EXE;
	LOGOS_EXE=\$(find "\${WINEPREFIX}" -name ${FLPRODUCT}.exe | grep "${FLPRODUCT}\/${FLPRODUCT}.exe"); export LOGOS_EXE;
	LOGOS_DIR="\$(dirname "\${LOGOS_EXE}")"; export LOGOS_DIR;
	LOGS="DISABLED"; export LOGS;
fi

LOGOS_USER="\$(find "\${HERE}"/data/wine64_bottle/drive_c/users/*/AppData/Local/Logos -name Data | sed -r "s@\${HERE}/data/wine64_bottle/drive_c/users/(.*)/AppData/Local/Logos/Data@\1@")"; export LOGOS_USER;

if [ "\$(find "\${HERE}/data/wine64_bottle/drive_c/users/\${LOGOS_USER}/AppData/Local/Logos/Data/"* -maxdepth 0 -type d | awk -F'/' '{print \$NF}')" ]; then
	LOGOS_UID="\$(find "\${HERE}/data/wine64_bottle/drive_c/users/\${LOGOS_USER}/AppData/Local/Logos/Data/"* -maxdepth 0 -type d | awk -F'/' '{print \$NF}')"; export LOGOS_UID;
elif [ -z "LOGOS_UID" ]; then
	LOGOS_UID="NoUser"; export LOGOS_UID;
else
	:
fi

[ -z "\${LOGOS_ICON_URL}" ] && export LOGOS_ICON_URL="${LOGOS_ICON_URL}"
LOGOS_ICON_FILENAME="\$(basename "\${LOGOS_ICON_URL}")"; export LOGOS_ICON_FILENAME;
if [ -z "\${WINEDEBUG}" ]; then WINEDEBUG="fixme-all,err-all"; export WINEDEBUG; fi # Make wine output less verbose
# END ENVIRONMENT
# BEGIN FUNCTION DECLARATIONS
usage() {
	cat << UEOF
\$TITLE, by \$AUTHOR, \$VERSION.

Usage: ./\$TITLE
Interact with ${FLPRODUCT} Bible Software in Wine on Linux.

Options:
    -h   --help                Prints this help message and exit.
    -v   --version             Prints version information and exit.
    -D   --debug               Makes Wine print out additional info.
    -f   --force-root          Sets LOGOS_FORCE_ROOT to true, which
                               permits the root user to run the script.
    -R   --check-resources     Check ${FLPRODUCT}'s resource usage.
    -e   --edit-config         Edit the Logos on Linux config file.
    -i   --indexing            Run the ${FLPRODUCT} indexer in the
                               background.
    -b   --backup              Saves ${FLPRODUCT} data to the config's
                               backup location.
    -r   --restore             Restores ${FLPRODUCT} data from the config's
                               backup location.
    -l   --logs                Turn Logos logs on or off.
    -d   --dirlink             Create a symlink to the Windows Logos directory
                               in your Logos on Linux install dir.
                               The symlink's name will be 'installation_dir'.
    -s   --shortcut            Create or update the Logos shortcut, located in
                               HOME/.local/share/applications.
    --remove-all-index         Removes all index and library catalog files.
    --remove-library-catalog   Removes all library catalog files.
	--install-bash-completion  Installs the bash completion file to
                               /etc/bash_completion.d/.
UEOF
}

resourceSnapshot() {
	if [[ \$(which pidstat) ]]; then
		PIDSTR=\$(ps faux | grep "\${FLPRODUCT}" | grep "\${LOGOS_USER}" | grep -vE "(grep)" | awk '{printf "%s%s",sep, \$2; sep=" -p "} END{print ""}');
		printf "Snapshot of Logos System Resource Usage:\n\n"
		eval "pidstat --human -p \${PIDSTR}"
		eval "pidstat --human -d -p \${PIDSTR}"
		printf "\n---\n"
		echo "Note: There may be some processes improperly included."
	else
		echo "ERR: You need to install the 'sysstat' package in order to get the	 resource checking option's	  resource usage snapshot."
	fi
}

resourcePlot() {
	if [[ \$(which psrecord) ]]; then
		declare -a PIDARR PLOT;
		PIDARR=(\$(ps faux | grep "\${FLPRODUCT}" | grep "\${LOGOS_USER}" | grep -vE "(grep)" | awk '{print \$2}'));
		for i in \${!PIDARR[@]}; do
			PLOTNAME="\${APPDIR}/Logos-Resource-Plot_\${PIDARR[\$i]}.png"
			psrecord "\${PIDARR[\$i]}" --interval 1 --duration 60 --plot "\${PLOTNAME}" & PLOT[\$i]=\$!
			echo "Writing resource plot to \${PLOTNAME}."
			WAIT_PIDS="\${WAIT_PIDS} \${PLOT[\$i]}"
		done
		echo "Recordings will take 1 minute."
		eval "wait \${WAIT_PIDS}"
		exit ;
	else
		echo "ERR: You need to install the 'psrecord' package in order to get the   resource checking option's	   resource usage plot."
		fi
}

removeAllIndex() {
	echo "======= removing all ${FLPRODUCT}Bible BibleIndex, LibraryIndex, PersonalBookIndex, and LibraryCatalog files: ======="
	LOGOS_EXE="\$(find "\${WINEPREFIX}" -name ${FLPRODUCT}.exe | grep "${FLPRODUCT}\/${FLPRODUCT}.exe")"
	LOGOS_DIR="\$(dirname "\${LOGOS_EXE}")"
	rm -fv "\${LOGOS_DIR}"/Data/*/BibleIndex/*
	rm -fv "\${LOGOS_DIR}"/Data/*/LibraryIndex/*
	rm -fv "\${LOGOS_DIR}"/Data/*/PersonalBookIndex/*
	rm -fv "\${LOGOS_DIR}"/Data/*/LibraryCatalog/*
	echo "======= removing all ${FLPRODUCT}Bible index files done! ======="
	exit 0
}

removeLibraryCatalog() {
	echo "======= removing ${FLPRODUCT}Bible LibraryCatalog files only: ======="
	rm -fv "\${LOGOS_DIR}"/Data/*/LibraryCatalog/*
	echo "======= removing all ${FLPRODUCT}Bible index files done! ======="
	exit 0
}

indexing() {
	LOGOS_INDEXER_EXE=\$(find "\${WINEPREFIX}" -name ${FLPRODUCT}Indexer.exe |  grep "${FLPRODUCT}\/System\/${FLPRODUCT}Indexer.exe")
	if [ -z "\${LOGOS_INDEXER_EXE}" ] ; then
		echo "* ERROR: the ${FLPRODUCT}Indexer.exe can't be found!!!"
		exit 1
	fi
	echo "* Closing anything running in this wine bottle:"
	"\${WINESERVER_EXE}" -k
	echo "* Running the indexer:"
	"\${WINE_EXE}" "\${LOGOS_INDEXER_EXE}"
	"\${WINESERVER_EXE}" -w
	echo "======= indexing of ${FLPRODUCT}Bible run done! ======="
	exit 0
}

have_dep() {
    command -v "\$1" >/dev/null 2>&1
}       

check_commands() {
	for cmd in "\$@"; do
		if have_dep "\${cmd}"; then
			:
		else
			MISSING_CMD+=("\${cmd}")
		fi
	done
	if [ "\${#MISSING_CMD[@]}" -ne 0 ]; then
		echo "Your system is missing \${MISSING_CMD[*]}. Please install your distro's \${MISSING_CMD[*]} packages. Exiting."
		exit 1;
	fi
}

yes_or_no() {
	while true; do
		read -p "\$* [Y/n]: " yn
		case "\$yn" in
			[Yy]*) return 0 ;;
			[Nn]*) echo "Exiting"; return 1 ;;
		esac
	done
}

# Source: https://unix.stackexchange.com/a/259254/123999
bytesToHumanReadable() {
    local i=\${1:-0} d="" s=0 S=("Bytes" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "YiB" "ZiB")
    while ((i > 1024 && s < \${#S[@]}-1)); do
        printf -v d ".%02d" \$((i % 1024 * 100 / 1024))
        i=\$((i / 1024))
        s=\$((s + 1))
    done
    echo "\$i$d \${S[\$s]}"
}

checkDiskSpace() {
	if [ "\$1" == "b" ]; then
		DOCUMENTS_SPACE=\$(du --max=1 "\${SOURCEDIR}/Documents" | tail -n1 | cut -f1)
		USERS_SPACE=\$(du --max=1 "\${SOURCEDIR}/Users" | tail -n1 | cut -f1)
		DATA_SPACE=\$(du --max=1 "\${SOURCEDIR}/Data" | tail -n1 | cut -f1)
		REQUIRED_SPACE="\$(echo "\${DOCUMENTS_SPACE}" + "\${USERS_SPACE}" + "\${DATA_SPACE}" ' * 1024' | bc)"; export REQUIRED_SPACE;
		AVAILABLE_SPACE=\$(echo \$(df "\${BACKUPDIR}" | awk 'NR==2 {print \$4}') ' * 1024' | bc); export AVAILABLE_SPACE;
		REQUIRED_SPACE_HR=\$(bytesToHumanReadable "\${REQUIRED_SPACE}"); export REQUIRED_SPACE_HR;
		AVAILABLE_SPACE_HR=\$(bytesToHumanReadable "\${AVAILABLE_SPACE}"); export AVAILABLE_SPACE_HR;
		if (( \$AVAILABLE_SPACE < \$REQUIRED_SPACE )); then
			echo "Your install needs no more than \$REQUIRED_SPACE_HR but your backup directory only has \$AVAILABLE_SPACE_HR.";
			return 1;
		else
			if [[ "\$(read -e -p "Your install needs no more than \$REQUIRED_SPACE_HR. Your backup directory has \$AVAILABLE_SPACE_HR. Linux systems usually suggest using no more than 80% disk capacity. Proceed with backup? [Y/n]: "; echo \$REPLY)" == [Yy]* ]]; then
				return 0;
			else
				echo "Exiting.";
				exit 1;
			fi
		fi
	elif [ "\$1" == "r" ]; then
		REQUIRED_SPACE="\$(du --max=1 "\${BACKUPDIR}" | tail -n1 | cut -f1)"; export REQUIRED_SPACE;
		AVAILABLE_SPACE="\$(df "\${SOURCEDIR}" | awk 'NR==2 {print \$4}')"; export AVAILABLE_SPACE;
		REQUIRED_SPACE_HR="\$(du --max=1 "\${BACKUPDIR}" | tail -n1 | cut -f1)"; export REQUIRED_SPACE_HR;
		AVAILABLE_SPACE_HR="\$(df -h "\${SOURCEDIR}" | awk 'NR==2 {print \$4}')"; export AVAILABLE_SPACE_HR
		if (( \$AVAILABLE_SPACE < \$REQUIRED_SPACE )); then
			echo "Your install needs no more than \$REQUIRED_SPACE but your install directory only has \$AVAILABLE_SPACE.";
			return 1;
		else
			if [[ "\$(read -e -p "Your install needs no more than \$REQUIRED_SPACE. Your backup directory has \$AVAILABLE_SPACE. Linux systems usually suggest using no more than 80% disk capacity. Proceed with backup? [Y/n]: "; echo \$REPLY)" == [Yy]* ]]; then
				return 0;
			else
				echo "Exiting.";
				exit 1;
			fi
		fi
	fi
}

backup() {
	check_commands rsync;

	if [ "\${LOGOS_UID}" = "NoUser" ]; then
		echo "You must log in to your account first. Exiting."
		exit 1;
	fi

	if [ -d "\${BACKUPDIR}" ]; then
		SOURCEDIR="\${HERE}/data/wine64_bottle/drive_c/users/\${LOGOS_USER}/AppData/Local/Logos"; export SOURCEDIR;
		BACKUPDIR="\$BACKUPDIR"; export BACKUPDIR;
		checkDiskSpace b;
		mkdir -p "\${BACKUPDIR}/\${LOGOS_UID}"
		rsync -avhP --delete "\${SOURCEDIR}/Documents/" "\${BACKUPDIR}/\${LOGOS_UID}/Documents/";
		rsync -avhP --delete "\${SOURCEDIR}/Users/" "\${BACKUPDIR}/\${LOGOS_UID}/Users/";
		rsync -avhP --delete "\${SOURCEDIR}/Data/" "\${BACKUPDIR}/\${LOGOS_UID}/Data/";
		exit 0;
	else 
		echo "Backup directory does not exist. Exiting.";
		exit 1;
	fi
}

# TODO: The restore command restores the backup's Logos UID, but if this is a new install, this UID will be different. The restore command should    account for this change.
restore() {
	check_commands rsync;

	if [ "\${LOGOS_UID}" = "NoUser" ]; then
		echo "You must log in to your account first. Exiting."
		exit 1;
	fi

	if [ -d "\${BACKUPDIR}" ]; then
		SOURCEDIR="\${HERE}/data/wine64_bottle/drive_c/users/\${LOGOS_USER}/AppData/Local/Logos"; export SOURCEDIR;
		BACKUPDIR="\$BACKUPDIR"; export BACKUPDIR;
		checkDiskSpace r;
		rsync -avhP "\$BACKUPDIR/\$LOGOS_UID/Documents/" "\$SOURCEDIR/Documents/";
		rsync -avhP "\$BACKUPDIR/\$LOGOS_UID/Users/" "\$SOURCEDIR/Users/";
		rsync -avhP "\$BACKUPDIR/\$LOGOS_UID/Data/" "\$SOURCEDIR/Data/";
		exit 0;
	else
		echo "Backup directory does not exist. Exiting.";
		exit 1;
	fi
}

logsOn() {
	echo "======= enable ${FLPRODUCT}Bible logging only: ======="
	"\${WINE_EXE}" reg add "HKCU\\\\Software\\\\Logos4\\\\Logging" /v Enabled /t REG_DWORD /d 0001 /f
	"\${WINESERVER_EXE}" -w
	sed -i 's/LOGS="DISABLED"/LOGS="ENABLED"/' \${CONFIG_PATH}
	echo "======= enable ${FLPRODUCT}Bible logging done! ======="
	exit 0
}

logsOff() {
	echo "======= disable ${FLPRODUCT}Bible logging only: ======="
	"\${WINE_EXE}" reg add "HKCU\\\\Software\\\\Logos4\\\\Logging" /v Enabled /t REG_DWORD /d 0000 /f
	"\${WINESERVER_EXE}" -w
	sed -i -E 's/LOGS=".*"/LOGS="DISABLED"/' \${CONFIG_PATH}
	echo "======= disable ${FLPRODUCT}Bible logging done! ======="
	exit 0
}

dirlink() {
	echo "======= making ${FLPRODUCT}Bible directory lik only: ======="
	LOGOS_DIR_RELATIVE="\$(realpath --relative-to="\${HERE}" "\${LOGOS_DIR}")"
	rm -f "\${HERE}/installation_dir"
	ln -s "\${LOGOS_DIR_RELATIVE}" "\${HERE}/installation_dir"
	echo "dirlink created at: \${HERE}/installation_dir"
	echo "======= making ${FLPRODUCT}Bible directory link done! ======="
	exit 0
}

shortcut() {
	echo "======= making new ${FLPRODUCT}Bible shortcut only: ======="
	[ ! -f "\${HERE}/data/\${LOGOS_ICON_FILENAME}" ] && wget --inet4-only -c "\${LOGOS_ICON_URL}" -P "\${HERE}/data"
	mkdir -p "\${HOME}/.local/share/applications"
	rm -rf "\${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop"
	rm -rf "\${HOME}/.local/share/applications/${FLPRODUCT} Bible.desktop"
	[ ! -f "\${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop" ] && touch "\${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop"
	cat > "\${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop" << SEOF
[Desktop Entry]
Name=${FLPRODUCT}Bible
Comment=A Bible Study Library with Built-In Tools
Exec=\${HERE}/${FLPRODUCT}.sh
Icon=\${HERE}/data/${FLPRODUCTi}-128-icon.png
Terminal=false
Type=Application
Categories=Education;
SEOF
	chmod 755 "\${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop"
	echo "File: \${HOME}/.local/share/applications/${FLPRODUCT}Bible.desktop updated"
	echo "======= making new ${FLPRODUCT}Bible.desktop shortcut done! ======="
	exit 0
}

installBashCompletion() {
	URL="https://raw.githubusercontent.com/ferion11/LogosLinuxInstaller/master/LogosLinuxInstaller.bash"
	wget -O "${HOME}/Downloads/LogosLinuxInstaller.bash" "${URL}"
	if [ -d "/etc/bash_completion.d" ]; then
		sudo mv "${HOME}/Downloads/LogosLinuxInstaller.bash" /etc/bash_completion.d/
	else
		echo "ERROR: /etc/bash_completion.d is missing."
		exit 1
	fi
}
# END FUNCTION DECLARATIONS
# BEGIN OPTARGS
RESET_OPTARGS=true
for arg in "\$@"
do
	if [ -n "\$RESET_OPTARGS" ]; then
		unset RESET_OPTARGS
		set -- 
	fi
	case "\$arg" in # Relate long options to short options
		--help)        set -- "\$@" -h ;;
		--version)     set -- "\$@" -v ;;
		--force-root)  set -- "\$@" -f ;;
		--debug)       set -- "\$@" -D ;;
		--check-resources) set -- "\$@" -R ;;
		--edit-config) set -- "\$@" -e ;;
        --indexing)    set -- "\$@" -i ;;
		--backup)      set -- "\$@" -b ;;
		--restore)     set -- "\$@" -r ;;
		--logs)        set -- "\$@" -l ;;
        --dirlink)     set -- "\$@" -d ;;
		--shortcut)    set -- "\$@" -s ;;
		*)             set -- "\$@" "\$arg" ;;
	esac
done
OPTSTRING=':-:bdDefhilRrsv' # Available options

# First loop: set variable options which may affect other options
while getopts "\$OPTSTRING" opt; do
	case \$opt in
		f)  export LOGOS_FORCE_ROOT="1"; ;;
		D)  export DEBUG=true;
			WINEDEBUG=""; ;;
		\\?) echo "\$TITLE: -\$OPTARG: undefined option." >&2 && usage >&2 && exit ;;
		:)  echo "\$TITLE: -\$OPTARG: missing argument." >&2 && usage >&2 && exit ;;
	esac
done
OPTIND=1 # Reset the index.

# Second loop: determine user action
while getopts "\$OPTSTRING" opt; do
	case \$opt in
		h)  usage && exit ;;
		v)  echo "\$TITLE, \$VERSION by \$AUTHOR." && exit ;;
		-)
			case "\${OPTARG}" in
				remove-all-index)
					removeAllIndex ;;
				remove-library-catalog)
					removeLibraryCatalog ;;
				install-bash-completion)
					installBashCompletion ;;
				*)
					if [ "\$OPTERR" = 1 ] && [ "\${OPTSTRING:0:1}" != ":" ]; then
						echo "\$TITLE: --\${OPTARG}: undefined option." >&2 && usage >&2 && exit
					fi
			esac;;
		R)
			resourceSnapshot;
			resourcePlot;
			exit ;;
		e)
			if [ -n "\${EDITOR}" ]; then
				"\${EDITOR}" "\${CONFIG_PATH}" ;
			else
				echo "Error: The EDITOR variable is not set in user's environment."
			fi
			exit ;;
		i)
			indexing ;;
		b)
			backup ;;
		r)
			restore ;;
		l)
			if [ -f "\${CONFIG_PATH}" ]; then
				if [ "\${LOGS}" -eq "DISABLED" ]; then
					logsOn;
				elif [ "\${LOGS}" -eq "ENABLED" ]; then
					logsOff;
				else
					echo "LOGS var improperly set. Disabling ${FLPRODUCT} logs and resetting the LOGS value.";
					logsOff;
				fi
			else
				echo "--logs command failed. \${CONFIG_FILE} does not exist. Exiting.";
			fi
			;;
		d)
			dirlink ;;
        s)
			shortcut ;;
		\\?) echo "\$TITLE: -\$OPTARG: undefined option." >&2 && usage >&2 && exit ;;
		:)  echo "\$TITLE: -\$OPTARG: missing argument." >&2 && usage >&2 && exit ;;
	esac
done
if [ "\$OPTIND" -eq '1' ]; then
	echo "No options were passed.";
fi
shift \$((OPTIND-1))
# END OPTARGS

# BEGIN DIE IF ROOT
if [ "\$(id -u)" -eq '0' ] && [ -z "\${LOGOS_FORCE_ROOT}" ]; then
	echo "* Running Wine/winetricks as root is highly discouraged. Use -f|--force-root if you must run as root. See  https://wiki.winehq.org/FAQ#Should_I_run_Wine_as_root.3F"
	exit 1;
fi
# END DIE IF ROOT

debug() {
	[[ \$DEBUG = true ]] && return 0 || return 1
}

debug && echo "Debug mode enabled."

if [ -z "\${LOGOS_EXE}" ] ; then
	echo "======= Running control: ======="
	"\${HERE}/controlPanel.sh" "\$@"
	echo "======= control run done! ======="
	exit 0
fi

"\${WINE_EXE}" "\${LOGOS_EXE}"
"\${WINESERVER_EXE}" -w
#-------------------------------------------------

#------------- Ending block ----------------------
# restore IFS
IFS=\${IFS_TMP}
#-------------------------------------------------

