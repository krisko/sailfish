#!/bin/bash
##################################################
# Author:       KrisKo 2017
# Description:  Script for handling jolla notes via ssh coneection
# See usage for more details
##################################################

############
# VARIABLES
############
USER="nemo"
IP=192.168.1.234
SQL="sqlite3"
DB="/home/nemo/.local/share/jolla-notes/QML/OfflineStorage/Databases/8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite"
# tmp file for listNotes
LSN=/tmp/notes.$$.tmp
# tmp file for color output
NTC=/tmp/notesc.$$.tmp

############
# FUNCTIONS
############

# set color code based on user input
setColor() {
    [[ $1 == "ls" ]] && 
        BLACK='\033[40m'  \
        RED='\033[41m'    \
        GREEN='\033[42m'  \
        YELLOW='\033[43m' \
        BLUE='\033[44m'   \
        MAGENTA='\033[45m' \
        CYAN='\033[46m'   \
        WHITE='\033[47m'  \
        NC='\033[0m'       ||
    case $1 in
        black)   COLOR="#000000";;
        red)     COLOR="#cc0000";;
        green)   COLOR="#00cc00";;
        yellow)  COLOR="#cccc00";;
        blue)    COLOR="#0000cc";;
        magenta) COLOR="#cc00cc";;
        cyan)    COLOR="#00cccc";;
        white)   COLOR="#ffffff";;
        pick)    COLOR=$(kcolorchooser --print);;
        *) unset COLOR;;
    esac
}

# show usage
usage() {
setColor ls
cat << EOF
USAGE $0 (ACTION) [COLOR|ID] [NOTE]

ACTIONS
  add      adds new note, with optional color and note from CMD
  list|ls  list all notes or note by ID
  del|rm   delete note by ID
  move|mv  move note to defined possition
  ccol|cc  change color of the note by ID

COLOR
  Valid colors: $(echo -e $BLACK BLACK $RED RED $GREEN GREEN $YELLOW YELLOW $BLUE BLUE $MAGENTA MAGENTA $CYAN CYAN $WHITE WHITE $NC)
  Or you can use option "pick" to launch color picker, to select custom color

NOTE
  text    text which will be set
  
EOF
}

# message system
msg() {
    SEV=$(echo -e "$1" | tr [:lower:] [:upper:])
    echo "$SEV": "$2"
    [[ "$SEV" == "ERROR" || "$SEV" == "FATAL" ]] && exit 1
}

# delaying function
w8() {
    secs=$1
    echo
    while [ $secs -gt 0 ]; do
        echo -ne "Removing note in $secs...\033[0K\r"
        sleep 1
        : $((secs--))
    done
}

# interactively choose color
chColor() {
    echo "Choose color: ";
    select COLOR in black red green yellow blue magenta cyan white; do
        setColor $COLOR
        break
    done;
}

# add new note
addN() {
    # detect if we have color from param
    [[ -n $1 ]] && setColor $1
    [[ -n $COLOR ]] && shift 1 || chColor
    # take the note
    [[ -n $1 ]] && NOTE="$@" || read -p "Enter note: " NOTE

    ssh $USER@$IP "\
        $SQL $DB \"update notes SET pagenr=pagenr+1;\"; \
        $SQL $DB \"insert into notes values (1,'$COLOR','$NOTE');\"; \
        NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
}

