@rem ####################################################
@rem # Simple command sequence to create a xbmc config backup
@rem # 02/16/2013 framp at linux-tips-and-tricks dot de
@rem ####################################################
@echo off
@rem
@rem ===> START adapt the following parms for your environment
@rem
set PASSWORD="raspberry"
set USERID="pi"
set PI="192.168.0.102"
set BACKUP_FILENAME="backup.tar.gz"
@rem
@rem ===> STOP adapt the following parms for your environment
@rem
echo "Stopping xbmc"
plink -pw %PASSWORD% %USERID%@%PI% sudo /sbin/initctl stop xbmc
echo "Creating backup on PI"
plink -pw %PASSWORD% %USERID%@%PI% tar -cvzf %BACKUP_FILENAME% .xbmc/
echo "Starting xbmc"
plink -pw %PASSWORD% %USERID%@%PI% sudo /sbin/initctl start xbmc
echo "Downloading backup file to current directory"
pscp -pw %PASSWORD% %USERID%@%PI%:/home/pi/%BACKUP_FILENAME% .
echo "Removing backup from PI"
plink -pw %PASSWORD% %USERID%@%PI% rm %BACKUP_FILENAME%
