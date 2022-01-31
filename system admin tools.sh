#!/bin/sh

EntrancePage() {
    local TMPFILE=$(mktemp tmp.XXXXXX)
    dialog  --title "System Info Panel" \
            --menu "Please select the command you want to use" \
            15 40 10 \
            1 "POST ANNOUNCEMENT" \
            2 "USER LIST" 2>"$TMPFILE"
    local choice=$?
    local action=$(cat "$TMPFILE") 
    rm "$TMPFILE"
    if [ "$choice" = 0 ] ; then
        if [ "$action" = 1 ] ; then
            PostAnnouncement
        elif [ "$action" = 2 ] ; then
            UserList
        fi
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    fi
}

PostAnnouncement() {
    local TMPFILE=$(mktemp tmp.XXXXXX)
    local users=$(cat /etc/master.passwd | awk 'BEGIN{
                                                    FS = ":";
                                                    command = "";
                                                }
                                                (NF > 8 && ($2 !~ /^\*/)){
                                                    command = command $3 " " $1 " off ";
                                                }
                                                (NF > 8 && ($2 ~ /^\*LOCK/)){
                                                    command = command $3 " " $1 " off ";
                                                }
                                                END{
                                                    printf("%s", command);
                                                }')
    dialog  --title "POST ANNOUNCEMENT" \
            --extra-button --extra-label All \
            --checklist "Select the users you want to post" \
            15 40 10 \
            $users 2>"$TMPFILE"
    local choice=$?
    if [ "$choice" = 1 ] ; then
        rm "$TMPFILE"
        EntrancePage
    else
        if [ "$choice" = 3 ] ; then
            rm "$TMPFILE"
            TMPFILE=$(mktemp tmp.XXXXXX)
            cat /etc/master.passwd | awk 'BEGIN{
                                                FS = ":";
                                                command = "";
                                            }
                                            (NF > 8 && ($2 !~ /^\*/)){
                                                command = command $3 " ";
                                            }
                                            (NF > 8 && ($2 ~ /^\*LOCK/)){
                                                command = command $3 " ";
                                            }
                                            END{
                                                printf("%s", command);
                                            }' > "$TMPFILE"
        fi
        local args=$(cat "$TMPFILE")
        rm "$TMPFILE"
        PostAnnouncementTo "$args"
    fi
}

PostAnnouncementTo() {
    local TMPFILE=$(mktemp tmp.XXXXXX)
    pw groupadd TMPGROUP
    for i in $@ ; do 
        local name=$(getent passwd "$i" | cut -d: -f1)
        pw groupmod TMPGROUP -m "$name"
    done
    
    dialog  --title "Post an announcement" \
            --inputbox "Enter your message:" \
            15 40 \
            2>"$TMPFILE"
    local choice=$?

    if [ "$choice" = 0 ] ; then
        wall -g TMPGROUP "$TMPFILE"
        for i in $@ ; do 
            local name=$(getent passwd "$i" | cut -d: -f1)
            pw groupmod TMPGROUP -d "$name"
        done
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    fi
    rm "$TMPFILE"
    pw groupdel TMPGROUP
    EntrancePage
}

UserList() {
    local TMPFILE=$(mktemp tmp.XXXXXX)
    local onlineUserList=$(mktemp tmp.XXXXXX)
    who | awk '{print $1}' > "$onlineUserList"
    local users=$(cat /etc/master.passwd | awk 'BEGIN{
                                                    FS = ":";
                                                    command = "";
                                                }
                                                (NF > 8 && ($2 !~ /^\*/)){
                                                    command = command $3 " " $1 " \n";
                                                }
                                                (NF > 8 && ($2 ~ /^\*LOCK/)){
                                                    command = command $3 " " $1 " \n";
                                                }
                                                END{
                                                    printf("%s", command);
                                                }')
    
    for i in $(cat "$onlineUserList") ; do
        users=$(echo "$users" | awk -v name="$i" 'BEGIN{
                                        command = "";
                                    }
                                    {
                                        if($2 == name) {
                                            command = command $1 " " $2 "[*]\n";
                                        }
                                        else {
                                            command = command $1 " " $2 "\n";
                                        }
                                    }
                                    END{
                                        printf("%s", command);
                                    }')
    done

    dialog  --cancel-label "EXIT" \
            --ok-label "SELECT" \
            --menu "User Info Panel" \
            15 40 10 \
            $users \
            2>"$TMPFILE"
    local choice=$?
    if [ "$choice" = 0 ] ; then
        local selection=$(cat "$TMPFILE")
        UserAction "$selection"
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        EntrancePage
    fi
    rm "$TMPFILE"
    rm "$onlineUserList"
}

