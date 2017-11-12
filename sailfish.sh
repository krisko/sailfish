#!/bin/bash

#ssh nemo@192.168.1.234 "sqlite3 /home/nemo/.local/share/jolla-notes/QML/OfflineStorage/Databases/8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite \"insert into notes values ((select 1+(select pagenr from notes order by pagenr DESC limit 1)),'#abcabc','new note');\"; NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"

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
USAGE $0 (ACTION) [COLOR] [NOTE]

ACTIONS
  add     adds new note

COLOR
  Valid colors: $(stc 0)black $(stc 1)red $(stc 2)green $(stc 3)yellow $(stc 4)blue $(stc 5)magenta $(stc 6)cyan $(stc 7)white $(stc R)reset

NOTE
  text    text which will be set
  
EOF
}

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
        *) unset COLOR;;
    esac
}


chColor() {
    echo "Choose color: ";
    select COLOR in black red green yellow blue magenta cyan white; do
        setColor $COLOR
        break
    done;
}



#ssh $USER@$IP "$SQL $DB \"insert into notes values ((select 1+(select pagenr from notes order by pagenr DESC limit 1)),'#abcabc','$NOTE');\"; \
#    NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"

addNote() {
    # detect if we have color from param
    [[ -n $1 ]] && setColor $1
    [[ -n $COLOR ]] && shift 1 || chColor
    # take the note
    [[ -n $1 ]] && NOTE="$@" || read -p "Enter note: " NOTE

    echo ssh $USER@$IP "\
        $SQL $DB \"update notes SET pagenr=pagenr+1;\"; \
        $SQL $DB \"insert into notes values (1,'$COLOR','$NOTE');\"; \
        NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
    ssh $USER@$IP "\
        $SQL $DB \"update notes SET pagenr=pagenr+1;\"; \
        $SQL $DB \"insert into notes values (1,'$COLOR','$NOTE');\"; \
        NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"
}

listNotes() {
# sqlite3 8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite  "select color,pagenr,body from notes ORDER by pagenr ASC" | sed 's/^.*|\([0-9]*\)|/\n\r\1:\n\r/'
:
}

#########
# BEGIN
#########

case $1 in
    add) shift 1; addNote $@;;
    *  ) usage;;
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

