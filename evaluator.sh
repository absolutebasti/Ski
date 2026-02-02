#!/bin/bash
# SKI EVALUATOR - Continuous monitoring script

LOG_FILE="/home/ubuntu/clawd/workspace/ski-project/evaluator-log.txt"
START_TIME=$(date +%s)
END_TIME=$((START_TIME + 7200))  # 2 hours = 7200 seconds
CHECK_COUNT=0

# Initial log
echo "🎿 SKI EVALUATOR STARTED" > "$LOG_FILE"
echo "Start time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
echo "Will monitor until: $(date -u -d @$END_TIME '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

# Get initial commit state
cd /home/ubuntu/clawd/workspace/ski-project
LAST_COMMIT=$(git log --oneline -1 | awk '{print $1}')
echo "Initial commit: $LAST_COMMIT" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

# Monitoring loop
while [ $(date +%s) -lt $END_TIME ]; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    CURRENT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    CURRENT_COMMIT=$(git log --oneline -1 | awk '{print $1}')
    
    echo "CHECK #$CHECK_COUNT - $CURRENT_TIME" >> "$LOG_FILE"
    
    if [ "$CURRENT_COMMIT" != "$LAST_COMMIT" ]; then
        echo "🚨 NEW COMMIT DETECTED!" >> "$LOG_FILE"
        echo "Previous: $LAST_COMMIT" >> "$LOG_FILE"
        echo "Current: $CURRENT_COMMIT" >> "$LOG_FILE"
        echo "Commit message: $(git log --oneline -1)" >> "$LOG_FILE"
        LAST_COMMIT=$CURRENT_COMMIT
    else
        echo "✓ No new commits" >> "$LOG_FILE"
        echo "Latest: $CURRENT_COMMIT - $(git log --oneline -1 | cut -d' ' -f2-)" >> "$LOG_FILE"
    fi
    
    echo "---" >> "$LOG_FILE"
    
    # Sleep for 2 minutes (120 seconds)
    sleep 120
done

echo "🎿 SKI EVALUATOR COMPLETED" >> "$LOG_FILE"
echo "End time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
echo "Total checks: $CHECK_COUNT" >> "$LOG_FILE"