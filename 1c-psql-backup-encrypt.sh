pg_dump -h localhost -U postgres -d kivork -F c -b -v -f kivork_bk.backup
tar -cvzf kivork_bk.tar.gz -C /home/clay/
gpg --encrypt -r vladimir@kiv.md --no-tty --trust-model always $BK_DATA_TO_ENCRYPT >$BK_DATA_TO_ENCRYPT.gpg