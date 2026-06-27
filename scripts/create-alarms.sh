#!/bin/bash
# Script para crear 4 alarmas CloudWatch para ProductosAPI
# Uso: ./scripts/create-alarms.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.env"

echo "============================================"
echo " Creando alarmas CloudWatch para $APP_NAME"
echo "============================================"
echo ""

# 1. CPU > 80% (EC2)
echo "[1/4] productosapi-cpu-high - CPU > 80% por 5 min"
aws cloudwatch put-metric-alarm \
  --alarm-name "productosapi-cpu-high" \
  --alarm-description "Alarma cuando CPU > 80% por 5 minutos" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$EC2_INSTANCE_ID \
  --region $AWS_REGION
echo "  Creada"

# 2. Memory > 85% (CWAgent)
echo "[2/4] productosapi-memory-high - Memoria > 85% por 5 min"
aws cloudwatch put-metric-alarm \
  --alarm-name "productosapi-memory-high" \
  --alarm-description "Alarma cuando memoria > 85% por 5 minutos" \
  --metric-name mem_used_percent \
  --namespace CWAgent \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$EC2_INSTANCE_ID \
  --region $AWS_REGION
echo "  Creada"

# 3. Error spike > 10
echo "[3/4] productosapi-error-spike - Errores > 10 en 5 min"
aws cloudwatch put-metric-alarm \
  --alarm-name "productosapi-error-spike" \
  --alarm-description "Alarma cuando errores > 10 en 5 minutos" \
  --metric-name productosapi.errors.total \
  --namespace $CW_NAMESPACE \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --region $AWS_REGION
echo "  Creada"

# 4. UnhealthyHost > 0
echo "[4/4] productosapi-unhealthy-host - UnhealthyHost > 0 por 2 min"
aws cloudwatch put-metric-alarm \
  --alarm-name "productosapi-unhealthy-host" \
  --alarm-description "Alarma cuando UnhealthyHostCount > 0 por 2 minutos" \
  --metric-name UnhealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 120 \
  --evaluation-periods 1 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=TargetGroup,Value=$TARGET_GROUP_NAME Name=LoadBalancer,Value=$ALB_NAME \
  --region $AWS_REGION
echo "  Creada"

echo ""
echo "============================================"
echo " 4 alarmas creadas exitosamente"
echo "============================================"
