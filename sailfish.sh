#!/bin/bash

USER="nemo"
IP=192.168.1.234
SQL="sqlite3"
DB="/home/nemo/.local/share/jolla-notes/QML/OfflineStorage/Databases/8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite"

stc() {
    case $1 in
        0) tput setaf 0;; #black
        1) tput setaf 1;; #red
        2) tput setaf 2;; #green
        3) tput setaf 3;; #yellow
        4) tput setaf 4;; #blue
        5) tput setaf 5;; #magenta
        6) tput setaf 6;; #cyan
        7) tput setaf 7;; #white
        R) tput sgr0;;
    esac
}

usage() {
cat << EOF
USAGE $0 (ACTION) [COLOR|ID] [NOTE]

ACTIONS
  add      adds new note, with optional color and note from CMD
  list|ls  list all notes or note by ID
  del|rm   delete note by ID
  move|mv  move note to defined possition

COLOR
  Valid colors: $(stc 0)black $(stc 1)red $(stc 2)green $(stc 3)yellow $(stc 4)blue $(stc 5)magenta $(stc 6)cyan $(stc 7)white $(stc R)reset
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

w8() {
    secs=$1
    echo
    while [ $secs -gt 0 ]; do
        echo -ne "Removing note in $secs...\033[0K\r"
        sleep 1
        : $((secs--))
    done
}

# set color code based on user input
setColor() {
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
        $SQL $DB \"select color,pagenr,body from notes WHERE pagenr=$1;\";" | sed 's/^.*|\([0-9]*\)|/\n\r\1:\n\r/' ||
    ssh $USER@$IP "\
        $SQL $DB \"select color,pagenr,body from notes ORDER by pagenr ASC;\";" | sed 's/\(^.*|\)\([0-9]*\)|/\n\r\1\2:\n\r/'
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

#########
# BEGIN
#########

case $1 in
        add) shift 1; addN $@;;
    list|ls) listN $2;;
     del|rm) delN $2;;
    move|mv) moveN $2 $3;;
         * ) usage;;
esac

exit 0

#TODO
# list notes, delete notes, move notes, insert note to 1st possition

# INC DEC pagenr
# sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite "update notes SET pagenr=pagenr+1;"
# sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite "update notes SET pagenr=pagenr-1;"

# list DB schema
# $ sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite ".schema notes"
# CREATE TABLE notes (pagenr INTEGER, color TEXT, body TEXT);

# delete by ID
# sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite "delete from notes where pagenr=2"
# sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite "update notes SET pagenr=pagenr-1 WHERE pagenr > 2;"

# change color with sed
# echo -e `sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite  "select color,pagenr,body from notes" | sed 's/#cc7700\\(|[0-9]|\\)/\\\033\\[0\\;31m\1\\\033\\[0m/g'`

