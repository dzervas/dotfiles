#!/bin/sh

XRANDR="xrandr"
CMD="${XRANDR}"
declare -A VOUTS
eval VOUTS=$(${XRANDR}|awk 'BEGIN {printf("(")} /^\S.*connected/{printf("[%s]=%s ", $1, $2)} END{printf(")")}')
declare -A POS

POS=([X]=0 [Y]=0)

find_mode() {
	echo $(${XRANDR} |grep ${1} -A1|awk '{FS="[ x ]"} /^\s/{printf("WIDTH=%s\nHEIGHT=%s", $4,$5)}')
}

xrandr_params_for() {
	if [ "${2}" == 'connected'  ]; then
		eval $(find_mode ${1})  #sets ${WIDTH} and ${HEIGHT}
		MODE="${WIDTH}x${HEIGHT}"
		SCALE=([X]=$(( 256000 / ${WIDTH} )) [Y]=$(( 160000 / ${HEIGHT} )))
		CMD="${CMD} --output ${1} --scale ${SCALE[X]:0:-2}.${SCALE[X]: -2}x${SCALE[Y]:0:-2}.${SCALE[Y]: -2} --mode ${MODE} --pos ${POS[X]}x${POS[Y]}"
		POS[X]=$((${POS[X]}+${WIDTH}))
		return 0
	else
		CMD="${CMD} --output ${1} --off"
		return 1
	fi

}

for VOUT in ${!VOUTS[*]}; do
	xrandr_params_for ${VOUT} ${VOUTS[${VOUT}]}
done
set -x
${CMD}
set +x

feh --bg-scale ~/.wallpaper.jpg
