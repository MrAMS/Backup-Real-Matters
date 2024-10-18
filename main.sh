#!/usr/bin/env bash

set -e

echo "Welcome to Backup-Real-Matters"

# STEP 0

echo "step 0: reading from configure..."
if [ ! -f "server.conf" ]; then
    echo "[ERRO]The file ./server.conf does not exist."
    touch "server.conf"
    exit 1
fi
server="$(<"server.conf")"
if [ ! -f "dirs.conf" ]; then
    echo "[ERRO]The file ./dirs.conf does not exist."
    touch "dirs.conf"
    exit 1
fi
if [ ! -f "ignores.conf" ]; then
    echo "[WARN]The file ignores.conf does not exist, create new."
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
done < "dirs.conf"

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
                echo "$file presumed unimportant, skipped"
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
        echo "[WARN]${dirs[i]} does not exist."
    fi
done

read -p "Total size of files to backup: $(numfmt --to=iec-i $files_size_tot), continue to backup?(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 0
fi

echo "ok"

# STEP 2

echo "step 2: copying files to remote server..."

for i in "${!files[@]}"; do
    file=${files[i]}
    echo "[$((i+1))/${#files[*]}] Copying $file..."
    dir="\$HOME/.backup-recent$(dirname "$file")"
    ssh $server "mkdir -p \""$dir"\"" && \
    scp -C -p -B "$file" \
        $server:\""$dir/$(date '+%Y%m%d-%H%M')-$(basename "$file")"\"
done

date '+%Y-%m-%d %H:%M' > "lasttime.conf"

echo "Done."


