#!/usr/bin/env bash

set -e

echo "Welcome to Backup-Real-Matters Remote Cleanner"

source configure.sh

declare -a dirs
while IFS= read -r -d '' dir; do
    dirs+=("$dir")
done < <(find "$HOME/$DIR_BACKUP" -type d -print0)

for i in "${!dirs[@]}"; do
    echo "[$((i+1))/${#dirs[*]}] Find in ${dirs[i]}:"
    unset files
    declare -A files
    unset keep_num
    declare -i keep_num
    keep_num=KEEP_SAME_MAX
    while IFS= read -r -d '' file; do
        if [ $(($(date -d "$KEEP_ONE_TIME" +%s) - $(stat -c %Y "$file"))) -gt 0 ]; then
            keep_num=1
        fi
        name=$(echo "$(basename "$file")" | cut -d'-' -f3-) # get text after the second '-', 20241018-2022-Hello.txt
        files["$name"]+="$file,"
    done < <(find ${dirs[i]} -maxdepth 1 -type f -print0)
    for key in "${!files[@]}"; do
        unset files_sorted_1group
        declare -a files_sorted_1group
        unset files_rm
        declare -a files_rm
        IFS=',' read -r -a files_sorted_1group <<< "${files["$key"]}"
        files_sorted_1group=($(printf "%s\n" "${files_sorted_1group[@]}" | sort -r))
        files_rm=("${files_sorted_1group[@]:keep_num}")
        if [ ${#files_rm[@]} -gt 0 ]; then
            echo "[WARN] rm ${files_rm[@]}"
            rm "${files_rm[@]}"
        fi
    done
done

echo "$(date '+%Y-%m-%d %H:%M') -> $(du -sh "$HOME/$DIR_BACKUP" | awk '{print $1}')" >> "cleaner.log"