# list notes from the phone
listN() {
    # if we have specific ID list only that
    [[ $1 =~ ^[0-9]+$ ]] &&
    ssh $USER@$IP "\
        $SQL $DB \"select color,pagenr,body from notes WHERE pagenr=$1;\";" | sed 's/^.*|\([0-9]*\)|/\n\r\1:\n\r/' > $LSN ||
    ssh $USER@$IP "\
        $SQL $DB \"select color,pagenr,body from notes ORDER by pagenr ASC;\";" | sed 's/\(^.*|\)\([0-9]*\)|/\n\r\1\2:\n\r/' > $LSN

    setColor ls
    sed -e 's/\#000000|\([0-9]:\)/\\\'$BLACK'\1\\\'$NC'/'   \
        -e 's/\#cc0000|\([0-9]:\)/\\\'$RED'\1\\\'$NC'/'     \
        -e 's/\#00cc00|\([0-9]:\)/\\\'$GREEN'\1\\\'$NC'/'   \
        -e 's/\#cccc00|\([0-9]:\)/\\\'$YELLOW'\1\\\'$NC'/'  \
        -e 's/\#0000cc|\([0-9]:\)/\\\'$BLUE'\1\\\'$NC'/'    \
        -e 's/\#cc00cc|\([0-9]:\)/\\\'$MAGENTA'\1\\\'$NC'/' \
        -e 's/\#00cccc|\([0-9]:\)/\\\'$CYAN'\1\\\'$NC'/'    \
        -e 's/\#ffffff|\([0-9]:\)/\\\'$WHITE'\1\\\'$NC'/'   \
        -e 's/^\#.*|\([0-9]:\)/\1/' $LSN > $NTC

    rm $LSN
    while read note; do
        echo -e $note;
    done < $NTC
    rm $NTC
}

# delete note by ID
delN() {
    # confirm deletion by ID
    [[ $1 =~ ^[0-9]+$ ]] &&
        listN $1 ||
        msg error "Invalid ID"
    # wait befor deleting
    w8 5

    ssh $USER@$IP "\
        $SQL $DB \"delete from notes where pagenr=$1;\"; \
        $SQL $DB \"update notes SET pagenr=pagenr-1 WHERE pagenr > $1;\"; \
        NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
}

# move note from posiion to new possition
moveN() {
    [[ $1 =~ ^[0-9]+$ ]] && [[ $2 =~ ^[0-9]+$ ]] || msg error "Invalid ID"
    [[ $1 -eq $2 ]] && msg info "Nothing to do." && exit 0
    # check if note exists
    [[ -n "$(listN $1)" ]] || msg error "Note with ID=$1 not found."
    [[ $1 -lt $2 ]] &&
        ssh $USER@$IP "\
            $SQL $DB \"update notes SET pagenr=1000 WHERE pagenr=$1;\"; \
            $SQL $DB \"update notes SET pagenr=pagenr-1 WHERE pagenr > $1 AND pagenr <= $2;\"; \
            $SQL $DB \"update notes SET pagenr=$2 WHERE pagenr=1000;\"; \
            NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
    [[ $1 -gt $2 ]] &&
        ssh $USER@$IP "\
            $SQL $DB \"update notes SET pagenr=1000 WHERE pagenr=$1;\"; \
            $SQL $DB \"update notes SET pagenr=pagenr+1 WHERE pagenr < $1 AND pagenr >= $2;\"; \
            $SQL $DB \"update notes SET pagenr=$2 WHERE pagenr=1000;\"; \
            NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
}

# change note color
noteC() {
    [[ $1 =~ ^[0-9]+$ ]] || msg error "Invalid ID"
    # check if note exists
    [[ -n "$(listN $1)" ]] || msg error "Note with ID=$1 not found."
    # detect if we have color from param
    [[ -n $2 ]] && setColor $2
    [[ -n $COLOR ]] || chColor

    ssh $USER@$IP "\
        $SQL $DB \"update notes SET color='$COLOR' WHERE pagenr=$1;\"; \
        NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
}

#########
# BEGIN
#########

case $1 in
        add) shift 1; addN $@;;
    list|ls) listN $2;;
     del|rm) delN $2;;
    move|mv) moveN $2 $3;;
    ccol|cc) noteC $2 $3;;
         * ) usage;;
esac

exit 0

##############################################
# TODO/ChangeLog # Author  # Description #
##############################################
# 0.0.1 20171109 # krisko  # Idea, sketch
# 0.1.0 20171110 # krisko  # Prototype, first working function - add
# 1.0.0 20171113 # krisko  # Implemented all basic functions
# 1.0.1 20171113 # krisko  # Fixed wrong variable name
##############################################
# NOTES
##############################################
# list DB schema
# $ sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite ".schema notes"
# CREATE TABLE notes (pagenr INTEGER, color TEXT, body TEXT);
##############################################
