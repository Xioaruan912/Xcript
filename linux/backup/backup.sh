#!/usr/bin/env bash
# ----------------------
# 通用自动备份脚本（打包 + 上传 OneDrive）
# - 单项失败最多尝试 MAX_RETRY 次后跳过，不会卡死
# - 支持 bash <(curl -sSL <URL>) 直接运行（需要 root 时会自动提权）
# - 可覆盖：BACKUP_CONF=/path/backup.conf、BASE_BACKUP_DIR、RCLONE_REMOTE、MAX_RETRY
# - 配置示例（backup.conf）：
#     BASE_BACKUP_DIR=/root/backup/backup
#     RCLONE_REMOTE=myonedrive:backup
#     MAX_RETRY=3
# ----------------------
set -uo pipefail

SELF_URL="${SELF_URL:-https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/backup/backup.sh}"
RETRY_DELAY="${RETRY_DELAY:-5}"          # 重试间隔（秒）
MAX_RETRY="${MAX_RETRY:-3}"              # 单项最大尝试次数
KEEP_LOCAL_DAYS="${KEEP_LOCAL_DAYS:-7}"  # 本地保留天数
KEEP_REMOTE_DAYS="${KEEP_REMOTE_DAYS:-4}"  # 远程保留天数

# ---------- 下载工具：curl 优先，回退 wget ----------
if command -v curl >/dev/null 2>&1; then
    FETCH_TO() { curl -fsSL --connect-timeout 20 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
    FETCH_TO() { wget -qO "$2" "$1"; }
else
    FETCH_TO() { return 1; }
fi

# ---------- 提权：支持 bash <(curl ...) 直接运行 ----------
if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
        exit 1
    fi
    # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
    SELF_TMP="$(mktemp /tmp/xcript-backup-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-backup-$$.sh")"
    if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
        echo "读取自身脚本失败，改为从仓库重新下载..."
        FETCH_TO "$SELF_URL" "$SELF_TMP" || { echo "下载失败，请检查网络。" >&2; exit 1; }
    fi
    chmod +x "$SELF_TMP"
    echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
    exec sudo bash "$SELF_TMP" "$@"
fi

# === 一、加载外部配置（如有） ===
for CONFIG_FILE in "${BACKUP_CONF:-}" /etc/xcript/backup.conf /root/backup/backup.conf "$HOME/.config/xcript/backup.conf"; do
    [ -n "$CONFIG_FILE" ] || continue
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        echo "[*] 已加载配置：$CONFIG_FILE"
        break
    fi
done

# === 二、日期与目录配置 ===
DATE="$(date +'%Y-%m-%d')"
BASE_BACKUP_DIR="${BASE_BACKUP_DIR:-/root/backup/backup}"
BACKUP_DIR="$BASE_BACKUP_DIR/$DATE"
mkdir -p "$BACKUP_DIR"

# === 三、备份项定义（name:type:src_path:filename）===
# type: dir / file / mongo / script
BACKUP_ITEMS=(
    "Vaultwarden:dir:/root/vaultwarden:vaultwarden-backup-$DATE.tar.gz"
    # "Nginx:dir:/etc/nginx:nginx-backup-$DATE.tar.gz"
    "Script:script:$0:backup-script-$DATE.sh"
)

# === 四、MongoDB 配置（用到 mongo 类型时才需要，可在 backup.conf 覆盖） ===
MONGO_HOST="${MONGO_HOST:-127.0.0.1}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER="${MONGO_USER:-}"
MONGO_PASS="${MONGO_PASS:-}"
MONGO_AUTH_DB="${MONGO_AUTH_DB:-admin}"

# === 五、远程上传配置 ===
RCLONE_REMOTE="${RCLONE_REMOTE:-myonedrive:backup}"