UserAction() {
    local TMPFILE=$(mktemp tmp.XXXXXX)
    local uid=$@
    local uname=$(getent passwd "$uid" | cut -d: -f1)
    local status=$(cat /etc/master.passwd | awk -v name="$uname" 'BEGIN{
                                                FS = ":";
                                            }
                                            ($1 == name){
                                                if ($2 ~ /^\*LOCK/) {
                                                    print "locked"
                                                }
                                                else {
                                                    print "not locked"
                                                }
                                            }')
    if [ "$status" = locked ] ; then
        dialog  --cancel-label "EXIT" \
                --menu "User $uname" \
                15 40 10 \
                1 "UNLOCK IT" \
                2 "GROUP INFO" \
                3 "PORT INFO" \
                4 "LOGIN HISTORY" \
                5 "SUDO LOG" \
                2>"$TMPFILE"
    else
        dialog  --cancel-label "EXIT" \
                --menu "User $uname" \
                15 40 10 \
                1 "LOCK IT" \
                2 "GROUP INFO" \
                3 "PORT INFO" \
                4 "LOGIN HISTORY" \
                5 "SUDO LOG" \
                2>"$TMPFILE"
    fi
    local choice=$?
    if [ "$choice" = 0 ] ; then
        local action=$(cat "$TMPFILE")
        case $action in
            1)
                if [ "$uid" = 0 ] ; then 
                    dialog  --title "(ˊ-ω-ˋ)" \
                            --msgbox "What are you doing?" \
                            15 40
                    UserAction "$uid"
                else
                    Locking "$uid" "$status"
                fi
            ;;
            2)
                GroupInfo "$uid"
            ;;
            3)
                PortInfo "$uid"
            ;;
            4)
                LoginHistory "$uid"
            ;;
            5)
                SudoLog "$uid"
            ;;
            *)
            ;;
        esac
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        UserList
    fi
    rm "$TMPFILE"
}

Locking() {
    local status=$2
    local uid=$1
    local name=$(getent passwd "$uid" | cut -d: -f1)
    local choice=$?

    if [ "$status" = locked ] ; then
        dialog  --title "UNLOCK IT" \
                --yesno "Are you sure you want to do this?" \
                10 40
        choice=$?
        if [ "$choice" = 0 ] ; then
            pw unlock "$name"
            dialog  --title "UNLOCK IT" \
                    --msgbox "UNLOCK SUCCEED!" \
                    15 40
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        UserAction "$uid"
    else
        dialog  --title "LOCK IT" \
                --yesno "Are you sure you want to do this?" \
                10 40
        choice=$?
        if [ "$choice" = 0 ] ; then
            pw lock "$name"
            pkill -u "$uid"
            dialog  --title "LOCK IT" \
                    --msgbox "LOCK SUCCEED!" \
                    15 40
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        UserAction "$uid"
    fi
}

GroupInfo() {
    local uid=$@
    local name=$(getent passwd "$uid" | cut -d: -f1)
    local groupinfo=$(id "$name" | awk 'BEGIN{ 
                                            print "GROUP_ID\tGROUP_NAME" 
                                        } 
                                        { 
                                            print substr($3, 8) 
                                        }' | awk 'BEGIN{ 
                                                    FS="," 
                                                    } 
                                                    { 
                                                        for(i = 1; i <= NF; i++) { 
                                                            print $i 
                                                        } 
                                                    }' | sed -n -e 's/(/\t\t/p' -e 's/GROUP/GROUP/p' | sed -n -e 's/)//p' -e 's/GROUP/GROUP/p' )
    dialog  --title "Group Info" \
            --no-collapse \
            --extra-button \
            --extra-label "EXPORT" \
            --msgbox "$groupinfo" \
            20 80
    
    local choice=$?
    if [ "$choice" = 0 ] ; then
        UserAction "$uid"
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        local TMPFILE=$(mktemp tmp.XXXXXX)
        dialog  --title "Export to file" \
                --inputbox "Enter the path:" \
                15 40 \
                2>"$TMPFILE"
        choice=$?
        if [ "$choice" = 0 ] ; then
            local dest=$(cat "$TMPFILE")
            local homedir=$(eval echo ~${SUDO_USER})
            dest=$(echo "$dest" | awk -v homedir="$homedir" '{ 
                                                            if ($0 ~ /^\~/) { 
                                                                line = $0; 
                                                                line = homedir substr(line, 2); 
                                                                print line; 
                                                            } else { 
                                                                if ($0 ~ /^\//) {
                                                                    print $0; 
                                                                } else {
                                                                    line = $0; 
                                                                    line = homedir "/" line; 
                                                                    print line; 
                                                                }
                                                            }
                                                        }')
            echo "$groupinfo" > "$dest"
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        GroupInfo "$uid"
        rm "$TMPFILE"
    fi
}

