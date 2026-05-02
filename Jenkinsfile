pipeline {
    agent any

    environment {
        AWS_REGION      = 'eu-west-2'
        AWS_ACCOUNT_ID  = '975050024946'
        ECR_BASE        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        EKS_CLUSTER     = 'prateek-streamingapp-eks'
        K8S_NAMESPACE   = 'streamingapp'

        // ECR repository names
        ECR_FRONTEND    = "${ECR_BASE}/prateek-streamingapp/frontend"
        ECR_AUTH        = "${ECR_BASE}/prateek-streamingapp/auth"
        ECR_STREAMING   = "${ECR_BASE}/prateek-streamingapp/streaming"
        ECR_ADMIN       = "${ECR_BASE}/prateek-streamingapp/admin"
        ECR_CHAT        = "${ECR_BASE}/prateek-streamingapp/chat"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.GIT_BRANCH} | Commit: ${env.GIT_COMMIT?.take(7)}"
            }
        }

        stage('AWS Login & ECR Auth') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        aws configure set aws_access_key_id \$AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key \$AWS_SECRET_ACCESS_KEY
                        aws configure set region ${AWS_REGION}
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_BASE}
                    """
                }
            }
        }

        stage('Create ECR Repositories') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        for repo in prateek-streamingapp/frontend prateek-streamingapp/auth prateek-streamingapp/streaming prateek-streamingapp/admin prateek-streamingapp/chat; do
                            aws ecr describe-repositories --repository-names \$repo --region ${AWS_REGION} 2>/dev/null || \
                            aws ecr create-repository --repository-name \$repo --region ${AWS_REGION}
                        done
                    """
                }
            }
        }

        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        sh """
                            docker build \
                                --build-arg REACT_APP_AUTH_API_URL=/proxy/auth/api \
                                --build-arg REACT_APP_STREAMING_API_URL=/proxy/streaming/api/streaming \
                                --build-arg REACT_APP_STREAMING_PUBLIC_URL=/proxy/streaming \
                                --build-arg REACT_APP_ADMIN_API_URL=/proxy/admin/api/admin \
                                --build-arg REACT_APP_CHAT_API_URL=/proxy/chat/api/chat \
                                --build-arg REACT_APP_CHAT_SOCKET_URL="" \
                                -t ${ECR_FRONTEND}:${IMAGE_TAG} \
                                -t ${ECR_FRONTEND}:latest \
                                ./frontend
                        """
                    }
                }
                stage('Build Auth Service') {
                    steps {
                        sh """
                            docker build \
                                -t ${ECR_AUTH}:${IMAGE_TAG} \
                                -t ${ECR_AUTH}:latest \
                                ./backend/authService
                        """
                    }
                }
                stage('Build Streaming Service') {
                    steps {
                        sh """
                            docker build \
                                -t ${ECR_STREAMING}:${IMAGE_TAG} \
                                -t ${ECR_STREAMING}:latest \
                                -f ./backend/streamingService/Dockerfile \
                                ./backend
                        """
                    }
                }
                stage('Build Admin Service') {
                    steps {
                        sh """
                            docker build \
                                -t ${ECR_ADMIN}:${IMAGE_TAG} \
                                -t ${ECR_ADMIN}:latest \
                                -f ./backend/adminService/Dockerfile \
                                ./backend
                        """
                    }
                }
                stage('Build Chat Service') {
                    steps {
                        sh """
                            docker build \
                                -t ${ECR_CHAT}:${IMAGE_TAG} \
                                -t ${ECR_CHAT}:latest \
                                -f ./backend/chatService/Dockerfile \
                                ./backend
                        """
                    }
                }
            }
        }

        stage('Push Images to ECR') {
            parallel {
                stage('Push Frontend') {
                    steps {
                        sh "docker push ${ECR_FRONTEND}:${IMAGE_TAG} && docker push ${ECR_FRONTEND}:latest"
                    }
                }
                stage('Push Auth') {
                    steps {
                        sh "docker push ${ECR_AUTH}:${IMAGE_TAG} && docker push ${ECR_AUTH}:latest"
                    }
                }
                stage('Push Streaming') {
                    steps {
                        sh "docker push ${ECR_STREAMING}:${IMAGE_TAG} && docker push ${ECR_STREAMING}:latest"
                    }
                }
                stage('Push Admin') {
                    steps {
                        sh "docker push ${ECR_ADMIN}:${IMAGE_TAG} && docker push ${ECR_ADMIN}:latest"
                    }
                }
                stage('Push Chat') {
                    steps {
                        sh "docker push ${ECR_CHAT}:${IMAGE_TAG} && docker push ${ECR_CHAT}:latest"
                    }
                }
            }
        }

        stage('Configure kubectl') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        aws eks update-kubeconfig \
                            --name ${EKS_CLUSTER} \
                            --region ${AWS_REGION}
                        kubectl get nodes
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        # Namespace & secrets
                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/mongodb-secret.yaml
                        kubectl apply -f k8s/frontend-nginx-configmap.yaml

                        # MongoDB
                        kubectl apply -f k8s/mongodb-statefulset.yaml
                        kubectl rollout status statefulset/mongodb -n ${K8S_NAMESPACE} --timeout=300s

                        # Backend services — inject image tags
                        sed 's|IMAGE_PLACEHOLDER_AUTH|${ECR_AUTH}:${IMAGE_TAG}|g'           k8s/auth-deployment.yaml       | kubectl apply -f -
                        sed 's|IMAGE_PLACEHOLDER_STREAMING|${ECR_STREAMING}:${IMAGE_TAG}|g' k8s/streaming-deployment.yaml  | kubectl apply -f -
                        sed 's|IMAGE_PLACEHOLDER_ADMIN|${ECR_ADMIN}:${IMAGE_TAG}|g'         k8s/admin-deployment.yaml      | kubectl apply -f -
                        sed 's|IMAGE_PLACEHOLDER_CHAT|${ECR_CHAT}:${IMAGE_TAG}|g'           k8s/chat-deployment.yaml       | kubectl apply -f -

                        # Frontend
                        sed 's|IMAGE_PLACEHOLDER_FRONTEND|${ECR_FRONTEND}:${IMAGE_TAG}|g'   k8s/frontend-deployment.yaml   | kubectl apply -f -

                        # Autoscalers
                        kubectl apply -f k8s/hpa.yaml
                    """
                }
            }
        }

        stage('Wait for Rollout') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        kubectl rollout status deployment/auth-service       -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/streaming-service  -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/admin-service      -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/chat-service       -n ${K8S_NAMESPACE} --timeout=180s
                        kubectl rollout status deployment/frontend           -n ${K8S_NAMESPACE} --timeout=180s
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        # Wait for LoadBalancer external IP
                        echo "Waiting for frontend LoadBalancer..."
                        for i in \$(seq 1 20); do
                            LB_HOST=\$(kubectl get svc frontend-service -n ${K8S_NAMESPACE} \
                                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
                            [ -n "\$LB_HOST" ] && break
                            echo "  attempt \$i/20 — waiting 15s..."
                            sleep 15
                        done

                        if [ -z "\$LB_HOST" ]; then
                            echo "WARNING: LoadBalancer hostname not yet assigned — skipping smoke test"
                            exit 0
                        fi

                        echo "Frontend LB: \$LB_HOST"
                        # Health checks via in-cluster pods
                        kubectl exec -n ${K8S_NAMESPACE} \
                            \$(kubectl get pod -n ${K8S_NAMESPACE} -l app=auth-service -o jsonpath='{.items[0].metadata.name}') \
                            -- wget -qO- http://localhost:3001/health || true

                        kubectl exec -n ${K8S_NAMESPACE} \
                            \$(kubectl get pod -n ${K8S_NAMESPACE} -l app=streaming-service -o jsonpath='{.items[0].metadata.name}') \
                            -- wget -qO- http://localhost:3002/api/health || true
                    """
                }
            }
        }

        stage('Deployment Summary') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-cred',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        echo "============================================"
                        echo "  StreamingApp Deployment #${BUILD_NUMBER}"
                        echo "============================================"
                        kubectl get pods      -n ${K8S_NAMESPACE}
                        kubectl get svc       -n ${K8S_NAMESPACE}
                        kubectl get hpa       -n ${K8S_NAMESPACE}
                        echo ""
                        FRONTEND_LB=\$(kubectl get svc frontend-service -n ${K8S_NAMESPACE} \
                            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
                        echo "  App URL: http://\$FRONTEND_LB"
                        echo "============================================"
                    """
                }
            }
        }
    }

    post {
        success {
            echo "StreamingApp deployed successfully — Build #${BUILD_NUMBER}"
        }
        failure {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                              credentialsId: 'aws-cred',
                              accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                              secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                sh """
                    echo "Deployment failed — rolling back..."
                    kubectl rollout undo deployment/auth-service      -n ${K8S_NAMESPACE} || true
                    kubectl rollout undo deployment/streaming-service -n ${K8S_NAMESPACE} || true
                    kubectl rollout undo deployment/admin-service     -n ${K8S_NAMESPACE} || true
                    kubectl rollout undo deployment/chat-service      -n ${K8S_NAMESPACE} || true
                    kubectl rollout undo deployment/frontend          -n ${K8S_NAMESPACE} || true
                """
            }
        }
        always {
            sh """
                docker rmi ${ECR_FRONTEND}:${IMAGE_TAG}   || true
                docker rmi ${ECR_AUTH}:${IMAGE_TAG}       || true
                docker rmi ${ECR_STREAMING}:${IMAGE_TAG}  || true
                docker rmi ${ECR_ADMIN}:${IMAGE_TAG}      || true
                docker rmi ${ECR_CHAT}:${IMAGE_TAG}       || true
            """
        }
    }
}
