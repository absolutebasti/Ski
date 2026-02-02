#!/bin/bash
# SKI EVALUATOR - Continuous Monitoring Loop
# Checks git log every 3 minutes and evaluates commits

LOG_FILE="ski-evaluator.log"
LAST_CHECK=""

echo "=== SKI EVALUATOR STARTED ===" >> $LOG_FILE
echo "Time: $(date)" >> $LOG_FILE

while true; do
    echo "" >> $LOG_FILE
    echo "--- Check at $(date) ---" >> $LOG_FILE
    
    # Get latest commit
    LATEST=$(git log --oneline -1)
    echo "Latest commit: $LATEST" >> $LOG_FILE
    
    # Get last 5 commits for context
    echo "Recent commits:" >> $LOG_FILE
    git log --oneline -5 >> $LOG_FILE
    
    # Check if there's a new commit since last check
    if [ "$LATEST" != "$LAST_CHECK" ] && [ -n "$LAST_CHECK" ]; then
        echo "🆕 NEW COMMIT DETECTED!" >> $LOG_FILE
        
        # Get the new commit details
        NEW_COMMIT=$(git log --oneline -1)
        echo "Evaluating: $NEW_COMMIT" >> $LOG_FILE
        
        # Show what files changed
        echo "Files changed:" >> $LOG_FILE
        git show --stat HEAD >> $LOG_FILE
        
        # Check commit message for task IDs
        COMMIT_MSG=$(git log -1 --pretty=%B)
        if echo "$COMMIT_MSG" | grep -qE "\[(HIGH|CRITICAL|MEDIUM|LOW)-[0-9]+\]"; then
            TASK_ID=$(echo "$COMMIT_MSG" | grep -oE "\[(HIGH|CRITICAL|MEDIUM|LOW)-[0-9]+\]")
            echo "✅ Task $TASK_ID completed!" >> $LOG_FILE
        fi
    fi
    
    LAST_CHECK="$LATEST"
    echo "Next check in 3 minutes..." >> $LOG_FILE
    
    # Wait 3 minutes (180 seconds)
    sleep 180
done