PortInfo() {
    local uid=$1
    local name=$(getent passwd "$uid" | cut -d: -f1)
    local TMPFILE=$(mktemp tmp.XXXXXX)
    local ports=$(sockstat -4 | grep "$name" | awk '{ print $3 " " $5 "_" $6 }')
    if [ ! "$ports" = "" ] ; then
        dialog  --title "Port Info" \
                --menu "PID and Port" \
                15 40 10 \
                $ports 2>"$TMPFILE"
        local choice=$?
        if [ "$choice" = 1 ] ; then
            UserAction "$uid"
        else
            local selection=$(cat "$TMPFILE")
            processState "$selection"
        fi
    else
        dialog  --title "Port Info" \
                --msgbox "no ports" \
                20 80
        UserAction "$uid"
    fi
    rm "$TMPFILE"
}

processState() {
    local pid=$@
    local stats=$(ps "$pid" -o 'user, pid, ppid, stat, %cpu, %mem, command' | awk '($0 !~ /^USE/) {
                                                                                        print "USER\t\t" $1;
                                                                                        print "PID\t\t" $2;
                                                                                        print "PPID\t\t" $3;
                                                                                        print "STAT\t\t" $4;
                                                                                        print "%CPU\t\t" $5;
                                                                                        print "%MEM\t\t" $6;
                                                                                        printf("COMMAND\t%s ", $7);
                                                                                        for(i = 8; i <= NF; i++){
                                                                                            printf("%s ", $i);
                                                                                        }
                                                                                    }' )
    dialog  --title "Port Info" \
            --no-collapse \
            --extra-button \
            --extra-label "EXPORT" \
            --msgbox "$stats" \
            20 80
    
    local choice=$?
    if [ "$choice" = 0 ] ; then
        PortInfo "$uid"
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        local TMPFILE=$(mktemp tmp.XXXXXX)
        dialog  --title "Export to file" \
                --inputbox "Enter the path:" \
                15 40 \
                2>"$TMPFILE"
        choice=$?
        if [ "$choice" = 0 ] ; then
            local dest=$(cat "$TMPFILE")
            local homedir=$(eval echo ~${SUDO_USER})
            dest=$(echo "$dest" | awk -v homedir="$homedir" '{ 
                                                            if ($0 ~ /^\~/) { 
                                                                line = $0; 
                                                                line = homedir substr(line, 2); 
                                                                print line; 
                                                            } else { 
                                                                if ($0 ~ /^\//) {
                                                                    print $0; 
                                                                } else {
                                                                    line = $0; 
                                                                    line = homedir "/" line; 
                                                                    print line; 
                                                                }
                                                            }
                                                        }')
            echo "$stats" > "$dest"
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        PortInfo "$uid"
        rm "$TMPFILE"
    fi
}

LoginHistory() {
    local uid=$1
    local name=$(getent passwd "$uid" | cut -d: -f1)
    local history=$(last "$name" | grep pts/ | grep -v tmux | awk 'BEGIN{ cnt = 0; print "DATE\t\tTIME\tIP" }{ if (cnt < 10) { print $4 " " $5 " " $6 "\t" $7 "\t" $3; cnt++; } }')
    echo "$history"

    dialog  --title "Login History" \
            --no-collapse \
            --extra-button \
            --extra-label "EXPORT" \
            --msgbox "$history" \
            20 80

    local choice=$?
    if [ "$choice" = 0 ] ; then
        UserAction "$uid"
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        local TMPFILE=$(mktemp tmp.XXXXXX)
        dialog  --title "Export to file" \
                --inputbox "Enter the path:" \
                15 40 \
                2>"$TMPFILE"
        choice=$?
        if [ "$choice" = 0 ] ; then
            local dest=$(cat "$TMPFILE")
            local homedir=$(eval echo ~${SUDO_USER})
            dest=$(echo "$dest" | awk -v homedir="$homedir" '{ 
                                                            if ($0 ~ /^\~/) { 
                                                                line = $0; 
                                                                line = homedir substr(line, 2); 
                                                                print line; 
                                                            } else { 
                                                                if ($0 ~ /^\//) {
                                                                    print $0; 
                                                                } else {
                                                                    line = $0; 
                                                                    line = homedir "/" line; 
                                                                    print line; 
                                                                }
                                                            }
                                                        }')
            echo "$history" > "$dest"
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        UserAction "$uid"
        rm "$TMPFILE"
    fi
}

