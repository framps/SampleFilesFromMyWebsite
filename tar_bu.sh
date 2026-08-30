umask 077
logger -t BACKUP "Gateway backup started on `date +%D` at `date +%T`" 
#echo -e "*** Gateway backup started on `date +%D` at `date +%T` ***\c" | wall
echo -e "Subject: Gateway backup started on `date +%D` at `date +%T`" | sendmail root
D=`date +%y%m%d`   
LOG="/var/log/backup/${D}.log"
mount /disks/hdb2 2>&1 >>$LOG
cd /backup 2>&1 >>$LOG
# v: verbose
# z: gzip
# p: preserve permission
## l: do not archive from other filesystems
# f: store in filename
# tar -X /usr/local/etc/bu_exclude.files -cvzpf ${D}.tar.gz / 2>&1 >> $LOG
tar -X /usr/local/etc/bu_exclude.files -cvzpf ${D}.tar.gz --one-file-system --atime-preserve / > /dev/nul
rc=$?
echo -e "*** Gateway backup finished on `date +%D` at `date +%T` with exit status $rc ***\c\c\c"| wall
logger -t BACKUP "Gateway backup finished on `date +%D` at `date +%T` with exit status $rc" 2>&1 >> $LOG
echo -e "Subject: Gateway backup finished on `date +%D` at `date +%T` with exit status $rc" | sendmail root
cd / 2>&1  >>$LOG
umount /disks/hdb2 2>&1 >>$LOG
