#!/usr/bin/env bash

set -e

ECHO_WARN="\033[43m[WARM]\033[0m"
ECHO_ERRO="\033[41m[ERRO]\033[0m"
COL_INFO=`tput setaf 2;`
COL_ERRO=`tput setab 1;tput setaf 7;`
COL_WARN=`tput setab 3;tput setaf 7;`
COL_END=`tput sgr0`

echo "Welcome to Backup-Real-Matters"

usage() {
 echo "Usage: $0 [OPTIONS]"
 echo "Options:"
 echo " -h, --help      Display this help message"
 echo " -b, --batch     Enable batch mode, no ask for user"
}

batch_mode=false
handle_options() {
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -b | --batch)
        batch_mode=true
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

DIR_BACKUP=".backup-recent"

# STEP 0

echo "step 0: reading from configure..."
if [ ! -f "server.conf" ]; then
    echo "[ERRO]The file ./server.conf does not exist."
    touch "server.conf"
    exit 1
fi
server="$(<"server.conf")"
if [ ! -f "dirs.conf" ]; then
    echo "[ERRO] The file ./dirs.conf does not exist."
    touch "dirs.conf"
    exit 1
fi
if [ ! -f "ignores.conf" ]; then
    echo "$ECHO_WARN The file ignores.conf does not exist, create new."
    touch "ignores.conf"
fi
lasttime=$(date -d "1 week ago" '+%Y-%m-%d %H:%M')
if [ -f "lasttime.conf" ]; then
    lasttime=$(cat "lasttime.conf")
    echo "Last backup time: $lasttime"
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
                echo "$file ${COL_YEL}presumed unimportant, skipped${COL_END}"
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
        echo "$ECHO_WARN ${dirs[i]} does not exist."
    fi
done

if ! $batch_mode; then
    read -p "Total size of files to backup: ${COL_INFO}$(numfmt --to=iec-i $files_size_tot)${COL_END}, continue to backup?(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    fi
fi

# STEP 2

echo "step 2: copying files to remote server..."

for i in "${!files[@]}"; do
    file=${files[i]}
    echo "[$((i+1))/${#files[*]}] Copying $file..."
    dir="\$HOME/$DIR_BACKUP$(dirname "$file")"
    ssh $server "mkdir -p \""$dir"\"" && \
    scp -C -p -B "$file" \
        $server:\""$dir/$(date '+%Y%m%d-%H%M')-$(basename "$file")"\"
done

date '+%Y-%m-%d %H:%M' > "lasttime.conf"

# STEP 3

echo "step 3: check remote server backups..."
remote_size=$(ssh $server "du -sh \$HOME/'$DIR_BACKUP'" | awk '{print $1}')
if ! $batch_mode; then
    read -p "Total size of files on remote server: ${COL_INFO}$remote_size${COL_END}, continue to clean up redundant backups?(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    fi
fi

# STEP 4

echo "step 4: running remote server cleanner..."

remote_script_path="\"\$HOME/$DIR_BACKUP/remote_cleanner.sh\""
scp -C -p -B "./remote_cleanner.sh" \
        $server:$remote_script_path && \
ssh $server "chmod +x $remote_script_path && $remote_script_path"

echo "Done."

