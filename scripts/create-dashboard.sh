#!/bin/bash
# Script para crear dashboard CloudWatch ProductosAPI-EP3 con 7 widgets
# Uso: ./scripts/create-dashboard.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.env"

DASHBOARD_BODY=$(cat <<EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0, "y": 0,
            "width": 12, "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", { "stat": "Average" } ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$AWS_REGION",
                "title": "1. CPU Usage",
                "view": "timeSeries",
                "stacked": false
            }
        },
        {
            "type": "metric",
            "x": 12, "y": 0,
            "width": 12, "height": 6,
            "properties": {
                "metrics": [
                    [ "CWAgent", "mem_used_percent", { "stat": "Average" } ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$AWS_REGION",
                "title": "2. Memory Usage",
                "view": "timeSeries",
                "stacked": false
            }
        },
        {
            "type": "metric",
            "x": 0, "y": 6,
            "width": 8, "height": 6,
            "properties": {
                "metrics": [
                    [ "$CW_NAMESPACE", "DeploymentDuration", { "stat": "Average" } ]
                ],
                "period": 60,
                "stat": "Average",
                "region": "$AWS_REGION",
                "title": "3. Deployment Duration",
                "view": "singleValue"
            }
        },
        {
            "type": "metric",
            "x": 8, "y": 6,
            "width": 8, "height": 6,
            "properties": {
                "metrics": [
                    [ "$CW_NAMESPACE", "TestCoverage", { "stat": "Average" } ]
                ],
                "period": 60,
                "stat": "Average",
                "region": "$AWS_REGION",
                "title": "4. Test Coverage",
                "view": "gauge",
                "setPeriodToTimeRange": true
            }
        },
        {
            "type": "metric",
            "x": 16, "y": 6,
            "width": 8, "height": 6,
            "properties": {
                "metrics": [
                    [ "$CW_NAMESPACE", "productosapi.errors.total", { "stat": "Sum", "label": "Errors" } ],
                    [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", { "stat": "Sum", "label": "5XX" } ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "$AWS_REGION",
                "title": "5. Error Rate",
                "view": "timeSeries",
                "stacked": true
            }
        },
        {
            "type": "metric",
            "x": 0, "y": 12,
            "width": 12, "height": 6,
            "properties": {
                "metrics": [
                    [ "$CW_NAMESPACE", "productosapi.requests.total", { "stat": "Sum" } ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "$AWS_REGION",
                "title": "6. Request Count",
                "view": "timeSeries",
                "stacked": false
            }
        },
        {
            "type": "metric",
            "x": 12, "y": 12,
            "width": 12, "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "HealthyHostCount", { "stat": "Average" } ]
                ],
                "period": 60,
                "stat": "Average",
                "region": "$AWS_REGION",
                "title": "7. Service Availability",
                "view": "singleValue"
            }
        }
    ]
}
EOF
)

echo "============================================"
echo " Creando dashboard: $CW_DASHBOARD_NAME"
echo "============================================"

aws cloudwatch put-dashboard \
  --dashboard-name "$CW_DASHBOARD_NAME" \
  --dashboard-body "$DASHBOARD_BODY" \
  --region $AWS_REGION

echo ""
echo " Dashboard $CW_DASHBOARD_NAME creado exitosamente"
echo " 7 widgets configurados:"
echo "  1. CPU Usage (EC2)"
echo "  2. Memory Usage (CWAgent)"
echo "  3. Deployment Duration"
echo "  4. Test Coverage"
echo "  5. Error Rate"
echo "  6. Request Count"
echo "  7. Service Availability"
echo "============================================"
