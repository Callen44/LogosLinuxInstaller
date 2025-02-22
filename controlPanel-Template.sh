#!/usr/bin/env bash
TITLE="controlPanel.sh"
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
	if [ -z \${WINEPREFIX} ] || [ -z \${WINE_EXE} ] || [ -z "\${WINESERVER_EXE}" ] || [ -z "\${APPDIR_BINDIR}" ] || [ -z "\${APPIMAGE_LINK_SELECTION_NAME}" ] || [ -z "\${WINETRICKSBIN}" ]; then
		echo "controlPanel.sh needs these variables set in the config file:"
		echo "- WINEPREFIX"
		echo "- WINE_EXE"
		echo "- WINESERVER_EXE"
		echo "- APPDIR_BINDIR"
		echo "- APPIMAGE_LINK_SELECTION_NAME"
		echo "- WINETRICKSBIN"
		echo "Config file incomplete. Exiting." >&2 && exit 1;
	fi
else
	[ -x "\${HERE}/data/bin/wine64" ] && export PATH="\${HERE}/data/bin:\${PATH}"
	export WINEPREFIX="\${HERE}/data/wine64_bottle"; export WINEPREFIX;
	export WINE_EXE="${WINE_EXE}"; export WINE_EXE;
	export WINESERVER_EXE="${WINESERVER_EXE}"; export WINESERVER_EXE;
	export APPDIR_BINDIR="${APPDIR_BINDIR}"; export APPDIR_BINDIR
	export APPIMAGE_LINK_SELECTION_NAME="${APPIMAGE_LINK_SELECTION_NAME}"; export APPIMAGE_LINK_SELECTION_NAME;
fi
if [ -z "${WINETRICKS_URL}" ]; then WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"; export WINETRICKS_URL; fi

if [ -z "\${WINEDEBUG}" ]; then WINEDEBUG="fixme-all,err-all"; export WINEDEBUG; fi # Make wine output less verbose
# END ENVIRONMENT
# BEGIN FUNCTION DECLARATIONS
usage() {
cat << EEOF
\$TITLE, by \$AUTHOR, \$VERSION.

Usage: ./\$TITLE
Interact with ${FLPRODUCT} Bible Software in Wine on Linux.

Options:
    -h   --help         Prints this help message and exit.
    -v   --version      Prints version information and exit.
    -D   --debug        Makes Wine print out additional info.
    -f   --force-root   Sets LOGOS_FORCE_ROOT to true, which permits
                        the root user to run the script.
    --wine64            Run the script's wine64 binary.
    --wineserver        Run the script's wineserver binary.
    --winetricks        Run winetricks.
    --setAppImage       Set the script's AppImage file. NOTE:
                        Currently broken. Disabled until fixed.
EEOF
}

cli_download() {
	URI="\${1}"
	DESTINATION="\${2}"
	FILENAME="\${URI##*/}"

	if [ "\${DESTINATION}" != "\${DESTINATION%/}" ]; then
		TARGET="\${DESTINATION}/\${1##*/}"
		[ -d "\${DESTINATION}" ] || mkdir -p "\${DESTINATION}" || echo "Cannot create \${DESTINATION}" && exit 1
	elif [ -d "\${DESTINATION}" ]; then
		TARGET="\${DESTINATION}/${1##*/}"
	else
		TARGET="\${DESTINATION}"
		[ -d "\${DESTINATION%/*}" ] || mkdir -p "\${DESTINATION%/*}" || echo "Cannot create directory \${DESTINATION%/*}" && exit 1
	fi
	echo "\${URI}"
	wget --inet4-only -c "\${URI}" -O "\${TARGET}"
}
setWinetricks() {
	if [ -f "\${APPDIR_BINDIR}/winetricks" ]; then
		WINETRICKSBIN="\${APPDIR_BINDIR}/winetricks"
	elif [ \$(which winetricks) &> /dev/null ]; then
		LOCAL_WINETRICKS_VERSION=\$(winetricks --version | awk -F' ' '{print \$1}')
		if [ "\${LOCAL_WINETRICKS_VERSION}" -ge "20220411" ]; then
			WINETRICKSBIN="\$(which winetricks)"
		fi
	else
		if [ ! -z "\${WINETRICKS_URL}" ]; then
			cli_download "\${WINETRICKS_URL}" "\${APPDIR_BINDIR}/winetricks"
			chmod 755 "\${APPDIR_BINDIR}/winetricks"
			WINETRICKSBIN="\${APPDIR_BINDIR}/winetricks"
			if [ -z "${CONFIG_PATH}" ]; then
				sed -ri 's/(WINETRICKSBIN=)(".*")/\1TAYLOR/' "\${CONFIG_PATH}"
			fi
		else
			echo "WINETRICKS_URL not set."
		fi
	fi
	export WINETRICKSBIN
}
runWinetricks() {
	if [ ! -z "\${WINETRICKSBIN}" ] && [ -f "\${WINETRICKSBIN}" ]; then
		:
	else
		setWinetricks
	fi
    "\${WINETRICKSBIN}" "$@"
    "\${WINESERVER_EXE}" -w
}

