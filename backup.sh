#!/bin/bash

# 基本配置
DATE=$(date +'%Y-%m-%d')
BACKUP_DIR="/root/backup/backup"
VB_DATA_DIR="/root/VB/data"
XBOARD_DIR="/root/Xboard/.docker/.data"
MONGO_BACKUP_DIR="/root/backup/mongo_backup_$DATE"
FILENAME_VAULT="vaultwarden-backup-$DATE.tar.gz"
FILENAME_XBOARD="xboard-backup-$DATE.tar.gz"
FILENAME_MONGO="mongodb-backup-$DATE.tar.gz"
RCLONE_REMOTE="myonedrive:backup"  # 修改为你配置的 remote 名

# MongoDB 认证信息配置
MONGO_HOST="82.21.190.8"          # MongoDB 地址，默认本地
MONGO_PORT="27017"              # MongoDB 端口
MONGO_USER="xioaruan"           # MongoDB 用户名
MONGO_PASS="214253551"       # MongoDB 密码
MONGO_AUTH_DB="admin"           # 认证数据库，通常是 admin

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# === 1. 备份 Vaultwarden ===
echo "[*] 开始备份 Vaultwarden 数据..."
tar -czf "$BACKUP_DIR/$FILENAME_VAULT" -C "$VB_DATA_DIR" .
if [ $? -ne 0 ]; then
  echo "[!] Vaultwarden 压缩失败"
  exit 1
fi

# === 2. 备份 XBoard ===
echo "[*] 开始备份 XBoard 数据..."
tar -czf "$BACKUP_DIR/$FILENAME_XBOARD" -C "$XBOARD_DIR" .
if [ $? -ne 0 ]; then
  echo "[!] XBoard 压缩失败"
  exit 1
fi

# === 3. 备份 MongoDB ===
echo "[*] 开始备份 MongoDB 数据..."
rm -rf "$MONGO_BACKUP_DIR"
mkdir -p "$MONGO_BACKUP_DIR"

# 执行 mongodump 带认证
mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" \
  --username "$MONGO_USER" --password "$MONGO_PASS" \
  --authenticationDatabase "$MONGO_AUTH_DB" \
  --out "$MONGO_BACKUP_DIR"

if [ $? -ne 0 ]; then
  echo "[!] MongoDB 备份失败"
  exit 1
fi

# 压缩 MongoDB 备份目录
tar -czf "$BACKUP_DIR/$FILENAME_MONGO" -C "$MONGO_BACKUP_DIR" .
if [ $? -ne 0 ]; then
  echo "[!] MongoDB 压缩失败"
  exit 1
fi

rm -rf "$MONGO_BACKUP_DIR"

# === 4. 上传到 OneDrive ===
echo "[*] 开始上传到 OneDrive..."
rclone copy "$BACKUP_DIR/$FILENAME_VAULT" "$RCLONE_REMOTE/" --log-level INFO
rclone copy "$BACKUP_DIR/$FILENAME_XBOARD" "$RCLONE_REMOTE/" --log-level INFO
rclone copy "$BACKUP_DIR/$FILENAME_MONGO" "$RCLONE_REMOTE/" --log-level INFO

if [ $? -eq 0 ]; then
  echo "[✓] 上传成功：$FILENAME_VAULT, $FILENAME_XBOARD 和 $FILENAME_MONGO"
else
  echo "[!] 上传失败，请检查 rclone 配置"
  exit 1
fi

# === 5. 清理 7 天前旧备份 ===
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -exec rm -f {} \;

# === 6. 完成日志 ===
echo "[✔] 所有备份完成：$DATE"
