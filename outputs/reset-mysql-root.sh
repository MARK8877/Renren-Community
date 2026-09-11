#!/bin/bash
# MySQL 8.4.5 Oracle macOS installation only.
# Reference: https://dev.mysql.com/doc/refman/8.4/en/resetting-permissions.html
set -euo pipefail
MYSQL_BASE=/usr/local/mysql
MYSQL_PLIST=/Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
MYSQL_LABEL=com.oracle.oss.mysql.mysqld
if [ "$EUID" -ne 0 ]; then
  echo '请使用 sudo /bin/bash 执行此脚本。'; exit 1
fi
case "$(readlink "$MYSQL_BASE")" in
  mysql-8.4.5-macos15-arm64) ;;
  *) echo 'MySQL 安装路径与已检查的 8.4.5 实例不一致，已停止。'; exit 1 ;;
esac
[ -f "$MYSQL_PLIST" ] && [ -d "$MYSQL_BASE/data/mysql" ] || {
  echo '没有找到现有服务或数据库，已停止。'; exit 1;
}
echo '将短暂停止本机 MySQL，并重置 root@localhost 密码。保留所有现有数据库。'
echo '新密码要求：12–72 位，可使用字母、数字以及 ! @ # % _ + = . -'
read -r -s -p '输入新的 MySQL root 密码: ' reset_password
echo
read -r -s -p '再次输入新密码: ' reset_confirmation
echo
if [ "$reset_password" != "$reset_confirmation" ] ||
   [ "${#reset_password}" -lt 12 ] || [ "${#reset_password}" -gt 72 ] ||
   [[ "$reset_password" == *[!a-zA-Z0-9!@#%_+=.-]* ]]; then
  echo '密码不一致或不符合要求，未修改数据库。'; exit 1
fi
unset reset_confirmation
reset_dir=$(mktemp -d /private/tmp/creatorhub-mysql-reset.XXXXXX)
chmod 700 "$reset_dir"
chown _mysql:_mysql "$reset_dir"
reset_stopped=0
reset_started=0
cleanup() {
  result=$?
  trap - EXIT
  if [ "$reset_started" -eq 1 ]; then
    if ! "$MYSQL_BASE/bin/mysqladmin" --defaults-file="$reset_dir/client.cnf" shutdown; then
      echo "临时实例未能正常关闭。诊断日志位于 $reset_dir/server.err。"
      echo '请勿再次运行脚本；请提供错误信息以继续处理。'
      rm -f "$reset_dir/init.sql" "$reset_dir/client.cnf"
      exit 1
    fi
  fi
  rm -f "$reset_dir/init.sql" "$reset_dir/client.cnf"
  if [ "$reset_stopped" -eq 1 ]; then
    if ! launchctl bootstrap system "$MYSQL_PLIST"; then
      echo '密码重置流程结束，但正常服务恢复失败，请在系统设置中启动 MySQL。'
      exit 1
    fi
  fi
  if [ "$result" -ne 0 ]; then
    echo "重置未验证成功。诊断日志（不含密码）: $reset_dir/server.err"
  fi
  exit "$result"
}
trap cleanup EXIT
umask 077
printf "ALTER USER 'root'@'localhost' IDENTIFIED BY '%s';\n" "$reset_password" > "$reset_dir/init.sql"
printf '[client]\nuser=root\npassword="%s"\nprotocol=SOCKET\nsocket=%s/mysql.sock\n' "$reset_password" "$reset_dir" > "$reset_dir/client.cnf"
chown _mysql:_mysql "$reset_dir/init.sql"
unset reset_password
launchctl bootout "system/$MYSQL_LABEL"
reset_stopped=1
# Wait for the original server to finish its normal shutdown.
for ((i=0; i<120; i++)); do
  if [ ! -f "$MYSQL_BASE/data/mysqld.local.pid" ]; then break; fi
  sleep 1
done
if [ -f "$MYSQL_BASE/data/mysqld.local.pid" ]; then
  echo '原实例未完成停止，未启动第二个实例。'; exit 1
fi
"$MYSQL_BASE/bin/mysqld" --basedir="$MYSQL_BASE" \
  --datadir="$MYSQL_BASE/data" --plugin-dir="$MYSQL_BASE/lib/plugin" \
  --user=_mysql --skip-networking --mysqlx=OFF \
  --socket="$reset_dir/mysql.sock" --pid-file="$reset_dir/server.pid" \
  --log-error="$reset_dir/server.err" --init-file="$reset_dir/init.sql" --daemonize
reset_started=1
"$MYSQL_BASE/bin/mysql" --defaults-file="$reset_dir/client.cnf" \
  -e 'SELECT CURRENT_USER() AS account, VERSION() AS version;'
echo '新密码验证成功。正在关闭临时实例并恢复正常 MySQL 服务。'
# EXIT cleanup shuts down the temporary server, removes secret files, then restores launchd.
