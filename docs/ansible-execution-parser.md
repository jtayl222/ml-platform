# Ansible Execution Parser

Advanced Ansible playbook execution analysis tool with comprehensive analytics, multiple output formats, and CI/CD integration.

## Features

- **📊 Advanced Analytics**: Performance timing, success rates, failure analysis
- **🌳 Visual Tree Structure**: Hierarchical view of playbook execution
- **🔧 Multiple Output Formats**: JSON, HTML, Markdown
- **📢 Slack Integration**: Automated notifications with execution summaries
- **🚀 CI/CD Ready**: Exit codes, quiet mode, JSON output for automation
- **📈 Performance Insights**: Identify slowest tasks and bottlenecks

## Installation

No additional dependencies required beyond Python 3.7+. Optional dependencies:
- `requests` - For Slack notifications (install with `pip install requests`)

## Usage

### Basic Usage

```bash
# Parse Ansible output from file
python scripts/parse-ansible-execution.py ansible_output.log

# Live monitoring during playbook execution
ansible-playbook site.yml | python scripts/parse-ansible-execution.py -

# Generate JSON report for CI/CD
python scripts/parse-ansible-execution.py ansible_output.log --json report.json
```

### Advanced Usage

```bash
# Generate HTML report with interactive features
python scripts/parse-ansible-execution.py ansible_output.log --html report.html

# Send Slack notification with execution summary
python scripts/parse-ansible-execution.py ansible_output.log \
  --slack-webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  --slack-channel "#infrastructure"

# Performance analysis mode
python scripts/parse-ansible-execution.py ansible_output.log --performance

# CI/CD integration with multiple outputs
ansible-playbook site.yml 2>&1 | tee deploy.log | \
  python scripts/parse-ansible-execution.py - \
  --json ci-report.json \
  --slack-webhook $SLACK_WEBHOOK \
  --quiet
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `input_file` | Ansible output file or "-" for stdin |
| `--json, -j FILE` | Generate JSON report to specified file |
| `--html, -H FILE` | Generate HTML report to specified file |
| `--markdown, -m FILE` | Generate Markdown report (default: ANSIBLE-EXECUTION-TREE.md) |
| `--slack-webhook, -s URL` | Send summary to Slack webhook |
| `--slack-channel, -c CHANNEL` | Slack channel (optional) |
| `--quiet, -q` | Suppress console output |
| `--no-tree` | Skip tree output (useful for CI/CD) |
| `--performance, -p` | Show detailed performance analysis |

## Output Formats

### Console Output

```
================================================================================
ANSIBLE EXECUTION TREE
================================================================================
🌳 Ansible Playbook Execution
├── 🎭 PLAY: Deploy MLOps Platform
│   ├── 📋 TASK: Gather Facts
│   │   ├── ✅ OK: nuc8i5behs
│   │   └── ✅ OK: nuc10i3fnh
│   └── 📋 TASK: Deploy MLflow
│       ├── 🔄 CHANGED: nuc8i5behs
│       └── 🔄 CHANGED: nuc10i3fnh

📊 Execution Summary:
   Duration: 45.2s
   Success Rate: 100.0%
   Total Tasks: 15
   Failed Tasks: 0
   Changed Tasks: 8
   Hosts: nuc8i5behs, nuc10i3fnh
