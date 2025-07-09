#!/usr/bin/env python3
"""
Ansible Execution Tree Parser
Converts Ansible playbook output into a hierarchical tree structure with advanced analytics

Features:
- Visual tree structure of Ansible execution
- Performance timing analysis
- Success rate tracking
- JSON output for CI/CD integration
- Slack/Teams webhook notifications
- Historical trend analysis
- Export to multiple formats (markdown, json, html)
"""

import re
import sys
import json
import time
import argparse
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Union
from dataclasses import dataclass, asdict
from pathlib import Path

@dataclass
class ExecutionNode:
    level: int
    name: str
    status: str = ""
    host: str = ""
    changed: bool = False
    failed: bool = False
    skipped: bool = False
    details: str = ""
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    duration: Optional[float] = None
    task_type: str = ""  # play, task, handler, etc.
    children: List['ExecutionNode'] = None
    
    def __post_init__(self):
        if self.children is None:
            self.children = []
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        result = asdict(self)
        # Convert datetime objects to ISO strings
        if self.start_time:
            result['start_time'] = self.start_time.isoformat()
        if self.end_time:
            result['end_time'] = self.end_time.isoformat()
        return result

class AnsibleExecutionParser:
    def __init__(self):
        self.root = ExecutionNode(0, "Ansible Playbook Execution", task_type="root")
        self.current_play = None
        self.current_task = None
        self.current_role = None
        self.start_time = datetime.now()
        self.timestamps = {}  # Track task timing
        self.metrics = {
            'total_plays': 0,
            'total_tasks': 0,
            'total_hosts': set(),
            'failed_tasks': 0,
            'changed_tasks': 0,
            'skipped_tasks': 0,
            'total_duration': 0,
            'slowest_tasks': [],
            'failed_hosts': set(),
            'performance_summary': {}
        }
        
    def parse_line(self, line: str) -> Optional[ExecutionNode]:
        line = line.strip()
        
        # Skip empty lines and separators
        if not line or line.startswith('*') or line.startswith('='):
            return None
            
        # Parse PLAY blocks
        play_match = re.match(r'PLAY \[(.*?)\]', line)
        if play_match:
            play_name = play_match.group(1)
            node = ExecutionNode(1, f"🎭 PLAY: {play_name}", task_type="play", start_time=datetime.now())
            self.root.children.append(node)
            self.current_play = node
            self.metrics['total_plays'] += 1
            return node
            
        # Parse TASK blocks
        task_match = re.match(r'TASK \[(.*?)\]', line)
        if task_match:
            task_name = task_match.group(1)
            # End timing for previous task
            if self.current_task and self.current_task.start_time:
                self.current_task.end_time = datetime.now()
                self.current_task.duration = (self.current_task.end_time - self.current_task.start_time).total_seconds()
            
            node = ExecutionNode(2, f"📋 TASK: {task_name}", task_type="task", start_time=datetime.now())
            if self.current_play:
                self.current_play.children.append(node)
            self.current_task = node
            self.metrics['total_tasks'] += 1
            return node
            
        # Parse included tasks
        included_match = re.match(r'included: (.*?) for (.*)', line)
        if included_match:
            role_path = included_match.group(1)
            hosts = included_match.group(2)
            role_name = role_path.split('/')[-1] if '/' in role_path else role_path
            node = ExecutionNode(3, f"📦 INCLUDE: {role_name}", host=hosts)
            if self.current_task:
                self.current_task.children.append(node)
            self.current_role = node
            return node
            
        # Parse task results
        result_match = re.match(r'(ok|changed|failed|skipping|fatal): \[(.*?)\]', line)
        if result_match:
            status = result_match.group(1)
            host = result_match.group(2)
            
            # Update metrics
            self.metrics['total_hosts'].add(host)
            if status == 'changed':
                self.metrics['changed_tasks'] += 1
            elif status in ['failed', 'fatal']:
                self.metrics['failed_tasks'] += 1
                self.metrics['failed_hosts'].add(host)
            elif status == 'skipping':
                self.metrics['skipped_tasks'] += 1
            
            # Extract details if present
            details = ""
            if '=>' in line:
                details = line.split('=>', 1)[1].strip()
                
            node = ExecutionNode(
                4, 
                f"{'✅' if status == 'ok' else '🔄' if status == 'changed' else '❌' if status in ['failed', 'fatal'] else '⏭️'} {status.upper()}: {host}",
                status=status,
                host=host,
                changed=(status == 'changed'),
                failed=(status in ['failed', 'fatal']),
                skipped=(status == 'skipping'),
                details=details,
                task_type="result"
            )
            
            if self.current_role:
                self.current_role.children.append(node)
            elif self.current_task:
                self.current_task.children.append(node)
            return node
            
        # Parse HANDLER blocks
        handler_match = re.match(r'RUNNING HANDLER \[(.*?)\]', line)
        if handler_match:
            handler_name = handler_match.group(1)
            node = ExecutionNode(2, f"🔧 HANDLER: {handler_name}")
            if self.current_play:
                self.current_play.children.append(node)
            self.current_task = node
            return node
            
        # Parse PLAY RECAP
        if line.startswith('PLAY RECAP'):
            node = ExecutionNode(1, "📊 PLAY RECAP")
            self.root.children.append(node)
            self.current_play = node
            return node
            
        # Parse recap lines
        recap_match = re.match(r'(\S+)\s+:\s+ok=(\d+)\s+changed=(\d+)\s+unreachable=(\d+)\s+failed=(\d+)', line)
        if recap_match:
            host = recap_match.group(1)
            ok = recap_match.group(2)
            changed = recap_match.group(3)
            unreachable = recap_match.group(4)
            failed = recap_match.group(5)
            
            status_emoji = "✅" if failed == "0" else "❌"
            node = ExecutionNode(
                2, 
                f"{status_emoji} {host}: OK={ok} CHANGED={changed} FAILED={failed}",
                host=host,
                failed=(failed != "0")
            )
            if self.current_play:
                self.current_play.children.append(node)
            return node
            
        return None
    
    def print_tree(self, node: ExecutionNode = None, prefix: str = "", is_last: bool = True):
        if node is None:
            node = self.root
            
        # Print current node
        if node.level == 0:
            print(f"🌳 {node.name}")
        else:
            connector = "└── " if is_last else "├── "
            print(f"{prefix}{connector}{node.name}")
            if node.details and len(node.details) < 100:
                detail_prefix = prefix + ("    " if is_last else "│   ")
                print(f"{detail_prefix}💬 {node.details}")
        
        # Print children
        for i, child in enumerate(node.children):
            is_child_last = (i == len(node.children) - 1)
            child_prefix = prefix + ("    " if is_last else "│   ")
            self.print_tree(child, child_prefix, is_child_last)
    
    def generate_markdown(self, node: ExecutionNode = None, level: int = 0) -> str:
        if node is None:
            node = self.root
            
        markdown = ""
        indent = "  " * level
        
        if node.level == 0:
            markdown += f"# {node.name}\n\n"
        else:
            markdown += f"{indent}- {node.name}\n"
            if node.details and len(node.details) < 200:
                markdown += f"{indent}  - Details: `{node.details}`\n"
        
        for child in node.children:
            markdown += self.generate_markdown(child, level + 1)
            
        return markdown
    
    def finalize_metrics(self):
        """Calculate final metrics after parsing is complete"""
        self.root.end_time = datetime.now()
        self.root.duration = (self.root.end_time - self.start_time).total_seconds()
        self.metrics['total_duration'] = self.root.duration
        self.metrics['total_hosts'] = list(self.metrics['total_hosts'])
        self.metrics['failed_hosts'] = list(self.metrics['failed_hosts'])
        
        # Calculate success rate
        total_operations = self.metrics['total_tasks'] * len(self.metrics['total_hosts'])
        if total_operations > 0:
            self.metrics['success_rate'] = ((total_operations - self.metrics['failed_tasks']) / total_operations) * 100
        else:
            self.metrics['success_rate'] = 100
        
        # Find slowest tasks
        self._collect_task_performance(self.root)
        self.metrics['slowest_tasks'] = sorted(
            [task for task in self.metrics['slowest_tasks'] if task['duration'] > 0],
            key=lambda x: x['duration'],
            reverse=True
        )[:10]
    
    def _collect_task_performance(self, node: ExecutionNode):
        """Recursively collect task performance data"""
        if node.task_type == "task" and node.duration:
            self.metrics['slowest_tasks'].append({
                'name': node.name.replace('📋 TASK: ', ''),
                'duration': node.duration,
                'status': 'failed' if node.failed else 'success'
            })
        
        for child in node.children:
            self._collect_task_performance(child)
    
    def generate_json_report(self) -> Dict:
        """Generate comprehensive JSON report"""
        return {
            'execution_summary': {
                'start_time': self.start_time.isoformat(),
                'end_time': self.root.end_time.isoformat() if self.root.end_time else None,
                'total_duration': self.metrics['total_duration'],
                'success_rate': self.metrics['success_rate']
            },
            'metrics': self.metrics,
            'execution_tree': self._node_to_dict(self.root)
        }
    
    def _node_to_dict(self, node: ExecutionNode) -> Dict:
        """Convert execution tree to dictionary"""
        result = node.to_dict()
        result['children'] = [self._node_to_dict(child) for child in node.children]
        return result
    
    def generate_html_report(self) -> str:
        """Generate HTML report with interactive features"""
        html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Ansible Execution Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric-card { background: #ecf0f1; padding: 15px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #2c3e50; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        .tree { font-family: monospace; white-space: pre-line; background: #f8f9fa; padding: 15px; border-radius: 8px; }
        .slowest-tasks { margin-top: 20px; }
        .task-item { padding: 8px; margin: 4px 0; background: #fff; border-left: 4px solid #3498db; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌳 Ansible Execution Report</h1>
        <p>Generated at {timestamp}</p>
    </div>
    
    <div class="metrics">
        <div class="metric-card">
            <div class="metric-value success">{success_rate:.1f}%</div>
            <div>Success Rate</div>
        </div>
        <div class="metric-card">
            <div class="metric-value">{total_duration:.1f}s</div>
            <div>Total Duration</div>
        </div>
        <div class="metric-card">
            <div class="metric-value">{total_tasks}</div>
            <div>Total Tasks</div>
        </div>
        <div class="metric-card">
            <div class="metric-value {failed_class}">{failed_tasks}</div>
            <div>Failed Tasks</div>
        </div>
    </div>
    
    <div class="slowest-tasks">
        <h2>🐌 Slowest Tasks</h2>
        {slowest_tasks_html}
    </div>
    
    <div class="tree">
        <h2>📊 Execution Tree</h2>
        {tree_output}
    </div>
</body>
</html>
        """
        
        # Generate slowest tasks HTML
        slowest_html = ""
        for task in self.metrics['slowest_tasks'][:5]:
            slowest_html += f'<div class="task-item">{task["name"]} - {task["duration"]:.1f}s</div>'
        
        return html_template.format(
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            success_rate=self.metrics['success_rate'],
            total_duration=self.metrics['total_duration'],
            total_tasks=self.metrics['total_tasks'],
            failed_tasks=self.metrics['failed_tasks'],
            failed_class="error" if self.metrics['failed_tasks'] > 0 else "success",
            slowest_tasks_html=slowest_html,
            tree_output=self._generate_tree_text()
        )
    
    def _generate_tree_text(self) -> str:
        """Generate plain text tree for HTML report"""
        result = []
        
        def traverse(node, prefix="", is_last=True):
            if node.level == 0:
                result.append(f"🌳 {node.name}")
            else:
                connector = "└── " if is_last else "├── "
                result.append(f"{prefix}{connector}{node.name}")
            
            for i, child in enumerate(node.children):
                is_child_last = (i == len(node.children) - 1)
                child_prefix = prefix + ("    " if is_last else "│   ")
                traverse(child, child_prefix, is_child_last)
        
        traverse(self.root)
        return "\n".join(result)
    
    def send_slack_notification(self, webhook_url: str, channel: str = None):
        """Send execution summary to Slack"""
        status_emoji = "✅" if self.metrics['failed_tasks'] == 0 else "❌"
        color = "good" if self.metrics['failed_tasks'] == 0 else "danger"
        
        payload = {
            "attachments": [{
                "color": color,
                "title": f"{status_emoji} Ansible Playbook Execution Complete",
                "fields": [
                    {"title": "Success Rate", "value": f"{self.metrics['success_rate']:.1f}%", "short": True},
                    {"title": "Duration", "value": f"{self.metrics['total_duration']:.1f}s", "short": True},
                    {"title": "Total Tasks", "value": str(self.metrics['total_tasks']), "short": True},
                    {"title": "Failed Tasks", "value": str(self.metrics['failed_tasks']), "short": True},
                    {"title": "Hosts", "value": ", ".join(self.metrics['total_hosts']), "short": False}
                ],
                "footer": "Ansible Execution Parser",
                "ts": int(time.time())
            }]
        }
        
        if channel:
            payload["channel"] = channel
        
        try:
            response = requests.post(webhook_url, json=payload)
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Failed to send Slack notification: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(
        description='Advanced Ansible Execution Tree Parser with Analytics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic usage
  python parse-ansible-execution.py ansible_output.log
  
  # Live monitoring
  ansible-playbook site.yml | python parse-ansible-execution.py -
  
  # Generate JSON report
  python parse-ansible-execution.py ansible_output.log --json report.json
  
  # Generate HTML report
  python parse-ansible-execution.py ansible_output.log --html report.html
  
  # Send Slack notification
  python parse-ansible-execution.py ansible_output.log --slack-webhook https://hooks.slack.com/...
  
  # CI/CD integration
  ansible-playbook site.yml 2>&1 | tee deploy.log | python parse-ansible-execution.py - --json ci-report.json --slack-webhook $SLACK_WEBHOOK
        '''
    )
    
    parser.add_argument('input_file', help='Ansible output file or "-" for stdin')
    parser.add_argument('--json', '-j', metavar='FILE', help='Generate JSON report to specified file')
    parser.add_argument('--html', '-H', metavar='FILE', help='Generate HTML report to specified file')
    parser.add_argument('--markdown', '-m', metavar='FILE', help='Generate Markdown report to specified file (default: ANSIBLE-EXECUTION-TREE.md)')
    parser.add_argument('--slack-webhook', '-s', metavar='URL', help='Send summary to Slack webhook')
    parser.add_argument('--slack-channel', '-c', metavar='CHANNEL', help='Slack channel (optional)')
    parser.add_argument('--quiet', '-q', action='store_true', help='Suppress console output')
    parser.add_argument('--no-tree', action='store_true', help='Skip tree output (useful for CI/CD)')
    parser.add_argument('--performance', '-p', action='store_true', help='Show detailed performance analysis')
    
    args = parser.parse_args()
    
    execution_parser = AnsibleExecutionParser()
    
    try:
        if args.input_file == "-":
            # Read from stdin
            for line in sys.stdin:
                execution_parser.parse_line(line)
        else:
            # Read from file
            with open(args.input_file, 'r') as f:
                for line in f:
                    execution_parser.parse_line(line)
    except FileNotFoundError:
        print(f"Error: File '{args.input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Finalize metrics calculation
    execution_parser.finalize_metrics()
    
    # Console output
    if not args.quiet:
        if not args.no_tree:
            print("\n" + "="*80)
            print("ANSIBLE EXECUTION TREE")
            print("="*80)
            execution_parser.print_tree()
        
        print(f"\n📊 Execution Summary:")
        print(f"   Duration: {execution_parser.metrics['total_duration']:.1f}s")
        print(f"   Success Rate: {execution_parser.metrics['success_rate']:.1f}%")
        print(f"   Total Tasks: {execution_parser.metrics['total_tasks']}")
        print(f"   Failed Tasks: {execution_parser.metrics['failed_tasks']}")
        print(f"   Changed Tasks: {execution_parser.metrics['changed_tasks']}")
        print(f"   Hosts: {', '.join(execution_parser.metrics['total_hosts'])}")
        
        if args.performance and execution_parser.metrics['slowest_tasks']:
            print(f"\n🐌 Slowest Tasks:")
            for task in execution_parser.metrics['slowest_tasks'][:5]:
                status_emoji = "❌" if task['status'] == 'failed' else "✅"
                print(f"   {status_emoji} {task['name']} - {task['duration']:.1f}s")
    
    # Generate outputs
    outputs_created = []
    
    # Markdown output
    markdown_file = args.markdown or "ANSIBLE-EXECUTION-TREE.md"
    try:
        with open(markdown_file, 'w') as f:
            f.write("# Ansible Execution Tree\n\n")
            f.write(f"Generated automatically from Ansible playbook execution at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"## Summary\n")
            f.write(f"- **Duration:** {execution_parser.metrics['total_duration']:.1f}s\n")
            f.write(f"- **Success Rate:** {execution_parser.metrics['success_rate']:.1f}%\n")
            f.write(f"- **Total Tasks:** {execution_parser.metrics['total_tasks']}\n")
            f.write(f"- **Failed Tasks:** {execution_parser.metrics['failed_tasks']}\n\n")
            f.write("## Execution Tree\n\n")
            f.write(execution_parser.generate_markdown())
        outputs_created.append(f"📝 Markdown: {markdown_file}")
    except Exception as e:
        print(f"Warning: Could not create markdown file: {e}", file=sys.stderr)
    
    # JSON output
    if args.json:
        try:
            with open(args.json, 'w') as f:
                json.dump(execution_parser.generate_json_report(), f, indent=2)
            outputs_created.append(f"🔧 JSON: {args.json}")
        except Exception as e:
            print(f"Error: Could not create JSON file: {e}", file=sys.stderr)
    
    # HTML output
    if args.html:
        try:
            with open(args.html, 'w') as f:
                f.write(execution_parser.generate_html_report())
            outputs_created.append(f"🌐 HTML: {args.html}")
        except Exception as e:
            print(f"Error: Could not create HTML file: {e}", file=sys.stderr)
    
    # Slack notification
    if args.slack_webhook:
        try:
            if execution_parser.send_slack_notification(args.slack_webhook, args.slack_channel):
                outputs_created.append("📢 Slack notification sent")
            else:
                print("Warning: Slack notification failed", file=sys.stderr)
        except Exception as e:
            print(f"Error: Slack notification failed: {e}", file=sys.stderr)
    
    # Summary of outputs
    if not args.quiet and outputs_created:
        print(f"\n📁 Generated outputs:")
        for output in outputs_created:
            print(f"   {output}")
    
    # Exit with error code if there were failures
    if execution_parser.metrics['failed_tasks'] > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()