# === 六、单项备份（返回 0=成功 1=可重试的失败 2=跳过） ===
backup_once() {
    local NAME="$1" TYPE="$2" SRC_PATH="$3" FILENAME="$4"

    case "$TYPE" in
        dir)
            if [ ! -d "$SRC_PATH" ]; then
                echo "[!] $NAME 目录不存在：$SRC_PATH"
                return 2
            fi
            if tar -czf "$BACKUP_DIR/$FILENAME" -C "$SRC_PATH" . 2>"/tmp/${NAME}_tar.err"; then
                echo "[OK] $NAME 目录打包成功 -> $BACKUP_DIR/$FILENAME"
                return 0
            fi
            echo "[!] $NAME 压缩失败：$(tail -n 3 "/tmp/${NAME}_tar.err" 2>/dev/null)"
            return 1
            ;;

        file)
            if [ ! -f "$SRC_PATH" ]; then
                echo "[!] $NAME 文件不存在：$SRC_PATH"
                return 2
            fi
            if tar -czf "$BACKUP_DIR/$FILENAME" -C "$(dirname "$SRC_PATH")" "$(basename "$SRC_PATH")" 2>"/tmp/${NAME}_tar.err"; then
                echo "[OK] $NAME 文件打包成功 -> $BACKUP_DIR/$FILENAME"
                return 0
            fi
            echo "[!] $NAME 压缩失败：$(tail -n 3 "/tmp/${NAME}_tar.err" 2>/dev/null)"
            return 1
            ;;

        mongo)
            if ! command -v mongodump >/dev/null 2>&1; then
                echo "[!] 未安装 mongodump，跳过 $NAME"
                return 2
            fi
            local MONGO_OUT="/tmp/mongo_backup_$DATE"
            local MONGO_ARGS=(--host "$MONGO_HOST" --port "$MONGO_PORT" --out "$MONGO_OUT")
            if [ -n "$MONGO_USER" ]; then
                MONGO_ARGS+=(--username "$MONGO_USER" --password "$MONGO_PASS" --authenticationDatabase "$MONGO_AUTH_DB")
            fi
            rm -rf "$MONGO_OUT"
            mkdir -p "$MONGO_OUT"
            if ! mongodump "${MONGO_ARGS[@]}" 2>"/tmp/${NAME}_dump.err"; then
                echo "[!] MongoDB 备份失败：$(tail -n 5 "/tmp/${NAME}_dump.err" 2>/dev/null)"
                rm -rf "$MONGO_OUT"
                return 1
            fi
            if tar -czf "$BACKUP_DIR/$FILENAME" -C "$MONGO_OUT" . 2>"/tmp/${NAME}_tar.err"; then
                echo "[OK] MongoDB 压缩成功 -> $BACKUP_DIR/$FILENAME"
                rm -rf "$MONGO_OUT"
                return 0
            fi
            echo "[!] MongoDB 压缩失败：$(tail -n 3 "/tmp/${NAME}_tar.err" 2>/dev/null)"
            rm -rf "$MONGO_OUT"
            return 1
            ;;

        script)
            # 本地文件可读就直接复制；bash <(curl ...) 时 $0 是 /dev/fd/*，改为重新下载
            if [ -f "$SRC_PATH" ] && [ -r "$SRC_PATH" ]; then
                if cp "$SRC_PATH" "$BACKUP_DIR/$FILENAME" 2>"/tmp/${NAME}_cp.err"; then
                    echo "[OK] $NAME 脚本复制成功 -> $BACKUP_DIR/$FILENAME"
                    return 0
                fi
                echo "[!] $NAME 脚本复制失败：$(tail -n 3 "/tmp/${NAME}_cp.err" 2>/dev/null)"
                return 1
            fi
            if FETCH_TO "$SELF_URL" "$BACKUP_DIR/$FILENAME"; then
                echo "[OK] $NAME 脚本已从仓库重新下载 -> $BACKUP_DIR/$FILENAME"
                return 0
            fi
            echo "[!] $NAME 脚本备份失败（本地不可读且无法下载）：$SRC_PATH"
            return 2
            ;;

        *)
            echo "[!] 未知备份类型：$TYPE（$NAME）"
            return 2
            ;;
    esac
}

