pipeline {
    agent any

    environment {
        AWS_REGION      = 'us-east-1'
        ECR_REPO        = '668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial'
        ECS_CLUSTER     = 'todo-cluster'
        ECS_SERVICE     = 'todo-task-service-zp9225mz'
        IMAGE_TAG       = "v${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build -t ${ECR_REPO}:${IMAGE_TAG} .
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REPO}
                    
                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_REPO}:latest
                """
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh """
                    # Get current task definition
                    TASK_DEF=\$(aws ecs describe-services \
                        --cluster ${ECS_CLUSTER} \
                        --services ${ECS_SERVICE} \
                        --region ${AWS_REGION} \
                        --query 'services[0].taskDefinition' \
                        --output text)

                    # Get full task definition JSON, strip unneeded fields
                    TASK_DEF_JSON=\$(aws ecs describe-task-definition \
                        --task-definition \$TASK_DEF \
                        --region ${AWS_REGION} \
                        --query 'taskDefinition' \
                        --output json | \
                        jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

                    # Update image in task definition
                    NEW_TASK_DEF=\$(echo \$TASK_DEF_JSON | \
                        jq --arg IMAGE "${ECR_REPO}:${IMAGE_TAG}" \
                        '.containerDefinitions[0].image = \$IMAGE')

                    # Register new task definition revision
                    NEW_TASK_ARN=\$(aws ecs register-task-definition \
                        --region ${AWS_REGION} \
                        --cli-input-json "\$NEW_TASK_DEF" \
                        --query 'taskDefinition.taskDefinitionArn' \
                        --output text)

                    # Update service with new task definition
                    aws ecs update-service \
                        --cluster ${ECS_CLUSTER} \
                        --service ${ECS_SERVICE} \
                        --task-definition \$NEW_TASK_ARN \
                        --region ${AWS_REGION}

                    echo "Deployed \$NEW_TASK_ARN"
                """
            }
        }

        stage('Cleanup') {
            steps {
                sh """
                    docker rmi ${ECR_REPO}:${IMAGE_TAG} || true
                    docker rmi ${ECR_REPO}:latest || true
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed. Image ${IMAGE_TAG} deployed to ECS."
        }
        failure {
            echo "Pipeline failed at stage. Check logs above."
        }
    }
}
