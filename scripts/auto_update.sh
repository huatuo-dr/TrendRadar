#!/bin/bash

# 配置
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
UPDATE_SCRIPT="$SCRIPT_DIR/update_repo.sh"
PID_FILE="$SCRIPT_DIR/auto_update.pid"
LOG_FILE="$SCRIPT_DIR/auto_update.log"

# 获取下一次 07:00 的时间戳
get_next_run_time() {
    # 今天的 07:00
    local today_target=$(date -d "07:00" +%s)
    local now=$(date +%s)

    if [ "$now" -lt "$today_target" ]; then
        # 如果现在还没到今天的 07:00
        echo "$today_target"
    else
        # 如果已经过了，则是明天的 07:00
        echo $(date -d "tomorrow 07:00" +%s)
    fi
}

# 核心循环逻辑
run_loop() {
    echo "[$(date)] 服务启动" >> "$LOG_FILE"
    while true; do
        target_ts=$(get_next_run_time)
        now_ts=$(date +%s)
        sleep_seconds=$((target_ts - now_ts))
        
        target_date_str=$(date -d @$target_ts)
        echo "[$(date)] 下次执行时间: $target_date_str (等待 ${sleep_seconds}秒)" >> "$LOG_FILE"
        
        # 休眠
        sleep "$sleep_seconds"
        
        # 执行
        echo "[$(date)] 开始执行更新脚本..." >> "$LOG_FILE"
        bash "$UPDATE_SCRIPT" >> "$LOG_FILE" 2>&1
        echo "[$(date)] 更新脚本执行完毕" >> "$LOG_FILE"
        
        # 防止连续执行，稍微等一小会儿
        sleep 60
    done
}

# 命令实现
start() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "服务已经在运行中 (PID: $pid)"
            return
        else
            echo "发现残留的 PID 文件，清理中..."
            rm "$PID_FILE"
        fi
    fi

    echo "正在启动后台定时服务..."
    # 启动后台进程
    (run_loop) > /dev/null 2>&1 & 
    
    new_pid=$!
    echo "$new_pid" > "$PID_FILE"
    echo "服务已启动 (PID: $new_pid)"
    echo "日志文件: $LOG_FILE"
}

stop() {
    if [ ! -f "$PID_FILE" ]; then
        echo "服务未运行 (PID 文件不存在)"
        return
    fi

    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "正在停止服务 (PID: $pid)..."
        kill "$pid"
        rm "$PID_FILE"
        echo "服务已停止"
    else
        echo "服务未运行 (进程不存在)，清理 PID 文件"
        rm "$PID_FILE"
    fi
}

status() {
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: [运行中]"
            echo "PID: $pid"
            echo "Log: $LOG_FILE"
            echo "-------------------"
            tail -n 3 "$LOG_FILE"
        else
            echo "Status: [已停止] (发现残留 PID 文件)"
        fi
    else
        echo "Status: [已停止]"
    fi
}

# 主入口
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    *)
        echo "用法: $0 {start|stop|status}"
        exit 1
        ;;
esac