selectAppImage() {
		echo "======= Running AppImage Selection only: ======="
		APPIMAGE_FILENAME=""
		APPIMAGE_LINK_SELECTION_NAME="\${APPIMAGE_LINK_SELECTION_NAME}"

		APPIMAGE_FULLPATH="\$(zenity --file-selection --filename="\${HERE}"/data/*.AppImage --file-filter='AppImage files | *.AppImage *.Appimage *.appImage *.appimage' --file-filter='All files | *')"
		if [ -z "\${APPIMAGE_FULLPATH}" ]; then
			echo "No *.AppImage file selected! exiting…"
			exit 1
		fi

		APPIMAGE_FILENAME="\${APPIMAGE_FULLPATH##*/}"
		APPIMAGE_DIR="\${APPIMAGE_FULLPATH%\${APPIMAGE_FILENAME}}"
		APPIMAGE_DIR="\${APPIMAGE_DIR%?}"
		#-------

		if [ "\${APPIMAGE_DIR}" != "\${HERE}/data" ]; then
			if zenity --question --width=300 --height=200 --text="Warning: The AppImage isn't at \"./data/ directory\"\!\nDo you want to copy the AppImage to the \"./data/\" directory keeping portability?" --  title='Warning!'; then
					[ -f "\${HERE}/data/\${APPIMAGE_FILENAME}" ] && rm -rf "\${HERE}/data/\${APPIMAGE_FILENAME}"
					cp "\${APPIMAGE_FULLPATH}" "\${HERE}/data/"
					APPIMAGE_FULLPATH="\${HERE}/data/\${APPIMAGE_FILENAME}"
			else
				echo "Warning: Linking \${APPIMAGE_FULLPATH} to ./data/bin/\${APPIMAGE_LINK_SELECTION_NAME}"
					chmod +x "\${APPIMAGE_FULLPATH}"
					ln -s "\${APPIMAGE_FULLPATH}" "\${APPIMAGE_LINK_SELECTION_NAME}"
					rm -rf "\${HERE}/data/bin/\${APPIMAGE_LINK_SELECTION_NAME}"
					mv "\${APPIMAGE_LINK_SELECTION_NAME}" "\${HERE}/data/bin/"
					(DISPLAY="" "\${HERE}/controlPanel.sh" "\${WINE_EXE}" wineboot) | zenity --progress --title="Wine Bottle update" --text="Updating Wine Bottle…" --pulsate --auto-close --no-cancel
					echo "======= AppImage Selection run done with external link! ======="
					exit 0
			fi
		fi

		echo "Info: Linking ../\${APPIMAGE_FILENAME} to ./data/bin/\${APPIMAGE_LINK_SELECTION_NAME}"
		chmod +x "\${APPIMAGE_FULLPATH}"
		ln -s "../\${APPIMAGE_FILENAME}" "\${APPIMAGE_LINK_SELECTION_NAME}"
		rm -rf "\${HERE}/data/bin/\${APPIMAGE_LINK_SELECTION_NAME}"
		mv "\${APPIMAGE_LINK_SELECTION_NAME}" "\${HERE}/data/bin/"
		(DISPLAY="" "\${HERE}/controlPanel.sh" "\${WINE_EXE}" wineboot) | zenity --progress --title="Wine Bottle update" --text="Updating Wine Bottle…" --pulsate --auto-close --no-cancel
		echo "======= AppImage Selection run done! ======="
		exit 0
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
		--help)       set -- "\$@" -h ;;
		--version)    set -- "\$@" -V ;;
		--force-root) set -- "\$@" -f ;;
		--debug)      set -- "\$@" -D ;;
		*)            set -- "\$@" "\$arg" ;;
	esac
done
OPTSTRING=':-:hvDf' # Available options

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
				wine64)
					shift
					"\${WINE_EXE}" "\$@"
					"\${WINESERVER_EXE}" -w
					exit 0 ;;
				wineserver)
					shift
					"\${WINESERVER_EXE}" "\$@"
					exit 0 ;;
				winetricks)
					shift
					runWinetricks;
					exit 0 ;;
				#selectAppImage)
					#selectAppImage ;;
				*)
					if [ "\$OPTERR" = 1 ] && [ "\${OPTSTRING:0:1}" != ":" ]; then
						echo "\$TITLE: --\${OPTARG}: undefined option." >&2 && usage >&2 && exit
					fi
			esac;;
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

"\${WINE_EXE}" control
"\${WINESERVER_EXE}" -w
#-------------------------------------------------

#------------- Ending block ----------------------
# restore IFS
IFS=\${IFS_TMP}
#-------------------------------------------------

