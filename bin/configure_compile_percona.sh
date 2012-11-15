#!/bin/bash

if [ "${1}" ]
then
    BUILD_DIR="${1}"
else
    BUILD_DIR="${HOME}/${JOB_NAME}"
fi

if [ ! -d "${BUILD_DIR}" ]
     then
         mkdir -p ${BUILD_DIR}
         cd ${BUILD_DIR}
         git clone git://github.com/jonzobrist/Percona-Server-5.1.git
         cd Percona-Server-5.1/Percona-Server/
         echo "Running $(which autoreconf) at $(date)"
         autoreconf -i
         echo "Configuring for build at $(date)"
         #This was my old/original mysql configure command, but it is currently causing things to fail in compile time, so I'm shortening it
         #./configure -prefix=/usr -enable-local-infile -enable-thread-safe-client -enable-assembler -with-client-ldflags=-all-static -with-mysqld-ldflags=-all-static -with-unix-socket-path=/var/run/mysqld/mysqld.sock -with-plugins=partition,archive,blackhole,csv,federated,heap,innodb_plugin,myisam,myisammrg -with-big-tables -without-debug -with-tcp-port=3306 -with-readline -enable-profiling -disable-shared -enable-static -with-extra-charsets=complex -with-pic -with-fast-mutexes -with-zlib-dir=bundled -with-ssl
         ./configure --prefix=/usr --enable-local-infile --with-plugins=partition,archive,blackhole,csv,federated,heap,innodb_plugin,myisam,myisammrg --with-big-tables --without-debug --with-readline --with-pic --with-fast-mutexes --with-zlib-dir=bundled --with-ssl

         echo "Compiling began at $(date)"
         make
         echo "Compiling done at $(date), Making install, creating deb file"
         #sudo checkinstall make install
         checkinstall --pkgname="inthinc-percona-server-5.1" --pkgversion="5.1" --maintainer="root@inthinc.com" --provides="5.1.66-inthinc.1-495.precise - mysql-server-core-5.1 mysql-server-core mysql-server-5.1 mysql-server" --requires="5.1.66-inthinc.1-495.precise - inthinc-percona-server-client-5.1 (2 5.1.66-inthinc.1-495.precise) libdbi-perl (0 (null)) perl (2 5.6) libc6 (2 2.14) libmysqlclient16 (2 5.1.21-1) libstdc++6 (2 4.6) libwrap0 (2 7.6-4~) zlib1g (2 1:1.2.0) debconf (18 0.5) debconf-2.0 (0 (null)) psmisc (0 (null)) passwd (0 (null)) lsb-base (2 3.0-10) inthinc-percona-server-common-5.1 (2 5.1.66-inthinc.1-495.precise) adduser (2 3.40) debconf (0 (null)) tinyca (0 (null)) mailx (0 (null)) libhtml-template-perl (0 (null)) mysql-server (3 5.1.66-inthinc.1-495.precise) mysql-server:i386 (3 5.1.66-inthinc.1-495.precise) mysql-server-4.1 (0 (null)) mysql-server-4.1:i386 (0 (null)) mysql-server-5.1 (0 (null)) mysql-server-5.1:i386 (0 (null)) mysql-server-5.5 (0 (null)) mysql-server-5.5:i386 (0 (null)) mysql-server-core-5.1 (0 (null)) mysql-server-core-5.1:i386 (0 (null)) mysql-server-core-5.5 (0 (null)) mysql-server-core-5.5:i386 (0 (null)) percona-xtradb-server-5.0 (0 (null)) percona-xtradb-server-5.0:i386 (0 (null)) mysql-server (3 5.1.66-inthinc.1-495.precise) mysql-server:i386 (3 5.1.66-inthinc.1-495.precise) mysql-server-5.0 (0 (null)) mysql-server-5.0:i386 (0 (null)) mysql-server-5.1 (0 (null)) mysql-server-5.1:i386 (0 (null)) mysql-server-core-5.1 (0 (null)) mysql-server-core-5.1:i386 (0 (null)) percona-xtradb-server-5.0 (0 (null)) percona-xtradb-server-5.0:i386 (0 (null))" --conflicts="mysql-server (<< 5.1.66-inthinc.1-495.precise), mysql-server-4.1, mysql-server-5.1, mysql-server-5.5, mysql-server-core-5.1, mysql-server-core-5.5, percona-xtradb-server-5.0" --replaces="mysql-server (<< 5.1.66-inthinc.1-495.precise), mysql-server-5.0, mysql-server-5.1, mysql-server-core-5.1, percona-xtradb-server-5.0" --provides="mysql-server, mysql-server-5.1, mysql-server-core, mysql-server-core-5.1" --pkgarch="amd64" --pkgrelease="database" -y make install 

         echo "Done creating deb file at $(date)"
         ls -l *deb
         #git add *deb
         #git commit -m "Deb packages ${BUILD_TAG} $(date) By Jenkins"
         #git push origin master

