# Infraestructura AWS — ProductosAPI

Guia paso a paso para recrear la infraestructura desde cero.

---

## 1. Cuenta AWS

- **Account ID:** `905418035297`
- **Region:** `us-east-1` (N. Virginia)
- **IAM Role usado:** `LabRole` (tiene permisos de ECR, EC2, CloudWatch, ECS)

---

## 2. VPC y Networking

Usamos una VPC existente de AWS Academy (no creada manualmente):

| Recurso | ID |
|---|---|
| VPC | `vpc-02cc1c60d66d70b32` |
| Subnet A | `subnet-0f468ed17ab154564` (us-east-1a) |
| Subnet B | `subnet-0b9fca0167f69f5b6` (us-east-1b) |

---

## 3. Security Group — `productosapi-ecs-sg`

| Puerto | Protocolo | Origen | Descripcion |
|---|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH para deploy |
| 8080 | TCP | `sg-del-alb` (ID: `sg-09e3764d254ddee15`) | Trafico desde ALB |
| 80 | TCP | `0.0.0.0/0` | ALB listener HTTP |

**Security Group ID:** `sg-09e3764d254ddee15`

---

## 4. EC2 — `productosapi-ec2`

### Datos de la instancia

| Atributo | Valor |
|---|---|
| **Instance ID** | `i-0d147203826640885` |
| **AMI** | `al2023-ami-2023.12.20260622.0-kernel-6.18-x86_64` (Amazon Linux 2023) |
| **Tipo** | `t3.micro` (2 vCPU, 1GB RAM) |
| **Key Pair** | `productosapi-ec2` |
| **IAM Role** | `LabRole` |
| **VPC** | `vpc-02cc1c60d66d70b32` |
| **Subnet** | `subnet-0f468ed17ab154564` (us-east-1a) |
| **IP Publica** | Variable (cambia al detener/iniciar) |
| **Security Group** | `productosapi-ecs-sg` |

### User Data (script de instalacion)

```bash
#!/bin/bash
# Instalar Docker
yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Instalar CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Crear directorio para logs
mkdir -p /var/log/productosapi
```

### Configuracion adicional (post-instalacion)

```bash
# Verificar Docker
docker --version

# Verificar que el agente de CloudWatch este instalado
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

---

## 5. Application Load Balancer — `productosapi-alb`

| Atributo | Valor |
|---|---|
| **Nombre** | `productosapi-alb` |
| **Esquema** | `internet-facing` |
| **Listener** | HTTP:80 → Target Group |
| **Subnets** | `subnet-0f468ed17ab154564`, `subnet-0b9fca0167f69f5b6` |
| **Security Group** | Creado por CloudFormation (permite HTTP:80) |
| **DNS** | `productosapi-alb-1646067421.us-east-1.elb.amazonaws.com` |

### Target Group — `productosapi-tg`

| Atributo | Valor |
|---|---|
| **Nombre** | `productosapi-tg` |
| **Protocolo** | HTTP:8080 |
| **Tipo** | `ip` |
| **Health Check** | `GET /actuator/health` |
| **Intervalo** | 30s |
| **Umbral saludable** | 2 (exitoso) |
| **Umbral no saludable** | 3 (fallo) |
| **Codigo esperado** | `200` |
| **ARN** | `arn:aws:elasticloadbalancing:us-east-1:905418035297:targetgroup/productosapi-tg/edaefe04b5a30e79` |

---

## 6. ECR — `productosapi`

| Atributo | Valor |
|---|---|
| **Registry** | `905418035297.dkr.ecr.us-east-1.amazonaws.com` |
| **Repositorio** | `productosapi` |
| **URI imagen** | `905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest` |
| **Scan on push** | Habilitado |

### Tags de imagen

- `latest` — ultima version desplegada
- `{sha_commit}` — version especifica (ej: `3c87b29`)

---

## 7. Docker

### Dockerfile (multi-stage)

```
Builder: maven:3.9.9-eclipse-temurin-21-alpine
  → Compila el JAR con mvn clean package

Runtime: eclipse-temurin:21-jre-alpine
  → Copia el JAR y application.properties
  → HEALTHCHECK con curl al /actuator/health
  → Puerto 8080
  → Ejecuta como appuser (no root)
```

### docker-compose.yml (local)

```yaml
services:
  microservicio-app:
    build: .
    ports: ["8080:8080"]
    deploy:
      replicas: 2
      resources:
        limits: { cpus: '0.50', memory: 512M }
