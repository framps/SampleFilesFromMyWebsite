MYSELF=`basename $0`
#set -o xtrace
#set -o verbose
bufile=${1:?${MYSELF}: Missing backup file name}
F=$1
if [[ ! -e $F ]]; then
	echo "${MYSELF}: File $F not found"
	exit 1
fi
mount /linux2
cd /linux2
rm -Rf /linux2
tar -xvzpf $F --atime-preserve
# remember backup date
echo `date` > /linux2/backupDate
# now switch backup partition and root partition in fstab
sed 's/\/dev\/hdb1/\/dev\/hdaX/' /etc/fstab | sed 's/\/dev\/hda1/\/dev\/hdb1/' | sed 's/\/dev\/hdaX/\/dev\/hda1/' > /linux2/etc/fstab 
umount /linux2
