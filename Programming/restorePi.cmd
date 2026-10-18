@rem ####################################################
@rem # Simple command sequence to restore a xbmc config
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
@rem ===> END adapt the following parms for your environment
@rem
echo "Uploading backup file to PI"
pscp -pw %PASSWORD% %BACKUP_FILENAME% %USERID%@%PI%:/home/pi/%BACKUP_FILENAME%
echo "Stoping xbmc"
plink -pw %PASSWORD% %USERID%@%PI% sudo /sbin/initctl stop xbmc
echo "Saving old config on PI"
plink -pw %PASSWORD% %USERID%@%PI% mv .xbmc .xbmc_old
echo "Restoring backup on PI"
plink -pw %PASSWORD% %USERID%@%PI% tar -xvzf %BACKUP_FILENAME% 
echo "Starting xbmc"
plink -pw %PASSWORD% %USERID%@%PI% sudo /sbin/initctl start xbmc
echo "Removing backup file from PI"
plink -pw %PASSWORD% %USERID%@%PI% rm %BACKUP_FILENAME%
