#!/bin/bash

# ----------------------
# 通用自动备份脚本（支持上传到 OneDrive）
# 支持自定义备份项和 MongoDB 配置
# ----------------------

# === 一、加载外部配置（如有） ===
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# === 二、日期与目录配置 ===
DATE=$(date +'%Y-%m-%d')
BASE_BACKUP_DIR="${BASE_BACKUP_DIR:-/root/backup/backup}"
BACKUP_DIR="$BASE_BACKUP_DIR/$DATE"
mkdir -p "$BACKUP_DIR"

# === 三、备份项定义（数组，每项为 name:type:src_path:filename）===
# type: dir/file/mongo/script
BACKUP_ITEMS=(
    "Vaultwarden:dir:/root/Vaultwarden/data:vaultwarden-backup-$DATE.tar.gz"
    "XBoard:dir:/root/Xboard/.docker/.data:xboard-backup-$DATE.tar.gz"
    "XPay:file:/root/XPay/database.db:xpay-backup-$DATE.tar.gz"
    "Nginx:dir:/etc/nginx:nginx-backup-$DATE.tar.gz"
    "Nezha:dir:/opt/nezha:nezha-backup-$DATE.tar.gz"
    "Script:script:$0:backup-script-$DATE.sh"
    "MongoDB:mongo::mongodb-backup-$DATE.tar.gz"
)

# === 四、MongoDB 配置（可在 backup.conf 覆盖） ===
MONGO_HOST="${MONGO_HOST:-127.0.0.1}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER="${MONGO_USER:-root}"
MONGO_PASS="${MONGO_PASS:-password}"
MONGO_AUTH_DB="${MONGO_AUTH_DB:-admin}"

# === 五、远程上传配置 ===
RCLONE_REMOTE="${RCLONE_REMOTE:-myonedrive:backup}"

# === 六、备份主循环 ===
for item in "${BACKUP_ITEMS[@]}"; do
    IFS=":" read -r NAME TYPE SRC_PATH FILENAME <<< "$item"
    echo "[*] 备份 $NAME..."
    case "$TYPE" in
        dir)
            if [ -d "$SRC_PATH" ]; then
                tar -czf "$BACKUP_DIR/$FILENAME" -C "$SRC_PATH" .
                [ $? -ne 0 ] && echo "[!] $NAME 失败" && exit 1
            else
                echo "[!] 找不到目录：$SRC_PATH"
                exit 1
            fi
            ;;
        file)
            if [ -f "$SRC_PATH" ]; then
                tar -czf "$BACKUP_DIR/$FILENAME" -C "$(dirname "$SRC_PATH")" "$(basename "$SRC_PATH")"
                [ $? -ne 0 ] && echo "[!] $NAME 压缩失败" && exit 1
            else
                echo "[!] 找不到文件：$SRC_PATH"
                exit 1
            fi
            ;;
        mongo)
            MONGO_BACKUP_DIR="/tmp/mongo_backup_$DATE"
            rm -rf "$MONGO_BACKUP_DIR"
            mkdir -p "$MONGO_BACKUP_DIR"
            mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" \
                --username "$MONGO_USER" --password "$MONGO_PASS" \
                --authenticationDatabase "$MONGO_AUTH_DB" \
                --out "$MONGO_BACKUP_DIR"
            [ $? -ne 0 ] && echo "[!] MongoDB 备份失败" && exit 1
            tar -czf "$BACKUP_DIR/$FILENAME" -C "$MONGO_BACKUP_DIR" .
            [ $? -ne 0 ] && echo "[!] MongoDB 压缩失败" && exit 1
            rm -rf "$MONGO_BACKUP_DIR"
            ;;
        script)
            cp "$SRC_PATH" "$BACKUP_DIR/$FILENAME"
            [ $? -ne 0 ] && echo "[!] 脚本复制失败" && exit 1
            ;;
        *)
            echo "[!] 未知备份类型：$TYPE"
            exit 1
            ;;
    esac
done

# === 七、上传备份到 OneDrive ===
echo "[*] 上传备份到 OneDrive..."
rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$DATE" --log-level INFO
[ $? -ne 0 ] && echo "[!] 上传失败" && exit 1
echo "[✓] 上传成功：$DATE 目录"

# === 八、本地清理：删除 7 天前的旧备份目录 ===
echo "[*] 清理本地超过 7 天的旧备份..."
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# === 九、OneDrive 清理：删除 4 天前的旧目录 ===
echo "[*] 清理 OneDrive 上 4 天前的备份..."
FOUR_DAYS_AGO=$(date -d "-4 days" +%Y-%m-%d)
OLD_DIRS=$(rclone lsf "$RCLONE_REMOTE/" --dirs-only)
for dir in $OLD_DIRS; do
    dir_cleaned=$(echo "$dir" | sed 's:/*$::')
    if [[ "$dir_cleaned" < "$FOUR_DAYS_AGO" ]]; then
        echo "[!] 删除旧远程目录: $dir_cleaned"
        rclone purge "$RCLONE_REMOTE/$dir_cleaned"
    fi
done

echo "[✔] 所有备份任务完成：$DATE"
