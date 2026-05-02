# StreamingApp

A production-grade video streaming platform built on a MERN microservice architecture — featuring S3-backed adaptive playback, real-time watch-party chat, a dedicated admin portal, and a fully automated Jenkins CI/CD pipeline that deploys to Amazon EKS.

[![Jenkins](https://img.shields.io/badge/Jenkins-Declarative%20Pipeline-D24939?logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![Docker](https://img.shields.io/badge/Docker-Multi--stage-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS%201.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-eu--west--2-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![MongoDB](https://img.shields.io/badge/MongoDB-6.0-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)

---

## Table of Contents

- [Overview](#overview)
- [Microservice Architecture](#microservice-architecture)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Environment Configuration](#environment-configuration)
- [Running Locally](#running-locally)
- [CI/CD Pipeline](#cicd-pipeline)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Jenkins Access](#jenkins-access)
- [Feature Highlights](#feature-highlights)
- [License](#license)

---

## Overview

StreamingApp lets users browse a video catalogue, stream content via signed S3 URLs, and chat live with other viewers — all from a single React SPA. Administrators manage the content library through a dedicated microservice and dashboard.

The entire platform ships with a **Jenkins declarative pipeline** that builds 5 Docker images in parallel, pushes them to **Amazon ECR**, and deploys to a managed **Amazon EKS** cluster — with automatic rollback on failure.

---

## Microservice Architecture

```
                          ┌──────────────────────────────────┐
                          │         React Frontend           │
                          │    (Nginx reverse proxy :80)     │
                          └──────┬───────────────────────────┘
                                 │  /proxy/<service>/
               ┌─────────────────┼──────────────────────────────────────┐
               │                 │                  │                    │
               ▼                 ▼                  ▼                    ▼
     ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
     │ authService  │  │streamingService│  │  adminService   │  │ chatService  │
     │   :3001      │  │    :3002      │  │     :3003        │  │   :3004      │
     │  JWT + users │  │ catalogue +   │  │ upload + manage  │  │ Socket.IO +  │
     │              │  │ S3 playback   │  │ video assets     │  │ chat history │
     └──────┬───────┘  └──────┬────────┘  └────────┬─────────┘  └──────┬───────┘
            └─────────────────┴───────────────────┴──────────────────┘
                                         │
                              ┌──────────▼──────────┐
                              │  MongoDB :27017      │
                              │  (StatefulSet + EBS) │
                              └─────────────────────┘
```

| Service | Port | Responsibility |
|---|---|---|
| `authService` | 3001 | User registration, login, JWT issuance, role management |
| `streamingService` | 3002 | Video catalogue, S3 signed URL playback, public APIs |
| `adminService` | 3003 | Secure video upload to S3, metadata management, curation |
| `chatService` | 3004 | Socket.IO real-time chat + persistent message history |
| `frontend` | 80 | React SPA — nginx reverse proxies all backend calls |
| `mongodb` | 27017 | Shared MongoDB instance (StatefulSet with EBS PVC on EKS) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | React 18, Socket.IO client, Nginx reverse proxy |
| **Backend** | Node.js / Express (×4 microservices) |
| **Database** | MongoDB 6.0 |
| **Storage** | Amazon S3 (video files + thumbnails) |
| **Container Registry** | Amazon ECR |
| **Orchestration** | Kubernetes 1.31 on Amazon EKS |
| **CI/CD** | Jenkins declarative pipeline (Docker-in-Docker) |
| **IaC** | AWS CLI / eksctl |
| **Monitoring** | Amazon CloudWatch (Container Insights) |
| **Autoscaling** | Kubernetes HPA (CPU + Memory metrics) |
| **Region** | AWS eu-west-2 |

---

## Repository Structure

```
StreamingApp/
├── frontend/
│   ├── Dockerfile                   # Multi-stage: Node 18 build → Nginx Alpine
│   ├── nginx/default.conf           # Reverse proxy: /proxy/<svc>/ → backend services
│   └── src/
│       ├── pages/                   # LandingPage, Browse, StreamingPage, AdminDashboard, ...
│       ├── components/              # VideoCard, VideoPlayer, ChatPanel, Header, ...
│       ├── services/                # api.js, auth.service.js, streaming.service.js, ...
│       └── contexts/AuthContext.js
├── backend/
│   ├── authService/                 # JWT auth, user model, registration/login routes
│   ├── streamingService/            # Video catalogue, S3 streaming, seeder scripts
│   ├── adminService/                # Admin-only upload + management endpoints
│   └── chatService/                 # Socket.IO + REST chat endpoints
├── k8s/
│   ├── namespace.yaml
│   ├── mongodb-secret.yaml          # Base64-encoded credentials
│   ├── mongodb-statefulset.yaml     # MongoDB 6.0 + headless service + 5Gi EBS PVC
│   ├── auth-deployment.yaml
│   ├── streaming-deployment.yaml
│   ├── admin-deployment.yaml
│   ├── chat-deployment.yaml
│   ├── frontend-deployment.yaml     # LoadBalancer service
│   ├── frontend-nginx-configmap.yaml
│   └── hpa.yaml                     # HPA for all 5 services
├── helm/streamingapp/               # Helm chart (alternative to raw manifests)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── monitoring/
│   ├── cloudwatch-namespace.yaml
│   └── cloudwatch-configmap.yaml    # Container Insights config
├── docker-compose.yml               # Local full-stack development
├── Jenkinsfile                      # CI/CD pipeline (9 stages)
└── .env.example
```

---

## Environment Configuration

Copy `.env.example` and fill in your values. Each service reads its own subset.

### Auth Service (`backend/authService/.env`)
```ini
PORT=3001
MONGO_URI=mongodb://localhost:27017/streamingapp
JWT_SECRET=changeme
CLIENT_URLS=http://localhost:3000
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=eu-west-2
AWS_S3_BUCKET=
```

### Streaming Service (`backend/streamingService/.env`)
```ini
PORT=3002
MONGO_URI=mongodb://localhost:27017/streamingapp
JWT_SECRET=changeme
CLIENT_URLS=http://localhost:3000
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=eu-west-2
AWS_S3_BUCKET=
AWS_CDN_URL=
STREAMING_PUBLIC_URL=http://localhost:3002
```

### Admin Service (`backend/adminService/.env`)
```ini
PORT=3003
MONGO_URI=mongodb://localhost:27017/streamingapp
JWT_SECRET=changeme
CLIENT_URLS=http://localhost:3000
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=eu-west-2
AWS_S3_BUCKET=
```

### Chat Service (`backend/chatService/.env`)
```ini
PORT=3004
MONGO_URI=mongodb://localhost:27017/streamingapp
JWT_SECRET=changeme
CLIENT_URLS=http://localhost:3000
```

### Frontend build args
```ini
REACT_APP_AUTH_API_URL=/proxy/auth/api
REACT_APP_STREAMING_API_URL=/proxy/streaming/api/streaming
REACT_APP_STREAMING_PUBLIC_URL=/proxy/streaming
REACT_APP_ADMIN_API_URL=/proxy/admin/api/admin
REACT_APP_CHAT_API_URL=/proxy/chat/api/chat
REACT_APP_CHAT_SOCKET_URL=
```

---

## Running Locally

### Docker Compose (recommended)

```bash
# Clone and start the full stack
git clone https://github.com/Prateekdevops-619/StreamingApp.git
cd StreamingApp
cp .env.example .env   # fill in AWS credentials and secrets
docker-compose up --build
```

Navigate to `http://localhost:3000`. S3 credentials are optional for local testing — you can browse seeded metadata, but video playback requires valid S3 objects.

### Manual (per-service)

```bash
# Start MongoDB first (or use Docker)
docker run -d -p 27017:27017 mongo:6.0

# Install and run each service in a separate terminal
cd backend/authService     && npm install && npm run dev   # :3001
cd backend/streamingService && npm install && npm run dev  # :3002
cd backend/adminService    && npm install && npm run dev   # :3003
cd backend/chatService     && npm install && npm run dev   # :3004
cd frontend                && npm install && npm start     # :3000
```

---

## CI/CD Pipeline

The `Jenkinsfile` defines a **9-stage declarative pipeline** running on a Jenkins EC2 instance (`t3.medium`) in `eu-west-2`.

```
#1  Checkout
#2  AWS Login & ECR Auth
#3  Create ECR Repositories      (idempotent — skips if already exists)
#4  Build Images (parallel)      frontend | auth | streaming | admin | chat
#5  Push Images to ECR (parallel)
#6  Configure kubectl             (aws eks update-kubeconfig)
#7  Deploy to EKS                 namespace → secrets → MongoDB → services → HPA
#8  Wait for Rollout              (all 5 deployments, 180s timeout each)
#9  Smoke Test                    (in-cluster wget to auth :3001/health + streaming :3002/api/health)
    Deployment Summary            (kubectl get pods/svc/hpa)

post:
  success → "StreamingApp deployed successfully"
  failure → kubectl rollout undo (all 5 deployments)
  always  → docker rmi cleanup
```

**Pipeline environment variables:**

| Variable | Value |
|---|---|
| `AWS_REGION` | `eu-west-2` |
| `AWS_ACCOUNT_ID` | `975050024946` |
| `ECR_BASE` | `975050024946.dkr.ecr.eu-west-2.amazonaws.com` |
| `EKS_CLUSTER` | `prateek-streamingapp-eks` |
| `K8S_NAMESPACE` | `streamingapp` |
| `IMAGE_TAG` | `${BUILD_NUMBER}` |

**ECR repositories:**

| Service | Repository |
|---|---|
| Frontend | `prateek-streamingapp/frontend` |
| Auth | `prateek-streamingapp/auth` |
| Streaming | `prateek-streamingapp/streaming` |
| Admin | `prateek-streamingapp/admin` |
| Chat | `prateek-streamingapp/chat` |

**Jenkins credentials required:**

| ID | Type |
|---|---|
| `aws-cred` | AWS Credentials (Access Key + Secret) |

---

## Kubernetes Deployment

All manifests are in `k8s/`. The pipeline injects the correct ECR image tag at deploy time using `sed` substitution on `IMAGE_PLACEHOLDER_*` tokens.

### Workloads

| Workload | Kind | Min Replicas | Image | Service |
|---|---|---|---|---|
| auth-service | Deployment | 2 | `prateek-streamingapp/auth` | ClusterIP :3001 |
| streaming-service | Deployment | 2 | `prateek-streamingapp/streaming` | ClusterIP :3002 |
| admin-service | Deployment | 1 | `prateek-streamingapp/admin` | ClusterIP :3003 |
| chat-service | Deployment | 2 | `prateek-streamingapp/chat` | ClusterIP :3004 |
| frontend | Deployment | 2 | `prateek-streamingapp/frontend` | **LoadBalancer** :80 |
| mongodb | StatefulSet | 1 | `mongo:6.0` | Headless :27017 |

### Autoscaling (HPA)

| Service | CPU Target | Memory Target | Max Pods |
|---|---|---|---|
| auth-service | 60% | — | 6 |
| streaming-service | 60% | 70% | 8 |
| admin-service | — | — | — |
| chat-service | 60% | — | 6 |
| frontend | 70% | — | 4 |

### MongoDB

MongoDB runs as a StatefulSet with a **5Gi EBS PVC** (`gp2` StorageClass) for persistent storage. The EBS CSI driver is configured with IRSA (IAM Roles for Service Accounts) for credential-free AWS authentication. Liveness and readiness probes use TCP socket checks on port 27017.

### Accessing the app

```bash
# Get the frontend LoadBalancer URL
kubectl get svc frontend-service -n streamingapp \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Helm (alternative deployment)

```bash
helm upgrade --install streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --create-namespace \
  --set image.tag=<BUILD_NUMBER>
```

---

## Jenkins Access

| Item | Value |
|---|---|
| **URL** | http://52.56.79.23:8080 |
| **Job** | `StreamingApp-CI-CD` |
| **EC2 Instance** | `i-0b81d91b39deff4b8` (eu-west-2) |
| **Instance Type** | t3.medium |
| **EKS Cluster** | `prateek-streamingapp-eks` |

---

## Feature Highlights

- **S3-backed video streaming** with signed URLs for secure, time-limited playback
- **Dedicated admin microservice** — separate auth layer, S3 upload, metadata management
- **Real-time watch-party chat** via Socket.IO with persistent message history in MongoDB
- **Nginx reverse proxy** in the frontend container routes all API and WebSocket traffic — no CORS issues
- **Role-aware access control** enforced independently on each microservice and frontend route
- **HPA autoscaling** on all stateless services — scales up under load, stabilizes before scaling down
- **Automatic rollback** — pipeline undoes all 5 deployments if any stage fails

---

## License

MIT © StreamFlix Team
