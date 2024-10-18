# Backup-Real-Matters

备份真正重要的东西

## Intro

What are **real matters** that worth us to backup carefully?
- Recently modified: The work at hand is more important, old files may no longer be used.
- Modified after created: Your creation is the most important thing and creation means modified more than once by yourself. The files that have not been modified probably was downloaded from the internet which are easy to get back.

So this bash script will use `find` to get a list of recently modified & unbacked files and filter out files with the same birth date and modification date. Then, use `scp` to copy files to remote server through SSH and renamed with a date prefix.

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

## TODO
- [ ] Only keep the most recent N versions of each file on the server
- [ ] Remove files that are too old

Welcome for PR