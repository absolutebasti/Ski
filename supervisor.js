#!/usr/bin/env node
/**
 * SKI PROJECT SUPERVISOR
 * Monitors and restarts agents automatically
 * Runs continuously to ensure 24/7 operation
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const LOG_FILE = '/home/ubuntu/clawd/workspace/ski-project/supervisor.log';
const STATE_FILE = '/home/ubuntu/clawd/workspace/ski-project/.supervisor-state';

// Agent configurations
const AGENTS = [
  {
    name: 'ski-developer',
    label: 'ski-developer-v',
    minRuntime: 110, // minutes - restart after 1h50m
    spawnCommand: 'sessions_spawn'
  },
  {
    name: 'ski-evaluator', 
    label: 'ski-evaluator-v',
    minRuntime: 110,
    spawnCommand: 'sessions_spawn'
  },
  {
    name: 'ski-reviewer',
    label: 'ski-reviewer-v', 
    minRuntime: 110,
    spawnCommand: 'sessions_spawn'
  }
];

function log(message) {
  const timestamp = new Date().toISOString();
  const logLine = `[${timestamp}] ${message}\n`;
  fs.appendFileSync(LOG_FILE, logLine);
  console.log(logLine.trim());
}

function checkAgentStatus(agentName) {
  try {
    const result = execSync('clawdbot sessions list --kinds subagent --json 2>/dev/null || echo "[]"', { encoding: 'utf8' });
    const sessions = JSON.parse(result);
    
    // Find active sessions for this agent type
    const activeSessions = sessions.filter(s => 
      s.label && s.label.includes(agentName.replace('ski-', ''))
    );
    
    return activeSessions.length > 0 ? activeSessions : null;
  } catch (e) {
    return null;
  }
}

function spawnAgent(agentName, label, task) {
  log(`Spawning ${agentName}...`);
  
  try {
    // Create a spawn script
    const spawnScript = `
const { sessions_spawn } = require('clawdbot');

sessions_spawn({
  task: ${JSON.stringify(task)},
  label: '${label}${Date.now()}',
  agentId: 'main',
  runTimeoutSeconds: 7200,
  cleanup: 'keep'
}).then(result => {
  console.log('Spawned:', result);
}).catch(err => {
  console.error('Spawn failed:', err);
});
`;
    
    fs.writeFileSync('/tmp/spawn-agent.js', spawnScript);
    execSync('node /tmp/spawn-agent.js', { timeout: 30000 });
    
    log(`${agentName} spawned successfully`);
    return true;
  } catch (e) {
    log(`ERROR spawning ${agentName}: ${e.message}`);
    return false;
  }
}

function main() {
  log('=== SUPERVISOR STARTED ===');
  
  // Check each agent
  for (const agent of AGENTS) {
    const status = checkAgentStatus(agent.name);
    
    if (!status) {
      log(`${agent.name} is NOT RUNNING - RESTARTING`);
      
      const task = agent.name === 'ski-developer' 
        ? 'SKI DEVELOPER - WORK CONTINUOUSLY!\n\nGo to /home/ubuntu/clawd/workspace/ski-project\nRead Stack.md\nFind HIGH priority tasks\nImplement them:\n- Write code\n- git add -A\n- git commit -m "[TASK] description"\n- git push origin main\n- Update Stack.md\n\nKeep working! Repeat forever!'
        : agent.name === 'ski-evaluator'
        ? 'SKI EVALUATOR - WORK CONTINUOUSLY!\n\nGo to /home/ubuntu/clawd/workspace/ski-project\nEvery 3 minutes:\n- Check git log --oneline -5\n- Check Stack.md\n- Evaluate commits\n- Update Stack.md\n\nKeep going forever!'
        : 'SKI REVIEWER - WORK CONTINUOUSLY!\n\nGo to /home/ubuntu/clawd/workspace/ski-project\nEvery 10 minutes:\n- Research competitors (web_search)\n- Google Scholar\n- Check code quality\n- Add tasks to Stack.md\n\nGenerate improvements forever!';
      
      spawnAgent(agent.name, agent.label, task);
    } else {
      log(`${agent.name} is running (${status.length} sessions)`);
    }
  }
  
  log('=== SUPERVISOR CHECK COMPLETE ===\n');
}

// Run immediately
main();

// Also run every 10 minutes via cron
console.log('Supervisor complete. For 24/7 operation, add to cron:');
console.log('*/10 * * * * cd /home/ubuntu/clawd && node workspace/ski-project/supervisor.js');
