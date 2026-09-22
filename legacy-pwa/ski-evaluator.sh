#!/bin/bash
# SKI EVALUATOR - Commit Evaluation Script
# Evaluates new commits and updates Stack.md

PROJECT_DIR="/home/ubuntu/clawd/workspace/ski-project"
STACK_FILE="$PROJECT_DIR/Stack.md"
LOG_FILE="$PROJECT_DIR/ski-evaluator.log"
STATE_FILE="$PROJECT_DIR/.ski-evaluator-state"

evaluate_commit() {
    local commit_hash=$1
    local commit_msg=$(git log -1 --pretty=%B $commit_hash)
    local commit_author=$(git log -1 --pretty=%an $commit_hash)
    local commit_date=$(git log -1 --pretty=%cd --date=iso $commit_hash)
    
    echo "=== EVALUATING COMMIT ===" >> $LOG_FILE
    echo "Hash: $commit_hash" >> $LOG_FILE
    echo "Author: $commit_author" >> $LOG_FILE
    echo "Date: $commit_date" >> $LOG_FILE
    echo "Message: $commit_msg" >> $LOG_FILE
    
    # Extract task IDs from commit message
    local task_ids=$(echo "$commit_msg" | grep -oE '\[(HIGH|CRITICAL|MEDIUM|LOW|EVALUATION|INFRA)-[0-9]+\]' || true)
    
    if [ -n "$task_ids" ]; then
        echo "Found task IDs: $task_ids" >> $LOG_FILE
        
        # For each task ID found, mark as completed in Stack.md
        for task_id in $task_ids; do
            # Clean up brackets
            clean_id=$(echo "$task_id" | tr -d '[]')
            mark_task_completed "$clean_id" "$commit_hash" "$commit_date"
        done
    fi
    
    # Check for implementation commits
    if echo "$commit_msg" | grep -qE "(Implement|Add|Create|Build)"; then
        echo "🛠️ Implementation commit detected" >> $LOG_FILE
    fi
    
    # Check for Stack.md updates
    if echo "$commit_msg" | grep -q "Stack.md"; then
        echo "📋 Stack.md update commit" >> $LOG_FILE
    fi
}

mark_task_completed() {
    local task_id=$1
    local commit_hash=$2
    local commit_date=$3
    
    echo "Marking $task_id as completed..." >> $LOG_FILE
    
    # Use sed to update Stack.md - mark task as completed
    # Look for the task header and update its status
    if grep -q "\[$task_id\]" "$STACK_FILE"; then
        # Update status to COMPLETED if not already
        sed -i "s/Status:.*\[$task_id\]/Status: ✅ COMPLETED/g" "$STACK_FILE" 2>/dev/null || true
        sed -i "s/Status:.*pending.*\[$task_id\]/Status: ✅ COMPLETED/g" "$STACK_FILE" 2>/dev/null || true
        echo "Updated $task_id status in Stack.md" >> $LOG_FILE
    fi
}

# Main monitoring loop
cd $PROJECT_DIR

LAST_COMMIT=""
if [ -f "$STATE_FILE" ]; then
    LAST_COMMIT=$(cat "$STATE_FILE")
fi

echo "=== SKI EVALUATOR v1.0 STARTED ===" >> $LOG_FILE
echo "Watching: $PROJECT_DIR" >> $LOG_FILE
echo "Stack file: $STACK_FILE" >> $LOG_FILE
echo "Last known commit: $LAST_COMMIT" >> $LOG_FILE

while true; do
    CURRENT_COMMIT=$(git rev-parse HEAD)
    
    if [ "$CURRENT_COMMIT" != "$LAST_COMMIT" ]; then
        echo "$(date): New commit detected - $CURRENT_COMMIT" >> $LOG_FILE
        evaluate_commit "$CURRENT_COMMIT"
        echo "$CURRENT_COMMIT" > "$STATE_FILE"
        LAST_COMMIT=$CURRENT_COMMIT
    fi
    
    # Check every 3 minutes (180 seconds)
    sleep 180
done
