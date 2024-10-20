#!/usr/bin/env bash

set -e

echo "Welcome to Backup-Real-Matters"

source configure.sh

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -h, --help      Display this help message"
    echo " -b, --batch     Enable batch mode, no ask for user"
    echo " -n, --notify    Use notify-send to send notifications"
}

error_ext(){
    echo "${ECHO_ERRO} $1"
    if $notify; then
        notify-send -u critical "Backup Fail" \
            "Backup fail at $(date '+%Y-%m-%d %H:%M'), \
            reason: $1"
    fi
    exit 1
}

batch_mode=false
notify=false
handle_options() {
  while [ $# -gt 0 ]; do
    case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        -b | --batch)
            batch_mode=true
            echo "batch mode: ON"
            ;;
        -n | --notify)
            notify=true
            echo "notify: ON"
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
  done
}

# Main script execution
handle_options "$@"

if ! $batch_mode; then
    ECHO_WARN="\033[43m[WARM]\033[0m"
    ECHO_ERRO="\033[41m[ERRO]\033[0m"
    COL_INFO=`tput setaf 2;`
    COL_ERRO=`tput setaf 1;`
    COL_WARN=`tput setaf 3;`
    COL_END=`tput sgr0`
else
    ECHO_WARN="[WARM]"
    ECHO_ERRO="[ERRO]"
    COL_INFO=""
    COL_ERRO=""
    COL_WARN=""
    COL_END=""
fi


# STEP 0

echo "step 0: reading from configure..."
if [ ! -f "server.conf" ]; then
    error_ext "The file ./server.conf does not exist."
fi
server="$(<"server.conf")"
if [ ! -f "dirs.conf" ]; then
    error_ext "The file ./dirs.conf does not exist."
fi
if [ ! -f "ignores.conf" ]; then
    echo "${ECHO_WARN} The file ignores.conf does not exist, create new."
    touch "ignores.conf"
fi
lasttime=$(date -d "${FIRST_BACKUP}" '+%Y-%m-%d %H:%M')
if [ -f "lasttime.conf" ]; then
    lasttime=$(cat "lasttime.conf")
    echo "Last backup time: $lasttime"
else
    echo "${ECHO_WARN} First-time backup, consider files that have been modified within the last week"
fi

declare -a dirs
while IFS= read -r dir; do
    dirs+=("$dir")
done < <(grep -vE '^(\s*$|#)' "dirs.conf")

find_not_params=()
while IFS= read -r ignore; do
    find_not_params+=(-path "$ignore" -o)
done < <(grep -vE '^(\s*$|#)' "ignores.conf")

# STEP 1

echo "step 1: finding recently modified UNBACKED IMPORTANT file..."
declare -a files
declare -i files_size_tot
files_size_tot=0
for i in "${!dirs[@]}"; do
    echo "[$((i+1))/${#dirs[*]}] Find in ${dirs[i]}:"
    if [ -d "${dirs[i]}" ]; then
    # set -x
        while IFS= read -r -d '' file; do
            mod_time=$(stat -c "%Y" "$file")
            birth_time=$(stat -c "%W" "$file")
            if [ $((mod_time - birth_time)) -gt 2 ]; then
                files+=("$file")
                file_size=$(stat -c%s "$file")
                files_size_tot=$((file_size+files_size_tot))
                echo "$file $(numfmt --to=iec-i $file_size)"
            else
                echo "$file ${COL_WARN}presumed unimportant, skipped${COL_END}"
            fi
        done < <(find "${dirs[i]}" -type f -not \
            \(\
            "${find_not_params[@]}" \
            -path '*/\.*' \
            \)\
            -newermt "$lasttime"\
            -print0)
    # set +x
    else
        echo "${ECHO_WARN} ${dirs[i]} does not exist."
    fi
done

backup_size=$(numfmt --to=iec-i $files_size_tot)

if ! $batch_mode; then
    read -p "Total size of files to backup: ${COL_INFO}${backup_size}${COL_END}, continue to backup?(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    fi
fi

# STEP 2

echo "step 2: transferring files to remote server..."
dir_backup_remote="\"\$HOME/$DIR_BACKUP\""
tar czf - "${files[@]}" --atime-preserve --transform "s,.*/,&$(date '+%Y%m%d-%H%M-')," | ssh $server "tar xzf - -C "$dir_backup_remote""
if [ $? -ne 0 ]; then
    error_ext "transferring fail."
fi

date '+%Y-%m-%d %H:%M' > "lasttime.conf"

# STEP 3

echo "step 3: check remote server backups..."
remote_size=$(ssh $server "du -sh $dir_backup_remote" | awk '{print $1}')
if ! $batch_mode; then
    read -p "Total size of files on remote server: ${COL_INFO}$remote_size${COL_END}, continue to clean up redundant backups?(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    fi
fi

# STEP 4

echo "step 4: running remote server cleaner..."

if ! scp -C -p -B "./remote_cleaner.sh" "./configure.sh" \
        $server:$dir_backup_remote; then
    error_ext "transferring cleaner scripts fail."
fi
if ! ssh $server "cd $dir_backup_remote && \
    chmod +x remote_cleaner.sh && \
    ./remote_cleaner.sh"; then
    error_ext "cleaner script run fail."
fi

echo "Done."

if $notify; then
    notify-send -u normal "Backup-Real-Matters Done" \
    "Backup total size of backups: $backup_size, remote storage usage: $remote_size, done at $(date '+%Y-%m-%d %H:%M')"
fi

