#!/bin/bash
# Continuous Manager Agent Monitoring Loop

PROJECT_DIR="/home/ubuntu/clawd/workspace/ski-project"
LOG_FILE="$PROJECT_DIR/manager.log"
STATE_FILE="$PROJECT_DIR/.manager-state"
ALERT_HISTORY="/tmp/manager_alert_history"

# Timeouts (minutes)
DEV_EVAL_TIMEOUT=10
EVAL_COMMIT_TIMEOUT=10
REVIEWER_UPDATE_TIMEOUT=20
SYSTEM_IDLE_TIMEOUT=15

# Initialize state file
if [ ! -f $STATE_FILE ]; then
    echo "last_check=0" > $STATE_FILE
    echo "reviewer_alerts=0" >> $STATE_FILE
    echo "evaluator_alerts=0" >> $STATE_FILE
    echo "developer_alerts=0" >> $STATE_FILE
    echo "system_alerts=0" >> $STATE_FILE
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

read_state() {
    KEY=$1
    grep "^$KEY=" $STATE_FILE | cut -d= -f2
}

write_state() {
    KEY=$1
    VAL=$2
    sed -i "s/^$KEY=.*/$KEY=$VAL/" $STATE_FILE
}

check_file_age() {
    FILE=$1
    if [ -f "$FILE" ]; then
        MOD_TIME=$(stat -c %Y "$FILE")
        NOW=$(date +%s)
        echo $(( (NOW - MOD_TIME) / 60 ))
    else
        echo "99999"
    fi
}

check_git_age() {
    cd $PROJECT_DIR
    LAST_COMMIT=$(git log -1 --format=%ct 2>/dev/null || echo "0")
    NOW=$(date +%s)
    echo $(( (NOW - LAST_COMMIT) / 60 ))
}

increment_alert() {
    AGENT=$1
    CURRENT=$(read_state "${AGENT}_alerts")
    write_state "${AGENT}_alerts" $((CURRENT + 1))
    echo $((CURRENT + 1))
}

reset_alert() {
    AGENT=$1
    write_state "${AGENT}_alerts" 0
}

send_ping() {
    AGENT=$1
    MINUTES=$2
    ACTIVITY=$3
    ACTION=$4
    
    log "⚠️ MANAGER ALERT: $AGENT has been inactive for $MINUTES minutes."
    log "  Last activity: $ACTIVITY"
    log "  Action required: $ACTION"
    
    # Track for escalation
    COUNT=$(increment_alert $AGENT)
    echo "$(date '+%H:%M') $AGENT $MINUTES $ACTIVITY" >> $ALERT_HISTORY
    
    # Escalation check (3 timeouts in a row)
    if [ $COUNT -ge 3 ]; then
        log "🚨 ESCALATION: $AGENT has been stuck $COUNT times - escalating to all agents!"
        echo "$(date '+%H:%M') ESCALATE $AGENT" >> $ALERT_HISTORY
    fi
}

# Main monitoring
log "🔍 MANAGER CHECK STARTING ==="

# Check file ages
STACK_AGE=$(check_file_age "$PROJECT_DIR/Stack.md")
COMPETITORS_AGE=$(check_file_age "$PROJECT_DIR/competitors.md")
GIT_AGE=$(check_git_age)

log "Status: Git=${GIT_AGE}m Stack=${STACK_AGE}m Competitors=${COMPETITORS_AGE}m"

# Find most recent activity
MOST_RECENT=$GIT_AGE
[ $STACK_AGE -lt $MOST_RECENT ] && MOST_RECENT=$STACK_AGE
[ $COMPETITORS_AGE -lt $MOST_RECENT ] && MOST_RECENT=$COMPETITORS_AGE

# Check Reviewer timeout (Stack.md OR competitors.md)
if [ $STACK_AGE -gt $REVIEWER_UPDATE_TIMEOUT ] && [ $COMPETITORS_AGE -gt $REVIEWER_UPDATE_TIMEOUT ]; then
    send_ping "Reviewer" "$STACK_AGE" "No updates to Stack.md or competitors.md" "Update project documentation with research progress"
else
    reset_alert "reviewer"
fi

# Check system idle (overall)
if [ $MOST_RECENT -gt $SYSTEM_IDLE_TIMEOUT ]; then
    send_ping "System" "$MOST_RECENT" "No commits or file updates" "All agents check in - system needs activity"
else
    reset_alert "system"
fi

write_state "last_check" $(date +%s)
log "✅ MANAGER CHECK COMPLETE ==="
