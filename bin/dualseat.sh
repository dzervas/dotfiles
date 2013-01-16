hopt -s extglob

IFS=$'\n' DEVICE_LIST=( $(xinput list --short) )

for (( I=0; I<${#DEVICE_LIST[@]}; I++ )); do
    IFS=$'\t' INFO=( ${DEVICE_LIST[$I]} )
    [ "${INFO[2]:1:1}" = "s" ] || continue
    NAME="${INFO[0]:6}"
    NAME="${NAME%%*([[:blank:]])}"
    ID="${INFO[1]#id=}"
    [[ "$NAME" != *XTEST* ]] || continue
    case "${INFO[2]:8:1}" in
    "p" )
        POINTERS+=( "$ID"$'\t'"$NAME" )
        ;;
    "k" )
        KEYBOARDS+=( "$ID"$'\t'"$NAME" )
        ;;
    esac
done

MASTER_NAME="$( zenity --title="Enter name" --entry --text="Enter name for new master" )"
[ -n "$MASTER_NAME" ] || exit 1

POINTER="$( IFS=$'\t' zenity --title="Select device" --list --multiple --text="Choose a pointer" --column="Id" --column="Name" ${POINTERS[@]} )"
[ -n "$POINTER" ] || exit 1

KEYBOARD="$( IFS=$'\t' zenity --title="Select device" --list --multiple --text="Choose a keyboard" --column="Id" --column="Name" ${KEYBOARDS[@]} )"
[ -n "$KEYBOARD" ] || exit 1

xinput create-master "$MASTER_NAME"

IFS="|"
for ID in $POINTER; do
    xinput reattach "$ID" "$MASTER_NAME pointer"
done

for ID in $KEYBOARD; do
    xinput reattach "$ID" "$MASTER_NAME keyboard"
done
