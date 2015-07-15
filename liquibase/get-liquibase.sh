#!/usr/bin/env bash
connector_name=mysql-connector-java-5.1.35
if [ ! -d liquibase ]; then
    #create liquibase dir
    mkdir liquibase
    #get the liquibase tarball
    wget https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.3.5/liquibase-3.3.5-bin.tar.gz
    tar xvfz liquibase-3.3.5-bin.tar.gz -C liquibase
    #get the DB driver tar
    wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.35.tar.gz
    tar xvfz "${connector_name}.tar.gz" -C liquibase
    #move the jar to liquibase dir
    mv "liquibase/${connector_name}/${connector_name}-bin.jar" liquibase/
    #cleanup
    rm -Rf "liquibase/${connector_name}"
    rm liquibase*.tar.gz
    rm mysql-connector*.tar.gz
    # copy config script
    mv setup.ph liquibase/
    cd liquibase/
    ./setup.pl
    # If setup was successful, procede, else exit with error code
    if [[ $? == 0 ]]; then
        source ~/.bashrc
        sudo cp liquibase /usr/bin/
    else
        exit $?
    fi
fi
exit 0
