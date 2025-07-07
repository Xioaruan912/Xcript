#!/bin/bash

# ----------------------
# 自动备份脚本（支持上传到 OneDrive）
# 备份内容：Vaultwarden、XBoard、XPay、Nginx 配置、MongoDB、哪吒监控、自身脚本
# ----------------------

# === 一、日期与目录配置 ===

DATE=$(date +'%Y-%m-%d')                        # 当前日期（用于目录命名）
BASE_BACKUP_DIR="/root/backup/backup"          # 本地基础备份目录
BACKUP_DIR="$BASE_BACKUP_DIR/$DATE"            # 每日备份子目录

# === 二、需要备份的路径 ===

Vaultwarden_DATA_DIR="/root/Vaultwarden/data"         # Vaultwarden 数据目录
XBOARD_DIR="/root/Xboard/.docker/.data"               # XBoard 持久化数据目录
XPAY_DATA="/root/XPay/database.db"                    # XPay 数据库存储文件
NGINX_CONF_DIR="/etc/nginx"                           # Nginx 配置目录
NEZHA_DIR="/opt/nezha"                                # 哪吒监控目录
SCRIPT_PATH="/root/backup/backup.sh"                  # 本脚本路径

# === 三、备份文件名设定 ===

FILENAME_VAULT="vaultwarden-backup-$DATE.tar.gz"      # Vaultwarden 备份文件名
FILENAME_XBOARD="xboard-backup-$DATE.tar.gz"          # XBoard 备份文件名
FILENAME_NGINX="nginx-backup-$DATE.tar.gz"            # Nginx 配置备份文件名
FILENAME_MONGO="mongodb-backup-$DATE.tar.gz"          # MongoDB 压缩文件名
FILENAME_XPAY="xpay-backup-$DATE.tar.gz"              # XPay 数据库备份文件名
FILENAME_NEZHA="nezha-backup-$DATE.tar.gz"            # 哪吒监控备份文件名
FILENAME_SCRIPT="backup-script-$DATE.sh"              # 当前脚本备份文件名

# === 四、MongoDB 备份配置 ===

MONGO_BACKUP_DIR="/root/backup/mongo_backup_$DATE"    # 临时 MongoDB 输出路径
MONGO_HOST="2222228"                              # MongoDB 地址
MONGO_PORT="27017"                                    # 端口
MONGO_USER="2222222"                                 # 用户名
MONGO_PASS="2222222"                                # 密码
MONGO_AUTH_DB="admin"                                 # 认证库

# === 五、远程上传配置 ===

RCLONE_REMOTE="myonedrive:backup"                     # rclone 配置的 OneDrive 路径

# === 六、创建每日备份目录 ===

mkdir -p "$BACKUP_DIR"

# === 七、开始备份 ===

## 1. Vaultwarden 数据压缩
echo "[*] 备份 Vaultwarden..."
tar -czf "$BACKUP_DIR/$FILENAME_VAULT" -C "$Vaultwarden_DATA_DIR" .
[ $? -ne 0 ] && echo "[!] Vaultwarden 失败" && exit 1

## 2. XBoard 数据压缩
echo "[*] 备份 XBoard..."
tar -czf "$BACKUP_DIR/$FILENAME_XBOARD" -C "$XBOARD_DIR" .
[ $? -ne 0 ] && echo "[!] XBoard 失败" && exit 1

## 3. Nginx 配置文件打包（包括主配置文件和 cert 目录）
echo "[*] 备份 Nginx..."
tar -czf "$BACKUP_DIR/$FILENAME_NGINX" -C "$NGINX_CONF_DIR" nginx.conf cert/
[ $? -ne 0 ] && echo "[!] Nginx 失败" && exit 1

## 4. MongoDB 数据导出 + 压缩
echo "[*] 备份 MongoDB..."
rm -rf "$MONGO_BACKUP_DIR"
mkdir -p "$MONGO_BACKUP_DIR"

mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" \
  --username "$MONGO_USER" --password "$MONGO_PASS" \
  --authenticationDatabase "$MONGO_AUTH_DB" \
  --out "$MONGO_BACKUP_DIR"
[ $? -ne 0 ] && echo "[!] MongoDB 备份失败" && exit 1

tar -czf "$BACKUP_DIR/$FILENAME_MONGO" -C "$MONGO_BACKUP_DIR" .
[ $? -ne 0 ] && echo "[!] MongoDB 压缩失败" && exit 1
rm -rf "$MONGO_BACKUP_DIR"

## 5. XPay 数据库打包（压缩 sqlite 文件）
echo "[*] 备份 XPay..."
if [ -f "$XPAY_DATA" ]; then
    tar -czf "$BACKUP_DIR/$FILENAME_XPAY" -C "$(dirname "$XPAY_DATA")" "$(basename "$XPAY_DATA")"
    [ $? -ne 0 ] && echo "[!] XPay 压缩失败" && exit 1
else
    echo "[!] 找不到 XPay 数据文件：$XPAY_DATA"
    exit 1
fi

## 6. 哪吒监控目录备份
echo "[*] 备份 哪吒监控..."
if [ -d "$NEZHA_DIR" ]; then
    tar -czf "$BACKUP_DIR/$FILENAME_NEZHA" -C "$(dirname "$NEZHA_DIR")" "$(basename "$NEZHA_DIR")"
    [ $? -ne 0 ] && echo "[!] 哪吒监控压缩失败" && exit 1
else
    echo "[!] 找不到 哪吒监控目录：$NEZHA_DIR"
    exit 1
fi

## 7. 当前脚本自身备份
echo "[*] 备份自身脚本..."
if [ -f "$SCRIPT_PATH" ]; then
    cp "$SCRIPT_PATH" "$BACKUP_DIR/$FILENAME_SCRIPT"
    [ $? -ne 0 ] && echo "[!] 脚本复制失败" && exit 1
else
    echo "[!] 未找到脚本文件：$SCRIPT_PATH"
    exit 1
fi

# === 八、上传备份到 OneDrive ===

echo "[*] 上传备份到 OneDrive..."
rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$DATE" --log-level INFO
[ $? -ne 0 ] && echo "[!] 上传失败" && exit 1
echo "[✓] 上传成功：$DATE 目录"

# === 九、本地清理：删除 7 天前的旧备份目录 ===

echo "[*] 清理本地超过 7 天的旧备份..."
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# === 十、OneDrive 清理：删除 4 天前的旧目录 ===

echo "[*] 清理 OneDrive 上 4 天前的备份..."
FOUR_DAYS_AGO=$(date -d "-4 days" +%Y-%m-%d)
OLD_DIRS=$(rclone lsf "$RCLONE_REMOTE/" --dirs-only)

for dir in $OLD_DIRS; do
    dir_cleaned=$(echo "$dir" | sed 's:/*$::')  # 去掉末尾斜杠
    if [[ "$dir_cleaned" < "$FOUR_DAYS_AGO" ]]; then
        echo "[!] 删除旧远程目录: $dir_cleaned"
        rclone purge "$RCLONE_REMOTE/$dir_cleaned"
    fi
done

# === 十一、结束 ===
echo "[✔] 所有备份任务完成：$DATE"
