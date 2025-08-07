# Deploying n8n to Google Cloud Run  
### Persistent + PostgreSQL (e.g., Neon) + Docker-based Custom Image  

This guide walks you through deploying [n8n](https://n8n.io) to **Google Cloud Run** with:  
- Persistent file storage via **Cloud Storage**  
- A **PostgreSQL** backend (e.g., Neon)  
- A **custom Docker image** to solve TCP probe issues on Cloud Run  

---

## 📦 Prerequisites  

Ensure you have the following setup before deploying:

- ✅ A Google Cloud Project with billing enabled  
- ✅ [Docker](https://docs.docker.com/get-docker/) and [gcloud CLI](https://cloud.google.com/sdk/docs/install)  
- ✅ A PostgreSQL database (Neon or any cloud-based PostgreSQL)  
- ✅ A **Cloud Storage bucket** (must exist and be **empty** on first deploy)  
- ✅ A **Default Compute Service Account With proper IAM Roles** (The said account must have Storage Admin right to access the bucket) 
- ✅ A 32-character encryption key (for `N8N_ENCRYPTION_KEY`)  

---

## 📁 Files to Create  

Create the following in your working directory:

### Dockerfile  

```dockerfile
FROM docker.n8n.io/n8nio/n8n:latest

# Copy the script and ensure it has proper permissions
COPY startup.sh /
USER root
RUN chmod +x /startup.sh
USER node
EXPOSE 5678

# Use shell form to help avoid exec format issues
ENTRYPOINT ["/bin/sh", "/startup.sh"]
```

### startup.sh  

```bash
#!/bin/sh

# Map Cloud Run's PORT to N8N_PORT if it exists
if [ -n "$PORT" ]; then
  export N8N_PORT=$PORT
fi

# Start n8n with its original entrypoint
exec /docker-entrypoint.sh
```

ℹ️ This startup script prevents **TCP probe failure** issues on Cloud Run.  
Thanks to [datawranglerai/self-host-n8n-on-gcr](https://github.com/datawranglerai/self-host-n8n-on-gcr).

---

## 🛠️ PowerShell Deployment Steps  

Open a PowerShell terminal and run the steps below:

---

### 1. Set these variables or hardcode them in the following requests 

```powershell
$projectId = "your-project-id"
$region = "us-central1"
$repoName = "n8n-repo"
$imageName = "n8n"
$bucketName = "your-n8n-bucket"
$serviceName = "n8n-service"
$n8nEncryptionKey = "REPLACE_WITH_32_CHARACTER_KEY"
```

---

### 2. Set GCP Project and Enable Services  

```powershell
gcloud config set project $projectId
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com
```

---

### 3. Create Artifact Registry (skip if it already exists)  

```powershell
gcloud artifacts repositories create $repoName `
  --repository-format="docker" `
  --location=$region `
  --description="Repository for n8n workflow images"
```

---

### 4. Authenticate Docker  

```powershell
gcloud auth configure-docker "$region-docker.pkg.dev"
```

---

### 5. Build and Push the Docker Image  

```powershell
docker build --platform linux/amd64 -t "$region-docker.pkg.dev/$projectId/$repoName/$imageName:latest" .
docker push "$region-docker.pkg.dev/$projectId/$repoName/$imageName:latest"
```

---

### 6. First Cloud Run Deployment  

```powershell
gcloud run deploy $serviceName `
  --image="$region-docker.pkg.dev/$projectId/$repoName/$imageName:latest" `
  --platform="managed" `
  --region=$region `
  --allow-unauthenticated `
  --port=5678 `
  --cpu=1 `
  --memory=2Gi `
  --min-instances=0 `
  --max-instances=1 `
  --add-volume="name=n8n-volume,type=cloud-storage,bucket=$bucketName" `
  --add-volume-mount="volume=n8n-volume,mount-path=/home/node/.n8n/.n8n" `
  --set-env-vars="`
    N8N_PATH=/, `
    N8N_PORT=443, `
    N8N_PROTOCOL=https, `
    N8N_ENCRYPTION_KEY=$n8nEncryptionKey, `
    DB_LOGGING_ENABLED=true, `
    QUEUE_HEALTH_CHECK_ACTIVE=true, `
    N8N_USER_FOLDER=/home/node/.n8n, `
    N8N_LOG_LEVEL=debug, `
    DB_TYPE=postgresdb, `
    EXECUTIONS_MODE=regular, `
    GENERIC_TIMEZONE=UTC, `
    DB_POSTGRESDB_DATABASE=REPLACE_DB_NAME, `
    DB_POSTGRESDB_USER=REPLACE_DB_USER, `
    DB_POSTGRESDB_HOST=REPLACE_DB_HOST, `
    DB_POSTGRESDB_PORT=5432, `
    DB_POSTGRESDB_PASSWORD=REPLACE_DB_PASSWORD, `
    DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false, `
    DB_POSTGRESDB_SCHEMA=public, `
    DB_POSTGRESDB_MAX=10, `
    DB_POSTGRESDB_MIN=1, `
    DB_POSTGRESDB_CONNECTION_TIMEOUT=120000"
```
the RAM can be set to any amount. I have succesfully tested with 512mb and it was working with ease. so you can change that parameter too.

the above config is specfic for NEON but should work with any postgresql given some tinkering
after this if you want to check you should see some files poping up in your bucket. that is a good sign. if you are not, then recheck the folder paths.

> ✅ Go to the logs of your deployed instance and make sure its done with db migrations. this is optional but can save alot 
headache relating to db issues. once its done with db migration. it will start up some services and will not give out a editior URL. but dont panic.
---

### 7. Grab the Service URL  

```powershell
$serviceUrl = gcloud run services describe $serviceName --region=$region --format="value(status.url)"
```
> ✅ here we use the editor URL to directly bind it to the service url of the container and given 443 port. the URL should start working as intended.
---

### 8. Update Service with n8n Editor/Webhook URL you can do

```powershell
$serviceUrlWithOutHTTPS = $serviceUrl.Replace("https://", "")
gcloud run services update $serviceName `
  --region=$region `
  --update-startup-probe="initialDelaySeconds=240,timeoutSeconds=240,periodSeconds=240,failureThreshold=1,tcpSocket={port:5678}" `
  --update-env-vars="N8N_HOST=$serviceUrlWithOutHTTPS,N8N_WEBHOOK_URL=$serviceUrl,N8N_EDITOR_BASE_URL=$serviceUrl"
```

---

## ✅ Final Output (Console Logs)

Once n8n is fully initialized, your logs will show:

```text
N8N | ====================================
N8N | Version: 1.xx.x
N8N | Editor is now accessible at:
N8N | https://your-service-url
N8N | ====================================
```

---

## 👽 You did it!

n8n is now live on **Google Cloud Run** with persistent storage + PostgreSQL backend.

> After that, you can create **your own Skynet using agents** and take over humanity with ease.

---