```

### Comando de deploy en EC2

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 905418035297.dkr.ecr.us-east-1.amazonaws.com

docker run -d -p 8080:8080 \
  --name productosapi \
  --log-driver awslogs \
  --log-opt awslogs-group=/productosapi/microservice \
  --log-opt awslogs-region=us-east-1 \
  --log-opt awslogs-stream-prefix=ec2-productosapi \
  -e SERVER_PORT=8080 \
  -e AWS_REGION=us-east-1 \
  905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest
```

---

## 8. CloudWatch

### Log Group

| Atributo | Valor |
|---|---|
| **Nombre** | `/productosapi/microservice` |
| **Retencion** | 30 dias |
| **Stream prefix** | `ec2-productosapi` (EC2), `ecs-productosapi` (ECS) |

### Alarmas (4)

| Nombre | Metrica | Condicion | Periodo |
|---|---|---|---|
| `productosapi-cpu-high` | `CPUUtilization` (EC2) | > 80% | 5 min |
| `productosapi-memory-high` | `mem_used_percent` (CWAgent) | > 85% | 5 min |
| `productosapi-error-spike` | `productosapi.errors.total` (Custom) | > 10 | 5 min |
| `productosapi-unhealthy-host` | `UnhealthyHostCount` (ALB) | > 0 | 2 min |

### Dashboard — `ProductosAPI-EP3` (7 widgets)

| Widget | Metrica | Tipo |
|---|---|---|
| 1. CPU Usage | `CPUUtilization` (EC2) | TimeSeries |
| 2. Memory Usage | `mem_used_percent` (CWAgent) | TimeSeries |
| 3. Deployment Duration | `DeploymentDuration` (Custom) | SingleValue |
| 4. Test Coverage | `TestCoverage` (Custom) | Gauge |
| 5. Error Rate | `productosapi.errors.total` + `5XX` | TimeSeries |
| 6. Request Count | `productosapi.requests.total` (Custom) | TimeSeries |
| 7. Service Availability | `HealthyHostCount` (ALB) | SingleValue |

### Metricas personalizadas publicadas por el pipeline

- `ProductosAPI.DeploymentDuration` — duracion del deploy (segundos)
- `ProductosAPI.TestCoverage` — porcentaje de cobertura (0-100)
- `ProductosAPI.productosapi.errors.total` — total de errores
- `ProductosAPI.productosapi.requests.total` — total de requests

---

## 9. Pipelines CI/CD

### Workflows (`.github/workflows/`)

| Archivo | Trigger | Jobs |
|---|---|---|
| `ci-pipeline.yml` | Push a `main`/`develop` | validate → sonar → build-and-push → deploy |
| `deploy.yml` | Push a `main`/`develop` + PR a `main` | validate → build → deploy |

### Secrets requeridos en GitHub Actions

| Secret | Descripcion |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key de AWS (temporal, 4h) |
| `AWS_SECRET_ACCESS_KEY` | Secret key de AWS |
| `AWS_SESSION_TOKEN` | Session token de AWS |
| `EC2_HOST` | IP publica de la EC2 |
| `EC2_SSH_KEY` | Clave privada SSH para conectar a EC2 |
| `SONAR_TOKEN` | Token de autenticacion de SonarCloud |

---

## 10. Flujo de deploy completo

```
Developer push a main
       ↓
   GitHub Actions detecta el push
       ↓
   Job: validate
   ├── mvn clean test (JUnit + Mockito)
   ├── JaCoCo coverage (min 80%)
   ├── Trivy secret scan
   ├── SonarCloud analysis + Quality Gate
   ├── Check CloudWatch Alarms
   ├── Audit script
   └── Check hardcoded secrets
       ↓
   Job: build
   ├── mvn clean package
   ├── docker build -t productosapi
   └── docker push a ECR
       ↓
   Job: deploy
   ├── SSH a EC2
   ├── docker pull desde ECR
   ├── docker stop/rm/run contenedor
   ├── Publicar metricas CloudWatch
   └── Verificar health (GET /actuator/health via ALB)
```

---

## 11. Referencias

- **API endpoint:** `http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/api/v1/products`
- **Health check:** `http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/actuator/health`
- **SonarCloud:** `https://sonarcloud.io/dashboard?id=productosapi`
- **Repositorio:** `https://github.com/cafesincuchara/EntregaEvaluacion3`
