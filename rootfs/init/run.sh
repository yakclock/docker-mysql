#!/bin/sh
#

HOSTNAME=$(hostname -s)

WORK_DIR=/srv/mysql

MYSQL_DATA_DIR=${WORK_DIR}/data
MYSQL_LOG_DIR=${WORK_DIR}/log
MYSQL_TMP_DIR=${WORK_DIR}/tmp
MYSQL_RUN_DIR=${WORK_DIR}/run
MYSQL_INNODB_DIR=${WORK_DIR}/innodb

MYSQL_SYSTEM_USER=${MYSQL_SYSTEM_USER:-$(grep user /etc/mysql/my.cnf | cut -d '=' -f 2 | sed 's| ||g')}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-$(pwgen -s 15 1)}

MYSQL_OPTS="--batch --skip-column-names "
MYSQL_BIN=$(which mysql)


setSystemUser() {

  local current_user=$(grep user /etc/mysql/my.cnf | cut -d '=' -f 2 | sed 's| ||g')

  if [ "${MYSQL_SYSTEM_USER}" = "${current_user}" ]
  then
    return
  fi

  sed -i \
    -e "s/\(user.*=\).*/\1 ${MYSQL_SYSTEM_USER}/g" \
    /etc/mysql/my.cnf
}


bootstrapDatabase() {

  bootstrap="${WORK_DIR}/bootstrapped"

  sed -i \
    -e "s|%WORK_DIR%|${WORK_DIR}|g" \
    -e "s/\(bind-address.*=\).*/\1 0.0.0.0/g" \
    /etc/mysql/my.cnf

  [ -d ${MYSQL_DATA_DIR} ]        || mkdir -p ${MYSQL_DATA_DIR}
  [ -d ${MYSQL_LOG_DIR} ]         || mkdir -p ${MYSQL_LOG_DIR}
  [ -d ${MYSQL_TMP_DIR} ]         || mkdir -p ${MYSQL_TMP_DIR}
  [ -d ${MYSQL_RUN_DIR} ]         || mkdir -p ${MYSQL_RUN_DIR}
  [ -d ${MYSQL_INNODB_DIR} ]      || mkdir -p ${MYSQL_INNODB_DIR}

  chown -R ${MYSQL_SYSTEM_USER}: ${WORK_DIR}

  if [ ! -f ${bootstrap} ]
  then

    [ -f /root/.my.cnf ] && rm /root/.my.cnf

    mysql_install_db --user=${MYSQL_SYSTEM_USER} > /dev/null
    /usr/bin/mysqld_safe --syslog-tag=init &
    sleep 10s

    (
      echo "USE mysql;"
      echo "UPDATE user SET password = PASSWORD('${MYSQL_ROOT_PASS}') WHERE user = 'root';"
      echo "create user 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASS}';"
      echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
      echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;"
      echo "FLUSH PRIVILEGES;"
    ) | mysql --host=localhost

    sleep 2s

    killall mysqld

    cat << EOF > /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${MYSQL_ROOT_PASS}
socket   = ${MYSQL_RUN_DIR}/mysql.sock

EOF
    touch ${bootstrap}

  fi

}


run() {

  if [ ! -z ${MYSQL_BIN} ]
  then

    setSystemUser

    bootstrapDatabase

    /usr/bin/mysqld \
      --user=${MYSQL_SYSTEM_USER} \
      --userstat \
      --console

  else
    echo " [E] no MySQL binary found!"
    exit 1
  fi
}


run

# EOF
