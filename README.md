Percona-Server-5.1
==================

# DISCONTINUED PROJECT
Percona-Server-5.1 cloned from Percona Bazaar
This project was created to help me learn Jenkins, and I did not like Bazaar (so, so slow) so I put it into Github.
I have a job pull from Bazaar, make sure my stuff is there and put it here into Github.
I was planning on packaging my own debs so I could inject custom things into the package, but now I've changed my mind and am just going to use Percona's official Ubuntu packages, and inject via a separate package that re-owns the config files with dpkg divert.
http://www.percona.com/doc/percona-server/5.5/installation/apt_repo.html

#I install with this run in the shell


gpg --keyserver  hkp://keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
gpg -a --export CD2EFD2A | sudo apt-key add -

if [ ! -f /etc/apt/sources.list.d/percona.list ]
 then
    echo "deb http://repo.percona.com/apt $(grep DISTRIB_CODENAME /etc/lsb-release | sed 's/=/ /' | awk '{ print $2 }') main" | sudo tee /etc/apt/sources.list.d/percona.list
    echo "deb-src http://repo.percona.com/apt $(grep DISTRIB_CODENAME /etc/lsb-release | sed 's/=/ /' | awk '{ print $2 }') main" | sudo tee -a /etc/apt/sources.list.d/percona.list
else
    echo "Percona sources exist, $(cat /etc/apt/sources.list.d/percona.list)"
fi
#Sometimes it doesn't configure right, so you have to just rerun that line
apt-get update

#Percona SERVER
apt-get install mailutils percona-server-client-5.1 libmysqlclient18 percona-server-server-5.1 libdbd-mysql-perl postfix mailutils
touch /var/log/{btmp,lastlog,wtmp}

#Percona CLIENT
apt-get install mailutils percona-server-client-5.1 libmysqlclient16 libdbd-mysql-perl postfix