```

### JSON Output

```json
{
  "execution_summary": {
    "start_time": "2025-07-08T19:30:00.000Z",
    "end_time": "2025-07-08T19:30:45.200Z",
    "total_duration": 45.2,
    "success_rate": 100.0
  },
  "metrics": {
    "total_plays": 1,
    "total_tasks": 15,
    "total_hosts": ["nuc8i5behs", "nuc10i3fnh"],
    "failed_tasks": 0,
    "changed_tasks": 8,
    "slowest_tasks": [
      {
        "name": "Deploy MLflow",
        "duration": 12.3,
        "status": "success"
      }
    ]
  }
}
```

### HTML Output

Interactive HTML report with:
- Executive dashboard with key metrics
- Visual progress indicators
- Expandable execution tree
- Performance analysis charts
- Responsive design for mobile/desktop

### Slack Integration

Automated notifications include:
- ✅/❌ Status indicator
- Success rate percentage
- Total execution time
- Task counts (total, failed, changed)
- Host list
- Timestamp

## CI/CD Integration

### Exit Codes

- `0` - Success (no failed tasks)
- `1` - Failure (one or more failed tasks)

### GitHub Actions Example

```yaml
name: Deploy Infrastructure
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Deploy with Ansible
        run: |
          ansible-playbook -i inventory/production/hosts infrastructure/cluster/site.yml 2>&1 | \
          tee deploy.log | \
          python scripts/parse-ansible-execution.py - \
            --json deploy-report.json \
            --slack-webhook ${{ secrets.SLACK_WEBHOOK }} \
            --slack-channel "#deployments" \
            --quiet
      
      - name: Upload Reports
        uses: actions/upload-artifact@v2
        with:
          name: deployment-reports
          path: |
            deploy.log
            deploy-report.json
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Deploy') {
            steps {
                script {
                    def exitCode = sh(
                        script: '''
                            ansible-playbook site.yml 2>&1 | \
                            tee deploy.log | \
                            python scripts/parse-ansible-execution.py - \
                                --json "deploy-report-${BUILD_NUMBER}.json" \
                                --html "deploy-report-${BUILD_NUMBER}.html" \
                                --slack-webhook ${SLACK_WEBHOOK} \
                                --quiet
                        ''',
                        returnStatus: true
                    )
                    
                    if (exitCode != 0) {
                        error("Deployment failed")
                    }
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'deploy-report-*.json,deploy-report-*.html'
        }
    }
}
```

## Performance Analysis

The `--performance` flag provides detailed insights:

```bash
🐌 Slowest Tasks:
   ✅ Deploy MLflow - 12.3s
   ✅ Configure PostgreSQL - 8.7s
   ✅ Install K3s - 6.2s
   ✅ Setup MinIO - 4.1s
   ✅ Deploy Grafana - 3.8s
```

## Integration with Existing Tools

### Ansible Callback Plugins

For enhanced integration, consider using with Ansible callback plugins:

```ini
# ansible.cfg
[defaults]
stdout_callback = yaml
callback_whitelist = profile_tasks, timer
```

### Monitoring Integration

JSON output can be integrated with:
- **Prometheus**: Custom metrics from JSON
- **Grafana**: Dashboard with deployment trends
- **ELK Stack**: Centralized logging and analysis
- **Datadog**: Custom events and metrics

## Best Practices

### 1. Standardize Usage

Create a wrapper script for consistent usage:

```bash
#!/bin/bash
# scripts/ansible-with-analytics.sh

PLAYBOOK="$1"
ENVIRONMENT="$2"

ansible-playbook -i "inventory/${ENVIRONMENT}/hosts" "$PLAYBOOK" 2>&1 | \
tee "logs/deploy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log" | \
python scripts/parse-ansible-execution.py - \
  --json "reports/deploy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).json" \
  --slack-webhook "$SLACK_WEBHOOK" \
  --slack-channel "#infrastructure-${ENVIRONMENT}"
```

### 2. Historical Analysis

Store JSON reports for trend analysis:

```bash
# Store reports with timestamps
mkdir -p reports/$(date +%Y/%m)
python scripts/parse-ansible-execution.py ansible_output.log \
  --json "reports/$(date +%Y/%m)/deploy-$(date +%Y%m%d-%H%M%S).json"
```

### 3. Alert Thresholds

Set up alerts based on metrics:

```bash
# Example: Alert if deployment takes too long
DURATION=$(jq '.execution_summary.total_duration' deploy-report.json)
if (( $(echo "$DURATION > 300" | bc -l) )); then
    echo "⚠️  Deployment exceeded 5 minutes threshold"
fi
```

## Development

### Adding New Features

The script is designed for extensibility:

1. **New Output Formats**: Add methods to `AnsibleExecutionParser` class
2. **Additional Metrics**: Extend the `metrics` dictionary
3. **Notification Channels**: Add new methods similar to `send_slack_notification`

### Testing

Test with sample Ansible outputs:

```bash
# Test with sample output
python scripts/parse-ansible-execution.py test-data/sample-ansible-output.log --performance

# Test CI/CD integration
echo "Sample output" | python scripts/parse-ansible-execution.py - --json test.json --quiet
```

## Troubleshooting

### Common Issues

1. **Missing Dependencies**: Install with `pip install requests`
2. **Permissions**: Ensure script has execute permissions
3. **Encoding Issues**: Use UTF-8 encoding for log files
4. **Slack Webhook**: Verify webhook URL and permissions

### Debug Mode

For debugging, remove `--quiet` and add verbose output:

```bash
python -u scripts/parse-ansible-execution.py ansible_output.log --performance
```

## License

This tool is part of the ML Platform infrastructure and follows the same license terms as the main repository.