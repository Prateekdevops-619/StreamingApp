#!/bin/bash
# CloudWatch Alarms for StreamingApp
REGION="eu-west-2"
CLUSTER="prateek-streamingapp-eks"
SNS_TOPIC=""  # Add SNS topic ARN here for email notifications

# High CPU alarm for EKS nodes
aws cloudwatch put-metric-alarm \
  --alarm-name "StreamingApp-HighCPU" \
  --alarm-description "EKS node CPU > 80%" \
  --namespace "AWS/EC2" \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region $REGION \
  --alarm-actions ${SNS_TOPIC} 2>/dev/null || true

# Log group for each service
for svc in frontend auth streaming admin chat; do
  aws logs create-log-group \
    --log-group-name "/streamingapp/${svc}" \
    --region $REGION 2>/dev/null || true
  aws logs put-retention-policy \
    --log-group-name "/streamingapp/${svc}" \
    --retention-in-days 7 \
    --region $REGION 2>/dev/null || true
  echo "Log group /streamingapp/${svc} ready"
done

# EKS control plane logs group (auto-created by EKS)
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/prateek-streamingapp-eks" \
  --region $REGION --query "logGroups[*].logGroupName" --output table
