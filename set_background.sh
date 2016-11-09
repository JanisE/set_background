# Given an image list ".dynamic_image_list.list", randomly chooses
# a proper image for a desktop background and sets it as such.

function Log
{
	# Log for the history.
	{
		echo -n "[$(date --iso-8601=seconds)] ";
		echo "$1";
	} >> .set_background.log
}

function SelectRandomFile
{
	# Use "readlink" to get the absolute path from a relative one.
	readlink --canonicalize-existing "$(\
		head --lines $(wc --lines .dynamic_image_list.list | \
		perl -pe 's/\s.*//' | \
		php -r 'print mt_rand(0, trim(fgets(STDIN)));') .dynamic_image_list.list | \
		tail --lines 1\
	)"
}

function IsAnimation
{
	if [[ $(identify -format %n "$1") != 1 ]]
	then
		echo 1;
	fi
}

function IsSupportedFileName
{
	if [[ $1 != *'#'* ]]
	then
		echo 1;
	fi
}

function TryHardToGetValidImage
{
	bFound=
	sFileName="$(SelectRandomFile)"

	for i in $(seq 1 50)
	do
		if [[ $(IsAnimation "$sFileName") \
			|| ! $(IsSupportedFileName "$sFileName") \
			|| ! -f "$sFileName" ]]
		then
			Log "Skipping $sFileName"
			sFileName="$(SelectRandomFile)"
		else
			bFound=1
			break;
		fi
	done

	if [[ $bFound ]]
	then
		echo "$sFileName"
	fi
}

function SetScalingMode
{
	read -r -d '' cPhpCalculateMode << 'cPhpCalculateMode'
	$aScreenDimensions = explode('x', trim(fgets(STDIN)));
	$sImageFile = trim(fgets(STDIN));

	$oImageSize = getimagesize($sImageFile);
	if ($oImageSize[0] > $aScreenDimensions[0] || $oImageSize[1] > $aScreenDimensions[1]) {
		print 'scaled';
	}
	else {
		print 'centered';
	}
cPhpCalculateMode

	# If run from cron, "DISPLAY" might be not set, but is needed by "xrandr".
	if [[ ! $DISPLAY ]]
	then
		export DISPLAY=:0
	fi

	sScreenDimensions=$(xrandr | grep '*' | perl -pe 's/\s*(\S+).*/$1/')
	gsettings set org.cinnamon.desktop.background picture-options "'$(echo $sScreenDimensions$'\n'"$1" | php -r "$cPhpCalculateMode")'"
}



sFileName="$(TryHardToGetValidImage)"

if [[ $sFileName ]]
then
	# If run from cron, this might be not set, but is needed by "gsettings set org.cinnamon.*".
	if [[ ! $DBUS_SESSION_BUS_ADDRESS ]]
	then
		export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS \
			/proc/$(pgrep -f 'gnome-session' | head -n1)/environ | \
			cut -d= -f2-)
	fi

	# Set the image.
	gsettings set org.cinnamon.desktop.background picture-uri "file://$sFileName"

	SetScalingMode "$sFileName";

	Log "$sFileName"
else
	Log "Could not find an image."
fi
