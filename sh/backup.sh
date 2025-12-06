#!/bin/bash

# =========================================================
#  全交互式备份脚本 (无需修改代码，运行即可配置)
# =========================================================

# 获取脚本所在目录，配置文件将保存在这里
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/backup.conf"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# =========================================================
#  函数：配置向导 (生成配置文件)
# =========================================================
configure_wizard() {
    clear
    echo -e "${BLUE}############################################${NC}"
    echo -e "${BLUE}#      欢迎使用 X-Backup 配置向导          #${NC}"
    echo -e "${BLUE}############################################${NC}"
    echo -e "配置文件将保存在: $CONF_FILE\n"

    # 1. 设置本地备份目录
    read -e -p "1. 本地备份存放目录 (默认: /root/backup): " INPUT_DIR
    LOCAL_DIR="${INPUT_DIR:-/root/backup}"
    
    # 2. 设置 Rclone 远程
    echo -e "\n2. Rclone 远程配置 (例如: onedrive:backup)"
    echo -e "   如果没有配置 Rclone 或只想本地备份，请直接回车跳过。"
    read -e -p "   请输入 Rclone 名称: " INPUT_REMOTE
    REMOTE_DEST="$INPUT_REMOTE"

    # 3. 设置保留天数
    echo -e "\n3. 备份保留策略"
    read -e -p "   本地保留几天? (默认: 7): " INPUT_LDAY
    KEEP_LOCAL="${INPUT_LDAY:-7}"
    
    if [ -n "$REMOTE_DEST" ]; then
        read -e -p "   远程保留几天? (默认: 15): " INPUT_RDAY
        KEEP_REMOTE="${INPUT_RDAY:-15}"
    else
        KEEP_REMOTE=0
    fi

    # 4. 循环添加备份项目
    echo -e "\n4. 添加要备份的文件或目录 (输入完一个回车，直接回车结束)"
    BACKUP_ITEMS=()
    while true; do
        read -e -p "   请输入路径 (结束请回车): " ITEM_PATH
        if [ -z "$ITEM_PATH" ]; then
            break
        fi
        
        # 简单检查路径是否存在
        if [ ! -e "$ITEM_PATH" ]; then
            echo -e "   ${YELLOW}[警告] 路径不存在: $ITEM_PATH (但已添加到列表)${NC}"
        else
            echo -e "   ${GREEN}[已添加] $ITEM_PATH${NC}"
        fi
        BACKUP_ITEMS+=("$ITEM_PATH")
    done

    # 如果没有添加任何项目
    if [ ${#BACKUP_ITEMS[@]} -eq 0 ]; then
        echo -e "\n${RED}[错误] 未配置任何备份项目，退出。${NC}"
        exit 1
    fi

    # 5. 生成配置文件
    echo -e "\n正在生成配置文件..."
    
    cat > "$CONF_FILE" <<EOF
# X-Backup 配置文件 (由脚本自动生成)
# 生成时间: $(date)

# 本地备份根目录
BACKUP_ROOT="$LOCAL_DIR"

# 远程 Rclone 路径 (留空则不上传)
REMOTE_DEST="$REMOTE_DEST"

# 保留天数
KEEP_LOCAL=$KEEP_LOCAL
KEEP_REMOTE=$KEEP_REMOTE

# 备份列表 (数组格式)
BACKUP_LIST=(
EOF

    # 写入数组内容
    for item in "${BACKUP_ITEMS[@]}"; do
        echo "    \"$item\"" >> "$CONF_FILE"
    done

    echo ")" >> "$CONF_FILE"

    echo -e "${GREEN}[成功] 配置已保存！${NC}"
    echo -e "您可以随时运行 ${YELLOW}bash $0 config${NC} 重新配置。"
    echo -e "-----------------------------------------------------\n"
}

# =========================================================
#  函数：执行备份任务
# =========================================================
run_backup() {
    # 读取配置
    source "$CONF_FILE"
    
    DATE_STR=$(date +'%Y-%m-%d')
    TODAY_DIR="$BACKUP_ROOT/$DATE_STR"
    mkdir -p "$TODAY_DIR"

    echo -e "${BLUE}[INFO] 开始备份任务: $DATE_STR${NC}"

    # 1. 执行打包
    for SRC in "${BACKUP_LIST[@]}"; do
        NAME=$(basename "$SRC")
        TARGET="$TODAY_DIR/${NAME}_${DATE_STR}.tar.gz"
        
        if [ -e "$SRC" ]; then
            tar -czPf "$TARGET" "$SRC" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "  [备份成功] $SRC -> $TARGET"
            else
                echo -e "  ${RED}[备份失败] $SRC (Tar error)${NC}"
            fi
        else
            echo -e "  ${YELLOW}[跳过] 源路径不存在: $SRC${NC}"
        fi
    done

    # 2. Rclone 上传
    if [ -n "$REMOTE_DEST" ]; then
        echo -e "${BLUE}[INFO] 正在上传到远程: $REMOTE_DEST${NC}"
        rclone copy "$TODAY_DIR" "$REMOTE_DEST/$DATE_STR" --log-level ERROR
    fi

    # 3. 清理本地
    echo -e "${BLUE}[INFO] 清理本地旧备份 (保留 $KEEP_LOCAL 天)${NC}"
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +$KEEP_LOCAL -exec rm -rf {} \;

    # 4. 清理远程
    if [ -n "$REMOTE_DEST" ]; then
        echo -e "${BLUE}[INFO] 清理远程旧备份 (保留 $KEEP_REMOTE 天)${NC}"
        # 简单计算截止时间戳
        CUTOFF_TS=$(date -d "-$KEEP_REMOTE days" +%s)
        REMOTE_DIRS=$(rclone lsf "$REMOTE_DEST" --dirs-only 2>/dev/null)
        
        for R_DIR in $REMOTE_DIRS; do
            DIR_NAME=${R_DIR%/}
            if [[ "$DIR_NAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                DIR_TS=$(date -d "$DIR_NAME" +%s 2>/dev/null)
                if [[ -n "$DIR_TS" && $DIR_TS -lt $CUTOFF_TS ]]; then
                    echo "  删除远程: $DIR_NAME"
                    rclone purge "$REMOTE_DEST/$DIR_NAME" 2>/dev/null
                fi
            fi
        done
    fi
    
    echo -e "${GREEN}[完成] 所有任务执行完毕。${NC}"
}

# =========================================================
#  主逻辑入口
# =========================================================

# 如果带参数 config，或者配置文件不存在，则进入配置向导
if [ "$1" == "config" ] || [ ! -f "$CONF_FILE" ]; then
    configure_wizard
    
    read -p "是否立即运行一次备份? (y/n): " RUN_NOW
    if [[ "$RUN_NOW" != "y" ]]; then
        echo "已退出。以后只需运行 bash $0 即可自动备份。"
        exit 0
    fi
fi

# 运行备份
run_backup