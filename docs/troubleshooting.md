# Troubleshooting — Problems Encountered & Solutions

This document records every significant problem hit during the initial deployment of this project. Each entry includes the exact error, the root cause, and the steps taken to fix it.

---

## Table of Contents

1. [Terraform `localss` typo in ALB module](#1-terraform-localss-typo-in-alb-module)
2. [ALB module — wrong security group and subnet attribute names](#2-alb-module--wrong-security-group-and-subnet-attribute-names)
3. [ALB module — `redirects` block instead of `redirect`](#3-alb-module--redirects-block-instead-of-redirect)
4. [ASG module — `autoscalling` typos throughout](#4-asg-module--autoscalling-typos-throughout)
5. [ASG module — `filters = [...]` syntax rejected](#5-asg-module--filters--syntax-rejected)
6. [Security groups — `ip_protocol` and non-list `cidr_blocks`](#6-security-groups--ip_protocol-and-non-list-cidr_blocks)
7. [Security group — `aws_security_group` used instead of `aws_security_group_rule`](#7-security-group--aws_security_group-used-instead-of-aws_security_group_rule)
8. [EKS module — dangling `tags {}` block outside any resource](#8-eks-module--dangling-tags--block-outside-any-resource)
9. [S3 lifecycle rule — missing `filter {}` block](#9-s3-lifecycle-rule--missing-filter--block)
10. [Non-ASCII em-dashes in security group descriptions rejected by AWS](#10-non-ascii-em-dashes-in-security-group-descriptions-rejected-by-aws)
11. [RDS — Performance Insights not supported on db.t3.micro](#11-rds--performance-insights-not-supported-on-dbt3micro)
12. [Route53 — `count` depends on unknown value during plan](#12-route53--count-depends-on-unknown-value-during-plan)
13. [Helm provider chicken-and-egg with EKS](#13-helm-provider-chicken-and-egg-with-eks)
14. [CloudWatch log groups already existed in AWS](#14-cloudwatch-log-groups-already-existed-in-aws)
15. [IAM roles and policies already existed in AWS](#15-iam-roles-and-policies-already-existed-in-aws)
16. [Route53 CNAME record conflicted with new A alias record](#16-route53-cname-record-conflicted-with-new-a-alias-record)
17. [ALB controller CrashLoopBackOff — missing VPC ID and region](#17-alb-controller-crashloopbackoff--missing-vpc-id-and-region)
18. [Webhook `context deadline exceeded` — wrong node security group](#18-webhook-context-deadline-exceeded--wrong-node-security-group)
19. [ALB controller `AccessDenied: DescribeListenerAttributes`](#19-alb-controller-accessdenied-describelistenerattributes)
20. [Backend pods crashing — wrong DB_HOST and DB_PASSWORD in Secret](#20-backend-pods-crashing--wrong-db_host-and-db_password-in-secret)

---

## 1. Terraform `localss` typo in ALB module

**Error:**
```
Error: Unsupported block type
  on modules/alb/main.tf line 1:
  localss {
```

**Root cause:** `locals` was misspelled as `localss`. Additionally, references throughout the file used `${locals.name}` instead of the correct `${local.name}` (the block is `locals {}` but the reference keyword is `local.`).

**Fix:**
```hcl
# Wrong
localss {
  name = "${var.project}-${var.environment}"
}
resource "..." {
  name = "${locals.name}-alb"
}

# Correct
locals {
  name = "${var.project}-${var.environment}"
}
resource "..." {
  name = "${local.name}-alb"
}
```

---

## 2. ALB module — wrong security group and subnet attribute names

**Error:**
```
Error: Unsupported argument
  on modules/alb/main.tf:
  "security_group_id": argument not supported here
  "subnet": argument not supported here
```

**Root cause:** The `aws_lb` resource uses `security_groups` (a list) and `subnets` (a list), not singular forms.

**Fix:**
```hcl
# Wrong
resource "aws_lb" "main" {
  security_group_id = var.alb_sg_id
  subnet            = var.public_subnet_ids
}

# Correct
resource "aws_lb" "main" {
  security_groups = [var.alb_sg_id]
  subnets         = var.public_subnet_ids
}
```

---

## 3. ALB module — `redirects` block instead of `redirect`

**Error:**
```
Error: Unsupported block type
  on modules/alb/main.tf:
  redirects {
```

**Root cause:** The action block for HTTP→HTTPS redirect uses `redirect {}` (singular), not `redirects {}`.

**Fix:**
```hcl
# Wrong
action {
  type = "redirect"
  redirects {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}

# Correct
action {
  type = "redirect"
  redirect {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}
```

---

## 4. ASG module — `autoscalling` typos throughout

**Error:**
```
Error: Invalid resource type
  on modules/asg/main.tf:
  resource "aws_autoscalling_policy" "cpu"
```

**Root cause:** The module was written with `autoscalling` (double-l) throughout. The correct AWS provider resource names use `autoscaling` (single-l).

**Affected resources:**
- `aws_autoscalling_groups` → `aws_autoscaling_groups`
- `aws_autoscalling_policy` → `aws_autoscaling_policy`
- `predefined_metric_type = "ASGAverageCPUAutoscallization"` → `"ASGAverageCPUUtilization"`
- `predefied_metric_specification` → `predefined_metric_specification`
- `locals.name` → `local.name`

**Fix:** Global find-and-replace of `autoscalling` → `autoscaling` across the file, plus fixing the metric name and `locals.` → `local.` references.

---

## 5. ASG module — `filters = [...]` syntax rejected

**Error:**
```
Error: Unsupported argument
  on modules/asg/main.tf:
  filters = [
```

**Root cause:** The `aws_autoscaling_groups` data source does not accept a `filters` list argument. It uses separate `filter {}` blocks.

**Fix:**
```hcl
# Wrong
data "aws_autoscaling_groups" "eks_nodes" {
  filters = [
    { name = "tag:eks:cluster-name" values = [var.cluster_name] },
    { name = "tag:eks:nodegroup-name" values = [var.node_group_name] }
  ]
}

# Correct
data "aws_autoscaling_groups" "eks_nodes" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [var.node_group_name]
  }
}
```

---

## 6. Security groups — `ip_protocol` and non-list `cidr_blocks`

**Error:**
```
Error: Unsupported argument "ip_protocol"
Error: Incorrect attribute value type — "0.0.0.0/0" (string) cannot be used as cidr_blocks
```

**Root cause:** The `aws_security_group` inline `ingress`/`egress` blocks use `protocol` (not `ip_protocol`) and `cidr_blocks` must be a list, not a plain string.

`ip_protocol` is the attribute name used in the standalone `aws_vpc_security_group_ingress_rule` resource — a different resource type.

**Fix:**
```hcl
# Wrong (inline ingress block)
ingress {
  ip_protocol = "-1"
  cidr_blocks = "0.0.0.0/0"
}

# Correct (inline ingress block)
ingress {
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

---

## 7. Security group — `aws_security_group` used instead of `aws_security_group_rule`

**Error:**
```
Error: Unsupported argument
  on modules/security-groups/main.tf:
  source_security_group_id is not a valid argument for aws_security_group
```

**Root cause:** The rule that allows ALB traffic to reach EKS nodes (`alb_to_nodes`) was mistakenly written as an `aws_security_group` resource instead of an `aws_security_group_rule` resource. Security groups cannot reference other security groups in their inline blocks — cross-SG references require a standalone `aws_security_group_rule`.

**Fix:**
```hcl
# Wrong
resource "aws_security_group" "alb_to_nodes" {
  source_security_group_id = aws_security_group.alb.id
  ...
}

# Correct
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.alb.id
  description              = "ALB to EKS node port"
}
```

---

## 8. EKS module — dangling `tags {}` block outside any resource

**Error:**
```
Error: Unsupported block type
  on modules/eks/main.tf line 315:
  tags {
```

**Root cause:** A stray `tags {}` block appeared after the last `}` that closed the final resource. It was outside any resource and Terraform rejected it as a top-level block.

**Fix:** Deleted the orphaned block (lines 314–318 of the original file).

---

## 9. S3 lifecycle rule — missing `filter {}` block

**Error:**
```
Error: Missing required argument
  The argument "filter" is required for aws_s3_bucket_lifecycle_configuration rule
```

**Root cause:** AWS requires every S3 lifecycle rule to have a `filter {}` block specifying which objects the rule applies to. An empty `filter {}` means "apply to all objects."

**Fix:**
```hcl
rule {
  id     = "abort-incomplete-multipart"
  status = "Enabled"

  filter {}   # apply to all objects

  abort_incomplete_multipart_upload {
    days_after_initiation = 7
  }
}
```

---

## 10. Non-ASCII em-dashes in security group descriptions rejected by AWS

**Error:**
```
Error: creating Security Group: InvalidParameterValue: Invalid description
  description = "EKS nodes — allow self"
```

**Root cause:** The `—` character (em-dash, Unicode U+2014) is not in the ASCII character set. AWS security group descriptions only accept printable ASCII characters (letters, numbers, spaces, and `_.:/-`).

**Fix:** Replaced all em-dashes with ASCII hyphens (`-`) in all security group description strings.

---

## 11. RDS — Performance Insights not supported on db.t3.micro

**Error:**
```
Error: modifying RDS DB Instance: InvalidParameterCombination:
  Performance Insights is not supported for DB instance class db.t3.micro
```

**Root cause:** AWS Performance Insights requires `db.t3.small` or larger. The dev environment uses `db.t3.micro` to minimise cost.

**Fix:**
```hcl
# modules/rds/main.tf
performance_insights_enabled = false
```

Performance Insights is supported in the prod tfvars where `db_instance_class = "db.t3.small"`.

---

## 12. Route53 — `count` depends on unknown value during plan

**Error:**
```
Error: Invalid count argument
  The "count" value depends on resource attributes that cannot be determined
  until apply, so Terraform cannot predict how many instances will be created.
```

**Root cause:** The Route53 record was written with `count = var.alb_dns_name != "" ? 1 : 0`. Because `alb_dns_name` was derived from another resource's output (not a static variable), its value was unknown at plan time — Terraform cannot evaluate the conditional.

**Fix:** Removed the conditional count entirely. The Route53 record is always created:

```hcl
resource "aws_route53_record" "app" {
  # removed: count = var.alb_dns_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain}"
  type    = "A"
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
```

---

## 13. Helm provider chicken-and-egg with EKS

**Error:**
```
Error: Kubernetes cluster unreachable: the server doesn't have a resource type "helmrelease"
```
or
```
Error: configuring Terraform AWS Provider: no valid credential sources found
```

**Root cause:** The Terraform configuration included a `provider "helm"` block that needed the EKS cluster endpoint and certificate to connect. But those values are only available after the EKS cluster is created — which happens during the same `terraform apply`. Terraform evaluates all providers before running any resources, creating a deadlock.

**Fix:** Removed the `provider "helm"` block and all `helm_release` resources from Terraform entirely. The Cluster Autoscaler is now installed manually via Helm CLI after the EKS cluster is up:

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=todo-tf-cluster-dev \
  --set awsRegion=us-east-1 \
  --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<autoscaler-role-arn>
```

---

## 14. CloudWatch log groups already existed in AWS

**Error:**
```
Error: creating CloudWatch Logs Log Group: ResourceAlreadyExistsException:
  The specified log group already exists: /aws/eks/todo-tf-cluster-dev/cluster
```

**Root cause:** EKS automatically creates its own log group when control plane logging is enabled. When Terraform tries to create the same log group, AWS rejects it.

**Fix:** Import the existing log groups into Terraform state so Terraform adopts them instead of creating new ones:

```bash
terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.eks_cluster \
  /aws/eks/todo-tf-cluster-dev/cluster

terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.app \
  /todo/dev/application
```

After import, `terraform plan` shows no changes for these resources.

---

## 15. IAM roles and policies already existed in AWS

**Error:**
```
Error: creating IAM Role: EntityAlreadyExists: Role with name todo-dev-eks-cluster-role already exists.
Error: creating IAM Policy: EntityAlreadyExists: A policy called todo-dev-alb-controller-policy already exists.
```

**Root cause:** A previous interrupted `terraform apply` (or manual AWS console work) had already created these IAM resources. Terraform's state file didn't know they existed, so it tried to create them again.

**Fix:** Import each resource into state:

```bash
# EKS cluster role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_cluster todo-dev-eks-cluster-role

# EKS node role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_nodes todo-dev-eks-node-role

# EBS CSI driver role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.ebs_csi todo-dev-ebs-csi-role

# ALB controller role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.alb_controller todo-dev-alb-controller-role

# ALB controller policy (import by ARN)
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_policy.alb_controller \
  arn:aws:iam::668076964228:policy/todo-dev-alb-controller-policy
```

---

## 16. Route53 CNAME record conflicted with new A alias record

**Error:**
```
Error: [ERR]: Error building changeset: InvalidChangeBatch:
  RRSet of type CNAME with DNS name www.ankit.services. is not permitted at apex in zone ankit.services.
```
or simply the plan failing because an existing CNAME `www.ankit.services` prevented creating an A record.

**Root cause:** During an earlier attempt, the ALB controller had auto-created a CNAME record pointing `www.ankit.services` to the controller-managed ALB DNS name. Terraform's Route53 module was trying to create an A alias record at the same name — two records of different types at the same name conflict.

**Fix:** Manually deleted the old CNAME record via AWS CLI:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z07812883CC72HQVS0WSK \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "www.ankit.services.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "k8s-default-todoingr-096e8f96c2-1251263405.us-east-1.elb.amazonaws.com"}]
      }
    }]
  }'
```

Then re-ran `terraform apply` to create the correct A alias record.

---

## 17. ALB controller CrashLoopBackOff — missing VPC ID and region

**Symptom:**
```
$ kubectl get pods -n kube-system
NAME                                           READY   STATUS             RESTARTS
aws-load-balancer-controller-xxx               0/1     CrashLoopBackOff   5

$ kubectl logs -n kube-system deployment/aws-load-balancer-controller
level=error msg="VPC ID must be specified"
```

**Root cause:** The Helm install command was missing required values. The ALB controller needs to know which VPC to manage and which AWS region it is running in. Without these, it crashes on startup.

**Fix:** Reinstall with the missing flags:

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=todo-tf-cluster-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=vpc-045b7a536d94660d0 \
  --set region=us-east-1
```

---

## 18. Webhook `context deadline exceeded` — wrong node security group

**Symptom:**
```
$ kubectl apply -f app/k8s/
Error from server (InternalError): error when creating "deployment.yaml":
  Internal error occurred: failed calling webhook "mpod.elbv2.k8s.aws":
  Post "https://aws-load-balancer-webhook-service.kube-system.svc:443/mutate-v1-pod":
  context deadline exceeded
```

**Root cause:** The Kubernetes API server routes webhook calls through the cluster's internal network. The webhook pod lives on a node with security group `sg-04f784e2a0b0c0f10` (applied by the initial failed Terraform apply). However, Terraform's security group rules were written to a new SG `sg-0910a9a61b664d82d` created by a later apply. The cluster's security group `sg-0d1c831b59c30df03` had no inbound rules allowing it to reach port 443 on the actual node SG.

**Root cause in plain English:** Nodes got their SG from the first (interrupted) Terraform apply. Terraform's rules went into a different SG from the second apply. The control plane couldn't reach the nodes on ports 443 (webhooks) or 10250 (kubelet).

**Fix:** Manually added the required rules to the actual node SG (`sg-04f784e2a0b0c0f10`) from the cluster SG (`sg-0d1c831b59c30df03`):

```bash
# Allow kubelet API (port 10250)
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 10250 \
  --source-group sg-0d1c831b59c30df03

# Allow webhook HTTPS (port 443)
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 443 \
  --source-group sg-0d1c831b59c30df03

# Allow high ports (1025-65535) for NodePort and ephemeral traffic
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 1025-65535 \
  --source-group sg-0d1c831b59c30df03
```

**Long-term fix:** Ensure Terraform manages only one node SG and does not create a second one during re-apply. Or use `terraform state rm` and re-import the correct SG so state and reality align.

---

## 19. ALB controller `AccessDenied: DescribeListenerAttributes`

**Symptom:**
```
$ kubectl logs -n kube-system deployment/aws-load-balancer-controller
AccessDenied: User: arn:aws:sts::668076964228:assumed-role/todo-dev-alb-controller-role/...
  is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes
  on resource: arn:aws:elasticloadbalancing:...
```

**Root cause:** The IAM policy file (`alb-controller-policy.json`) was based on an older version of the AWS Load Balancer Controller. Version 3.3.0+ requires the `elasticloadbalancing:DescribeListenerAttributes` permission, which was not in the original policy.

**Fix (immediate — add permission to existing policy):**

```bash
# Get current policy ARN
POLICY_ARN=$(aws iam list-policies --query \
  "Policies[?PolicyName=='todo-dev-alb-controller-policy'].Arn" \
  --output text)

# Create a new policy version with the added permission
aws iam create-policy-version \
  --policy-arn $POLICY_ARN \
  --policy-document file://updated-policy.json \
  --set-as-default
```

**Fix (permanent — update the policy file):**
Added `"elasticloadbalancing:DescribeListenerAttributes"` to the `Action` list in `infra/terraform/modules/eks/alb-controller-policy.json`.

The controller recovers automatically after the IAM update — no pod restart needed.

---

## 20. Backend pods crashing — wrong DB_HOST and DB_PASSWORD in Secret

**Symptom 1:**
```
$ kubectl logs -n todo deployment/todo-backend
Error: getaddrinfo ENOTFOUND todo-db
```

**Root cause 1:** The `DB_HOST` value in `app/k8s/secret.yaml` was base64-encoded `todo-db` (a placeholder from earlier). The actual RDS endpoint created by Terraform is `todo-db-dev.c23qc6e80bp5.us-east-1.rds.amazonaws.com`.

**Fix:** Re-encode the correct hostname:
```bash
terraform -chdir=infra/terraform output -raw rds_endpoint | cut -d: -f1 | base64
# → dG9kby1kYi1kZXYuYzIzcWM2ZTgwYnA1LnVzLWVhc3QtMS5yZHMuYW1hem9uYXdzLmNvbQ==
```

Update `secret.yaml` with the new value.

---

**Symptom 2:**
```
$ kubectl logs -n todo deployment/todo-backend
Error: Access denied for user 'todo_user'@'...' (using password: YES)
```

**Root cause 2:** The initial `DB_PASSWORD` in the Secret was `rootpass` (a placeholder). The RDS master password had been set via `TF_VAR_rds_password` but the Secret was never updated to match. Additionally, an earlier attempt used `tododev` (7 characters) which AWS RDS rejected — RDS requires a minimum 8-character password.

**Fix:**

1. Reset the RDS master password to a valid value (minimum 8 characters):
```bash
aws rds modify-db-instance \
  --db-instance-identifier todo-db-dev \
  --master-user-password tododev1 \
  --apply-immediately
```

2. Wait ~60 seconds for the password change to propagate.

3. Re-encode the new password and update the Secret:
```bash
echo -n "tododev1" | base64
# → dG9kb2RldjE=
```

4. Apply the updated Secret:
```bash
kubectl apply -f app/k8s/secret.yaml
kubectl rollout restart deployment/todo-backend -n todo
```

---

## Key Lessons

| # | Lesson |
|---|--------|
| 1–4 | Small typos in Terraform (double-l, wrong prefix) cause cryptic errors — validate with `terraform validate` before apply |
| 5–7 | Check the AWS provider documentation for exact attribute names — the Terraform registry docs are authoritative |
| 8 | Every `{}` block must be inside a resource; stray top-level blocks break the whole file |
| 10 | AWS APIs only accept printable ASCII — copy-pasting from word processors introduces invisible characters |
| 11 | Instance class constraints exist for many AWS features — check compatibility before enabling |
| 12–13 | Terraform `count` and provider blocks cannot depend on values unknown at plan time |
| 14–16 | When re-running Terraform on an account that already has resources, `terraform import` is the right tool — never delete-and-recreate manually managed resources |
| 17 | Read the controller's startup logs before assuming the issue is network or IAM — the error message is usually specific |
| 18 | Security groups must match the actual SG assigned to nodes, not the SG Terraform thinks it assigned |
| 19 | Keep IAM policies up to date with the controller version — new permissions are added in minor releases |
| 20 | Always encode real values in Secrets before deploying — placeholder base64 strings will silently connect to nonexistent hosts |
