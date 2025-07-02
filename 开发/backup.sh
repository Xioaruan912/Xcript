#!/bin/bash

# === 基本配置 ===
DATE=$(date +'%Y-%m-%d')
BASE_BACKUP_DIR="/root/backup/backup"
BACKUP_DIR="$BASE_BACKUP_DIR/$DATE"
Vaultwarden_DATA_DIR="/root/Vaultwarden/data"
XBOARD_DIR="/root/Xboard/.docker/.data"
NGINX_CONF_DIR="/etc/nginx"
MONGO_BACKUP_DIR="/root/backup/mongo_backup_$DATE"

FILENAME_VAULT="vaultwarden-backup-$DATE.tar.gz"
FILENAME_XBOARD="xboard-backup-$DATE.tar.gz"
FILENAME_NGINX="nginx-backup-$DATE.tar.gz"
FILENAME_MONGO="mongodb-backup-$DATE.tar.gz"

RCLONE_REMOTE="myonedrive:backup"  # 配置的远程盘

# === MongoDB 认证配置 ===
MONGO_HOST="IP"
MONGO_PORT="27017"
MONGO_USER="账号"
MONGO_PASS="密码"
MONGO_AUTH_DB="admin"

# === 创建本地备份目录 ===
mkdir -p "$BACKUP_DIR"

# === 1. 备份 Vaultwarden ===
echo "[*] 备份 Vaultwarden..."
tar -czf "$BACKUP_DIR/$FILENAME_VAULT" -C "$Vaultwarden_DATA_DIR" .
[ $? -ne 0 ] && echo "[!] Vaultwarden 失败" && exit 1

# === 2. 备份 XBoard ===
echo "[*] 备份 XBoard..."
tar -czf "$BACKUP_DIR/$FILENAME_XBOARD" -C "$XBOARD_DIR" .
[ $? -ne 0 ] && echo "[!] XBoard 失败" && exit 1

# === 3. 备份 Nginx 配置 ===
echo "[*] 备份 Nginx..."
tar -czf "$BACKUP_DIR/$FILENAME_NGINX" -C "$NGINX_CONF_DIR" nginx.conf cert/
[ $? -ne 0 ] && echo "[!] Nginx 失败" && exit 1

# === 4. 备份 MongoDB ===
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

# === 5. 上传到 OneDrive ===
echo "[*] 上传备份到 OneDrive..."
rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$DATE" --log-level INFO
[ $? -ne 0 ] && echo "[!] 上传失败" && exit 1
echo "[✓] 上传成功：$DATE 目录"

# === 6. 清理本地 7 天前的备份文件夹 ===
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# === 7. 清理 OneDrive 上 4 天前的备份目录 ===
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

# === 8. 完成 ===
echo "[✔] 所有备份任务完成：$DATE"
