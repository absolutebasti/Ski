#!/bin/bash
# Manager Agent Monitoring Script for KitzSki Tracker

PROJECT_DIR="/home/ubuntu/clawd/workspace/ski-project"
LOG_FILE="/home/ubuntu/clawd/workspace/ski-project/manager.log"
ALERT_COUNT_FILE="/tmp/manager_alerts"

# Initialize alert counters
[ ! -f $ALERT_COUNT_FILE ] && echo "0 0 0 0" > $ALERT_COUNT_FILE

# Timeout thresholds (in minutes)
DEV_EVAL_TIMEOUT=10      # Developer waiting for Evaluator
EVAL_COMMIT_TIMEOUT=10   # Evaluator hasn't responded to commit
REVIEWER_UPDATE_TIMEOUT=20  # Reviewer hasn't updated Stack.md
SYSTEM_IDLE_TIMEOUT=15   # No activity in entire system

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

check_last_commit() {
    cd $PROJECT_DIR
    LAST_COMMIT=$(git log -1 --format=%ct 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DIFF=$(( (NOW - LAST_COMMIT) / 60 ))
    echo $DIFF
}

check_stack_md_update() {
    if [ -f "$PROJECT_DIR/Stack.md" ]; then
        LAST_MOD=$(stat -c %Y "$PROJECT_DIR/Stack.md")
        NOW=$(date +%s)
        DIFF=$(( (NOW - LAST_MOD) / 60 ))
        echo $DIFF
    else
        echo "9999"
    fi
}

check_competitors_md_update() {
    if [ -f "$PROJECT_DIR/competitors.md" ]; then
        LAST_MOD=$(stat -c %Y "$PROJECT_DIR/competitors.md")
        NOW=$(date +%s)
        DIFF=$(( (NOW - LAST_MOD) / 60 ))
        echo $DIFF
    else
        echo "9999"
    fi
}

send_alert() {
    AGENT=$1
    MINUTES=$2
    ACTIVITY=$3
    ACTION=$4
    
    log "⚠️ MANAGER ALERT: $AGENT has been inactive for $MINUTES minutes."
    log "Last activity: $ACTIVITY"
    log "Action required: $ACTION"
    
    # Store alert info for escalation tracking
    echo "$(date +%s) $AGENT $MINUTES" >> /tmp/manager_alert_history
}

# Main monitoring loop
log "=== MANAGER AGENT MONITORING STARTED ==="

# Initial checks
COMMIT_AGE=$(check_last_commit)
STACK_AGE=$(check_stack_md_update)
COMPETITORS_AGE=$(check_competitors_md_update)

log "Current Status:"
log "  - Last git commit: ${COMMIT_AGE}m ago"
log "  - Stack.md updated: ${STACK_AGE}m ago"
log "  - competitors.md updated: ${COMPETITORS_AGE}m ago"

# Check Reviewer timeout (Stack.md or competitors.md)
if [ $STACK_AGE -gt $REVIEWER_UPDATE_TIMEOUT ] && [ $COMPETITORS_AGE -gt $REVIEWER_UPDATE_TIMEOUT ]; then
    send_alert "Reviewer" "$STACK_AGE" "Stack.md/competitors.md not updated" "Update Stack.md with current task status"
fi

# Check system idle timeout (use most recent activity)
MOST_RECENT=$COMMIT_AGE
[ $STACK_AGE -lt $MOST_RECENT ] && MOST_RECENT=$STACK_AGE
[ $COMPETITORS_AGE -lt $MOST_RECENT ] && MOST_RECENT=$COMPETITORS_AGE

if [ $MOST_RECENT -gt $SYSTEM_IDLE_TIMEOUT ]; then
    send_alert "System" "$MOST_RECENT" "No commits or file updates" "All agents check in - system appears idle"
fi

log "=== MONITORING CHECK COMPLETE ==="
