# Backup-Real-Matters

*Backup the most valuable content at the least cost*

以最低成本备份重要的东西：自动备份**最近修改且创建和修改日期不同的文件**到远程服务器，每个文件仅保留最近的5个版本，修改时间在一周之前的文件仅保留最新的一个版本，以优化存储。

## Intro

Most of the time, we use `rsync` or `yadm` to back up specific folders. However, we need to continuously update the folder and ignore list and end up paying for cold data that may no longer be needed.

Which are **real matters** that worth us to backup carefully?
- Recently modified: Current work takes priority, as older files may no longer be relevant.
- Modified after created: Your original creations matter most, and if a file has been modified multiple times, it likely holds value. Files that haven't been altered since creation were probably downloaded and can easily be retrieved again if needed.

This bash script leverages the `find` command to generate a list of recently modified and unbacked files, filtering out those with identical creation and modification dates. It then uses `scp` to transfer these files to a remote server over SSH, adding a date prefix to the filenames. Additionally, the script deletes redundant or outdated backups to optimize server storage and minimize usage.

## Usage

```bash
$ chmod +x ./main.sh
$ ./main.sh
```

You should get a warning on first run, you need to create some files.

File `dirs.conf` which contains all the folders that need to be scanned.
```conf
/home/xxx/proj/
/home/xxx/Documents/

```
File `server.conf` which contain your remote server. You should configure key-based authentication for SSH before.
```conf
root@www.example.com
```

File `ignores.conf` which contain ignore patterns. You can use `#` as a line comment.
```conf
*/node_modules/*
*.torrent
# */toolchain/*
```

Note that all backed up files are stored in the path `$HOME/.backup-recent` on the remote server.

### Run daily

Also, you can use `crontab` to run script daily.

```bash
$ dirname "$(readlink -f ./main.sh)" # get the absolute path
$ crontab -e
```
Paste the following and remember to change the `/the/absolute/path/of/script/directory` path below.
```bash
@daily (cd /home/santiego/proj/scripts/backup-recent && export TERM=xterm-256color && BASH_ENV=~/.bashrc bash -l ./main.sh -b) 1> /dev/null 2> /tmp/backup-recent.error
```

## TODO
- [x] Keep only the most recent 5 versions of each file modified within the last week on the server
- [x] Keep only one version of each file that hasn’t been modified in the past week.
- [ ] TUI for user to browse all backedup files
- [ ] Delete files that are too old.

Pull requests are welcome.