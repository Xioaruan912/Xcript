#!/bin/bash

# ----------------------
# 通用自动备份脚本（支持上传到 OneDrive）
# 失败项会在本地一直 while 重试，直到成功，不退出整个脚本
# ----------------------

# === 0、通用设置 ===
RETRY_DELAY="${RETRY_DELAY:-60}"   # 失败后的重试间隔（秒）

# === 一、加载外部配置（如有） ===
CONFIG_FILE="$(dirname "$0")/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
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
    "Nginx:dir:/etc/nginx:nginx-backup-$DATE.tar.gz"
    "Komari:dir:/opt/komari/:Komari-backup-$DATE.tar.gz"
    # "Nezha:dir:/opt/nezha:nezha-backup-$DATE.tar.gz"
    "Script:script:$0:backup-script-$DATE.sh"
    "MongoDB:mongo::mongodb-backup-$DATE.tar.gz"
    "Nexusterminal:dir:/root/nexus-terminal/data:Nexusterminal-backup-$DATE.tar.gz"
)

# === 四、MongoDB 配置（可在 backup.conf 覆盖） ===
MONGO_HOST="${MONGO_HOST:-127.0.0.1}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER="${MONGO_USER:-root}"
MONGO_PASS="${MONGO_PASS:-password}"
MONGO_AUTH_DB="${MONGO_AUTH_DB:-admin}"

# === 五、远程上传配置 ===
RCLONE_REMOTE="${RCLONE_REMOTE:-myonedrive:backup}"

# === 六、封装一个带永久重试的备份函数 ===
backup_with_retry() {
    local NAME="$1"
    local TYPE="$2"
    local SRC_PATH="$3"
    local FILENAME="$4"

    echo "[*] 开始备份 $NAME（类型：$TYPE）..."
    while true; do
        case "$TYPE" in
            dir)
                if [ -d "$SRC_PATH" ]; then
                    tar -czf "$BACKUP_DIR/$FILENAME" -C "$SRC_PATH" . 2>/tmp/${NAME}_tar.err
                    if [ $? -eq 0 ]; then
                        echo "[✓] $NAME 目录打包成功 -> $BACKUP_DIR/$FILENAME"
                        break
                    else
                        echo "[!] $NAME 压缩失败：$(cat /tmp/${NAME}_tar.err 2>/dev/null)"
                    fi
                else
                    echo "[!] $NAME 目录不存在：$SRC_PATH"
                fi
                ;;

            file)
                if [ -f "$SRC_PATH" ]; then
                    tar -czf "$BACKUP_DIR/$FILENAME" -C "$(dirname "$SRC_PATH")" "$(basename "$SRC_PATH")" 2>/tmp/${NAME}_tar.err
                    if [ $? -eq 0 ]; then
                        echo "[✓] $NAME 文件打包成功 -> $BACKUP_DIR/$FILENAME"
                        break
                    else
                        echo "[!] $NAME 压缩失败：$(cat /tmp/${NAME}_tar.err 2>/dev/null)"
                    fi
                else
                    echo "[!] $NAME 文件不存在：$SRC_PATH"
                fi
                ;;

            mongo)
                MONGO_BACKUP_DIR="/tmp/mongo_backup_$DATE"
                rm -rf "$MONGO_BACKUP_DIR"
                mkdir -p "$MONGO_BACKUP_DIR"

                # mongodump 失败会重试
                mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" \
                    --username "$MONGO_USER" --password "$MONGO_PASS" \
                    --authenticationDatabase "$MONGO_AUTH_DB" \
                    --out "$MONGO_BACKUP_DIR" 2>/tmp/${NAME}_dump.err

                if [ $? -ne 0 ]; then
                    echo "[!] MongoDB 备份失败：$(tail -n 5 /tmp/${NAME}_dump.err 2>/dev/null)"
                    rm -rf "$MONGO_BACKUP_DIR"
                else
                    tar -czf "$BACKUP_DIR/$FILENAME" -C "$MONGO_BACKUP_DIR" . 2>/tmp/${NAME}_tar.err
                    if [ $? -eq 0 ]; then
                        echo "[✓] MongoDB 压缩成功 -> $BACKUP_DIR/$FILENAME"
                        rm -rf "$MONGO_BACKUP_DIR"
                        break
                    else
                        echo "[!] MongoDB 压缩失败：$(cat /tmp/${NAME}_tar.err 2>/dev/null)"
                        rm -rf "$MONGO_BACKUP_DIR"
                    fi
                fi
                ;;

            script)
                if [ -f "$SRC_PATH" ]; then
                    cp "$SRC_PATH" "$BACKUP_DIR/$FILENAME" 2>/tmp/${NAME}_cp.err
                    if [ $? -eq 0 ]; then
                        echo "[✓] $NAME 脚本复制成功 -> $BACKUP_DIR/$FILENAME"
                        break
                    else
                        echo "[!] $NAME 脚本复制失败：$(cat /tmp/${NAME}_cp.err 2>/dev/null)"
                    fi
                else
                    echo "[!] $NAME 脚本不存在：$SRC_PATH"
                fi
                ;;

            *)
                echo "[!] 未知备份类型：$TYPE（$NAME）"
                # 未知类型没法处理，避免死循环：仍然休眠重试，方便后续修正配置后继续
                ;;
        esac

        echo "[…] $NAME 将在 ${RETRY_DELAY}s 后重试"
        sleep "$RETRY_DELAY"
    done
}

# === 七、备份主循环（单项失败将永久重试） ===
for item in "${BACKUP_ITEMS[@]}"; do
    IFS=":" read -r NAME TYPE SRC_PATH FILENAME <<< "$item"
    backup_with_retry "$NAME" "$TYPE" "$SRC_PATH" "$FILENAME"
done

# === 八、上传备份到 OneDrive（如失败，不退出，但会提示） ===
echo "[*] 上传备份到 OneDrive..."
rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$DATE" --log-level INFO
if [ $? -ne 0 ]; then
    echo "[!] 上传失败（不会退出）。你可以稍后手动重试："
    echo "    rclone copy \"$BACKUP_DIR\" \"$RCLONE_REMOTE/$DATE\" --log-level INFO"
else
    echo "[✓] 上传成功：$DATE 目录"
fi

# === 九、本地清理：删除 7 天前的旧备份目录 ===
echo "[*] 清理本地超过 7 天的旧备份..."
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# === 十、OneDrive 清理：删除 4 天前的旧目录（失败不退出） ===
echo "[*] 清理 OneDrive 上 4 天前的备份..."
FOUR_DAYS_AGO=$(date -d "-4 days" +%Y-%m-%d)
OLD_DIRS=$(rclone lsf "$RCLONE_REMOTE/" --dirs-only 2>/tmp/rclone_lsf.err)
if [ $? -ne 0 ]; then
    echo "[!] 远程目录列表获取失败：$(cat /tmp/rclone_lsf.err 2>/dev/null)"
else
    for dir in $OLD_DIRS; do
        dir_cleaned=$(echo "$dir" | sed 's:/*$::')
        if [[ "$dir_cleaned" < "$FOUR_DAYS_AGO" ]]; then
            echo "[!] 删除旧远程目录: $dir_cleaned"
            rclone purge "$RCLONE_REMOTE/$dir_cleaned"
            if [ $? -ne 0 ]; then
                echo "[!] 删除远程目录失败：$dir_cleaned（不会退出）"
            fi
        fi
    done
fi

echo "[✔] 所有备份任务完成：$DATE"