# === 七、带次数限制的重试包装（不会无限卡住） ===
backup_with_retry() {
    local NAME="$1" TYPE="$2" SRC_PATH="$3" FILENAME="$4"
    local attempt=1 rc=0

    while true; do
        echo "[*] 开始备份 $NAME（类型：$TYPE，第 $attempt/$MAX_RETRY 次）..."
        backup_once "$NAME" "$TYPE" "$SRC_PATH" "$FILENAME"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            return 0
        fi
        if [ "$rc" -eq 2 ]; then
            echo "[!] $NAME 已跳过（源不存在或类型不支持）"
            return 2
        fi
        if [ "$attempt" -ge "$MAX_RETRY" ]; then
            echo "[!] $NAME 尝试 $MAX_RETRY 次仍失败，跳过该项"
            return 1
        fi
        attempt=$((attempt + 1))
        echo "[…] $NAME 将在 ${RETRY_DELAY}s 后重试"
        sleep "$RETRY_DELAY"
    done
}

# === 八、主循环 ===
FAILED=0
for item in "${BACKUP_ITEMS[@]}"; do
    IFS=":" read -r NAME TYPE SRC_PATH FILENAME <<< "$item"
    rc=0
    backup_with_retry "$NAME" "$TYPE" "$SRC_PATH" "$FILENAME" || rc=$?
    if [ "$rc" -eq 1 ]; then
        FAILED=$((FAILED + 1))
    fi
done

# === 九、上传备份到 OneDrive ===
if ! command -v rclone >/dev/null 2>&1; then
    echo "[!] 未安装 rclone，跳过上传。先执行下面脚本并完成 rclone config："
    echo "bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/backup/rclone.sh)"
    FAILED=$((FAILED + 1))
else
    echo "[*] 上传备份到 $RCLONE_REMOTE/$DATE ..."
    if rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE/$DATE" --log-level INFO; then
        echo "[OK] 上传成功：$DATE 目录"
    else
        echo "[!] 上传失败（不退出）。可手动重试："
        echo "rclone copy \"$BACKUP_DIR\" \"$RCLONE_REMOTE/$DATE\" --log-level INFO"
        FAILED=$((FAILED + 1))
    fi
fi

# === 十、本地清理：删除 N 天前的旧备份目录 ===
echo "[*] 清理本地超过 ${KEEP_LOCAL_DAYS} 天的旧备份..."
find "$BASE_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_LOCAL_DAYS" -exec rm -rf {} + 2>/dev/null || true

# === 十一、OneDrive 清理：删除 N 天前的旧目录（失败不退出） ===
if command -v rclone >/dev/null 2>&1; then
    echo "[*] 清理 OneDrive 上 ${KEEP_REMOTE_DAYS} 天前的备份..."
    CUTOFF="$(date -d "-${KEEP_REMOTE_DAYS} days" +%Y-%m-%d 2>/dev/null || true)"
    if [ -z "$CUTOFF" ]; then
        echo "[!] 无法计算过期日期（date -d 不支持），跳过远程清理。"
    else
        OLD_DIRS="$(rclone lsf "$RCLONE_REMOTE/" --dirs-only 2>/tmp/rclone_lsf.err || true)"
        for dir in $OLD_DIRS; do
            dir_cleaned="$(printf '%s' "$dir" | sed 's:/*$::')"
            case "$dir_cleaned" in
                [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
                *) continue ;;
            esac
            if [[ "$dir_cleaned" < "$CUTOFF" ]]; then
                echo "[!] 删除旧远程目录: $dir_cleaned"
                rclone purge "$RCLONE_REMOTE/$dir_cleaned" || echo "[!] 删除远程目录失败：$dir_cleaned（不会退出）"
            fi
        done
    fi
fi

echo "[OK] 所有备份任务完成：$DATE"
if [ "$FAILED" -gt 0 ]; then
    echo "[!] 有 $FAILED 项失败，请检查上面的日志。"
    exit 1
fi
exit 0
