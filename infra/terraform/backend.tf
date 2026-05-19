# Default backend — override per environment:
#   terraform init -backend-config=environments/<env>/backend.tf
#
# Bootstrap (one-time, run before first terraform init):
#   aws s3 mb s3://todo-tf-state-668076964228 --region us-east-1
#   aws s3api put-bucket-versioning --bucket todo-tf-state-668076964228 \
#     --versioning-configuration Status=Enabled

terraform {
  backend "s3" {
    bucket       = "todo-tf-state-668076964228"
    key          = "todo-fullstack/default.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