SudoLog() {
    local month=$(date | cut -d" " -f2)
    local day=$(date | cut -d" " -f3)
    local uid=$1
    local name=$(getent passwd "$uid" | cut -d: -f1)
    local logs=$(cat /var/log/auth.log | grep sudo | awk -v name="$name" -v month="$month" -v day="$day" 'BEGIN{
                                            Month["Jan"] = 1;
                                            Month["Feb"] = 2;
                                            Month["Mar"] = 3;
                                            Month["Apr"] = 4;
                                            Month["May"] = 5;
                                            Month["Jun"] = 6;
                                            Month["Jul"] = 7;
                                            Month["Aug"] = 8;
                                            Month["Sep"] = 9;
                                            Month["Oct"] = 10;
                                            Month["Nov"] = 11;
                                            Month["Dec"] = 12;
                                        }
                                        ($6 == name){
                                            status = 0;
                                            curmonth = Month[month];
                                            if(month == $1 || ((curmonth == 1 && Month[$1] == 12) || ((curmonth - 1) == Month[$1] && ($2 + 0 >= day + 0)))) {
                                                user = $6;
                                                sentence = "";
                                                command = "";
                                                foundCommand = 0;
                                                sentence = user " used sudo to do \`";
                                                for(i = 1; i <= NF; i++) {
                                                    if (foundCommand == 0) {
                                                        if ($i ~ /^COMMAND/) {
                                                            foundCommand = 1;
                                                            command = substr($i, 9);
                                                            sentence = sentence command;
                                                        }
                                                    }
                                                    else {
                                                        sentence = sentence " " $i;
                                                    }
                                                }
                                                if (foundCommand == 0) {
                                                    next;
                                                }
                                                sentence = sentence "\` on " $1 " " $2 " " $3;
                                                printf("%s\n", sentence);
                                            }
                                        }')

    dialog  --title "Sudo Log" \
            --no-collapse \
            --extra-button \
            --extra-label "EXPORT" \
            --msgbox "$logs" \
            20 80
    
    local choice=$?
    if [ "$choice" = 0 ] ; then
        UserAction "$uid"
    elif [ "$choice" = 255 ] ; then
        DeleteTMPFILEs
        echo "Esc pressed." >&2
        exit 1
    else
        local TMPFILE=$(mktemp tmp.XXXXXX)
        dialog  --title "Export to file" \
                --inputbox "Enter the path:" \
                15 40 \
                2>"$TMPFILE"
        choice=$?
        if [ "$choice" = 0 ] ; then
            local dest=$(cat "$TMPFILE")
            local homedir=$(eval echo ~${SUDO_USER})
            dest=$(echo "$dest" | awk -v homedir="$homedir" '{ 
                                                            if ($0 ~ /^\~/) { 
                                                                line = $0; 
                                                                line = homedir substr(line, 2); 
                                                                print line; 
                                                            } else { 
                                                                if ($0 ~ /^\//) {
                                                                    print $0; 
                                                                } else {
                                                                    line = $0; 
                                                                    line = homedir "/" line; 
                                                                    print line; 
                                                                }
                                                            }
                                                        }')
            echo "$logs" > "$dest"
        elif [ "$choice" = 255 ] ; then
            DeleteTMPFILEs
            echo "Esc pressed." >&2
            exit 1
        fi
        UserAction "$uid"
        rm "$TMPFILE"
    fi
}

DeleteTMPFILEs() {
    files=$(ls | grep 'tmp\.......' | awk '{ printf("%s ", $0 )}')

    for i in $files ; do
        rm "$i"
    done
}

trap "DeleteTMPFILEs; echo \"Ctrl + C pressed\"; exit 2" INT

if [ $(whoami) = root ]; then
    EntrancePage 
    echo "Exit."
else 
    echo "This script must be run as root" 
    exit 1
fi