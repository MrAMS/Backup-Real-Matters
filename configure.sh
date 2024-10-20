# Configurable
# Note that configuration on the remote will be overwritten

readonly DIR_BACKUP=".backup-recent" # backups locate at $HOME/$DIR_BACKUP on remote server
readonly FIRST_BACKUP="1 week ago" # range of files for the first-time backup

readonly KEEP_SAME_MAX=5 #  Keep the most recent $KEEP_SAME_MAX versions of each file
readonly KEEP_ONE_TIME="1 week ago" #  Keep only one version of each file that hasn’t been modified in $KEEP_ONE_TIME.
