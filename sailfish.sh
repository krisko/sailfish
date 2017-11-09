#!/bin/bash

#ssh nemo@192.168.1.234 "sqlite3 /home/nemo/.local/share/jolla-notes/QML/OfflineStorage/Databases/8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite \"insert into notes values ((select 1+(select pagenr from notes order by pagenr DESC limit 1)),'#abcabc','new note');\"; NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"

USER="nemo"
IP=192.168.1.234
SQL="sqlite3"
DB="/home/nemo/.local/share/jolla-notes/QML/OfflineStorage/Databases/8b63c31a7656301b3f7bcbbfef8a2b6f.sqlite"

read -p "enter note: " NOTE

ssh $USER@$IP "$SQL $DB \"insert into notes values ((select 1+(select pagenr from notes order by pagenr DESC limit 1)),'#abcabc','$NOTE');\"; \
    NOTEPID=\$(pgrep jolla-notes) && [[ -n \$NOTEPID ]] && kill -1 \$NOTEPID"

#TODO
# list notes, delete notes, move notes, insert note to 1st possition
