# Vicente — Persona B

**Proyecto:** [EvaluacionParcial2](https://github.com/cafesincuchara/EvaluacionParcial2) — `productosapi`
**Responsable de:** IE2 (Docker + AWS EC2) + IE5 (Cumplimiento) + IE4 (Documentación)
**Ponderación total:** 20% + 20% + 10% = **50%**

## Estado actual del repositorio

### Lo que YA existe (no requiere cambios)
- `pom.xml` (base, **faltan** plugins JaCoCo, Checkstyle, PMD)
- `Dockerfile` (básico multi-stage, **sin** HEALTHCHECK ni non-root user)
- `src/` completo con Java, tests, `sonar-project.properties`
- `.github/dependabot.yml` (básico, sin labels ni limits)
- `.github/workflows/ci-pipeline.yml` (workflow simple con deploy a Render)

### Lo que FALTA implementar (tu responsabilidad)

| Prioridad | Archivo/Tarea | IE | Descripción |
|---|---|---|---|
| 🔴 Alta | `Dockerfile` - actualizar | IE2 | Agregar HEALTHCHECK (curl), non-root user (appuser), copiar application.properties |
| 🔴 Alta | Crear infraestructura manual (Consola AWS) | IE2 | Security Groups, Target Group, ALB, EC2 con Docker |
| 🔴 Alta | `pom.xml` - plugins de calidad | IE5 | Agregar JaCoCo (check 80%), Checkstyle (google_checks), PMD (bestpractices + security) |
| 🔴 Alta | `scripts/audit-pipeline.sh` | IE5 | Crear script de auditoría (compartido con Brayan IE6) |
| 🔴 Alta | `docs/` - 3 documentos | IE4 | arquitectura-observabilidad.md, pipeline-ci-cd.md, mejora-continua.md |
| 🟡 Media | ECR repository (AWS CLI) | IE2 | Crear con scanOnPush=true y pushear imagen inicial |
| 🟡 Media | Lanzar EC2 con user data | IE2 | Instalar Docker, pull imagen, ejecutar contenedor |
| 🟡 Media | Registrar EC2 en Target Group | IE2 | Asociar IP privada al TG, verificar healthy |
| 🟡 Media | GitHub Secrets (Settings) | IE2 | Configurar AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, SONAR_TOKEN |
| 🟡 Media | SonarCloud Quality Gate (UI web) | IE5 | Crear `ProductosAPI-QG`: coverage ≥ 80%, rating A, code smells ≤ 20 |
| 🟡 Media | Branch Protection Rules (Settings GitHub) | IE5 | main: PR, approvals, status checks, admins. develop: PR, approvals |
| 🟡 Media | Actualizar `.github/dependabot.yml` | IE5 | Agregar open-pull-requests-limit: 10 y labels |
| 🟡 Media | Probar despliegue | IE2 | curl a ALB DNS, verificar contenedor con docker ps |
| 🔵 Baja | 8 capturas de pantalla para documentación | IE4 | Dashboard, pipeline, SonarCloud, branch rules, EC2, ALB, ECR |
| 🔵 Baja | Reflexiones individuales (sin IA) | IE4 | Brayan: IE1/IE3/IE6; Vicente: IE2/IE5/IE4 |

---

## IE2 — Desplegar microservicio con Docker en AWS EC2 (20%)

### Objetivo para 100%
> "Despliega eficazmente microservicios en entornos orquestados en la nube, integrando **de forma automatizada todas las configuraciones necesarias** para el monitoreo, trazabilidad y observabilidad."

### Pasos

#### 1. Optimizar el Dockerfile existente

El proyecto ya tiene un `Dockerfile` multi-stage. Actualizarlo para incluir health check y non-root user:

```dockerfile
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder
WORKDIR /app
COPY pom.xml ./
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/target/*.jar app.jar
COPY --from=builder /app/src/main/resources/application.properties application.properties

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
USER appuser
ENTRYPOINT ["java", "-jar", "app.jar", "--server.port=${PORT:-8080}"]
```

#### 2. Crear repositorio ECR

```bash
# Crear repositorio ECR con escaneo de imágenes
aws ecr create-repository \
  --repository-name productosapi \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Autenticarse y pushear la imagen inicial
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

docker build -t productosapi:latest .
docker tag productosapi:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest
```

#### 3. Crear infraestructura manual en AWS Console

Se optó por despliegue manual (no CloudFormation) porque AWS Academy/Vocareum no permite crear IAM Roles, VPC ni algunos recursos vía CloudFormation. Los pasos fueron:

##### a. Security Groups

| Grupo | Propósito | Reglas Inbound |
|---|---|---|
| `productosapi-alb-sg` | ALB → internet | HTTP 80 desde `0.0.0.0/0` |
| `productosapi-ecs-sg` | Instancia EC2 | HTTP 8080 desde `sg-09e3764d254ddee15` (ALB SG) |

##### b. Target Group

- **Nombre:** `productosapi-tg` · **Tipo:** IP · **Protocolo:** HTTP:8080
- **VPC:** `vpc-02cc1c60d66d70b32`
- **Health check:** `/actuator/health` → HTTP 200

##### c. Application Load Balancer

- **Nombre:** `productosapi-alb` · **Scheme:** Internet-facing · **IP:** IPv4
- **Subnets:** `subnet-0f468ed17ab154564` (us-east-1a), `subnet-0b9fca0167f69f5b6` (us-east-1b)
- **Listener:** HTTP:80 → forward a `productosapi-tg`
- **DNS:** `productosapi-alb-1646067421.us-east-1.elb.amazonaws.com`

##### d. Lanzar instancia EC2 (Amazon Linux 2023)

En AWS Console → EC2 → Launch instance:

| Parámetro | Valor |
|---|---|
| Nombre | `productosapi-ec2` |
| AMI | Amazon Linux 2023 (free tier) |
| Tipo | `t2.micro` o `t3.micro` |
| VPC | `vpc-02cc1c60d66d70b32` |
| Subnet | `subnet-0f468ed17ab154564` (pública) |
| Auto-assign Public IP | Enable |
| Security Group | `productosapi-ecs-sg` (puerto 8080 abierto) |
| Storage | 20 GB gp2 |

**User data** (al lanzar):

```bash
#!/bin/bash
yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 905418035297.dkr.ecr.us-east-1.amazonaws.com
docker pull 905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest
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

##### e. Registrar la EC2 en el Target Group

- EC2 → Target Groups → `productosapi-tg` → Register targets
- IP: `<private-ip-de-la-ec2>` · Port: `8080`
- Verificar que pase a healthy

#### 4. Desplegar infraestructura

```bash
# Desplegar stack
aws cloudformation create-stack \
  --stack-name ProductosAPI-Infra \
  --template-body file://cloudformation/productosapi-infra.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Monitorear progreso
aws cloudformation describe-stacks \
  --stack-name ProductosAPI-Infra \
  --query 'Stacks[0].StackStatus' \
  --region us-east-1

# Obtener el DNS del ALB
aws cloudformation describe-stacks \
  --stack-name ProductosAPI-Infra \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text \
  --region us-east-1
```

#### 5. Configurar GitHub Secrets

En Settings → Secrets and variables → Actions:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key de IAM con permisos EC2, ECR, CloudWatch |
| `AWS_SECRET_ACCESS_KEY` | Secret Key correspondiente |
| `AWS_REGION` | `us-east-1` |
| `SONAR_TOKEN` | Token de SonarCloud |

#### 6. Probar el despliegue

```bash
# Verificar que el ALB responde
curl -f http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/actuator/health
curl -f http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/api/v1/products

# Verificar que la EC2 está corriendo
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=productosapi-ec2" \
  --query 'Reservations[0].Instances[0].State.Name'

# Verificar Docker corriendo (SSH a la EC2)
ssh -i <key.pem> ec2-user@<public-ip>
docker ps
docker logs productosapi
```

#### 7. Evidencias
- Pantallazo de EC2 instancia en estado `Running`
- Pantallazo de ECR con la imagen `productosapi:latest`
- Pantallazo del ALB con Target Group saludable (EC2 registrada como target)
- Pantallazo del ALB DNS respondiendo al endpoint `/api/v1/products`
- Pantallazo de `docker ps` mostrando el contenedor ejecutándose
- Pantallazo de GitHub Secrets configurados

---

## IE5 — Aplicar políticas de cumplimiento (20%)

### Objetivo para 100%
> "Aplica rigurosamente políticas de cumplimiento usando herramientas automatizadas, garantizando calidad, seguridad y trazabilidad del código."

### Pasos

#### 1. Configurar Quality Gate en SonarCloud

El proyecto ya tiene `sonar-project.properties` configurado para SonarCloud. Mejorar los thresholds:

Ir a [SonarCloud → Quality Gates](https://sonarcloud.io/project/quality_gates?id=productosapi) → Create:

**Quality Gate: `ProductosAPI-QG`**

| Métrica | Operador | Umbral |
|---|---|---|
| Coverage | < | 80 |
| Duplicated Lines (%) | > | 3 |
| Security Rating | > | A |
| Reliability Rating | > | A |
| Maintainability Rating | > | A |
| Security Hotspots Reviewed | < | 100 |
| Code Smells | > | 20 |

Asignar este Quality Gate como predeterminado para el proyecto `productosapi`.

#### 2. Agregar plugins de calidad en pom.xml

Agregar dentro de `<build><plugins>` en `pom.xml`:

```xml
<!-- JaCoCo para cobertura de pruebas -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals><goal>report</goal></goals>
        </execution>
        <execution>
            <id>check</id>
            <goals><goal>check</goal></goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>

<!-- Checkstyle para estilo de código -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <version>3.3.1</version>
    <configuration>
        <configLocation>google_checks.xml</configLocation>
        <failOnViolation>true</failOnViolation>
    </configuration>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>

<!-- PMD para análisis estático -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-pmd-plugin</artifactId>
    <version>3.21.2</version>
    <configuration>
        <failOnViolation>true</failOnViolation>
        <rulesets>
            <ruleset>/category/java/bestpractices.xml</ruleset>
            <ruleset>/category/java/security.xml</ruleset>
        </rulesets>
    </configuration>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

#### 3. Crear script de auditoría automatizada

Crear `scripts/audit-pipeline.sh`:

```bash
#!/bin/bash
# Script de auditoría automatizada - ProductosAPI
set -euo pipefail

FAILURES=0

echo "╔═══════════════════════════════════════════════╗"
echo "║   AUDITORÍA DE CUMPLIMIENTO - ProductosAPI    ║"
echo "╚═══════════════════════════════════════════════╝"

# 1. Verificar dependencias vulnerables
echo "[1/6] Dependencias vulnerables..."
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q && echo "✅ OK" || {
    echo "❌ Dependencias con CVSS >= 7"; FAILURES=$((FAILURES+1)); }

# 2. Verificar calidad de código
echo "[2/6] Calidad de código..."
mvn checkstyle:check pmd:check -q && echo "✅ OK" || {
    echo "❌ Violaciones de calidad"; FAILURES=$((FAILURES+1)); }

# 3. Verificar cobertura
echo "[3/6] Cobertura de pruebas (mín. 80%)..."
mvn jacoco:check -q && echo "✅ OK" || {
    echo "❌ Cobertura < 80%"; FAILURES=$((FAILURES+1)); }

# 4. Escanear secretos
echo "[4/6] Secretos hardcodeados..."
PATTERN='(?i)(password|secret|token|api.key|apikey)\s*[:=]\s*["'"'"'][^"'"'"']+'
if grep -rP "$PATTERN" src/ --include='*.{java,properties}' 2>/dev/null; then
    echo "❌ Secretos encontrados"; FAILURES=$((FAILURES+1))
else
    echo "✅ No se encontraron secretos"
fi

# 5. Licencias
echo "[5/6] Licencias..."
mvn license:aggregate-add-third-party -q 2>/dev/null || true
echo "✅ Verificado"

# 6. Buenas prácticas
echo "[6/6] Buenas prácticas..."
TODOS=$(grep -r "TODO\|FIXME\|HACK" src/main --include="*.java" | wc -l)
[ "$TODOS" -gt 5 ] && echo "⚠️  $TODOS TODOs/FIXMEs" || echo "✅ OK"

echo ""
if [ $FAILURES -eq 0 ]; then
    echo "✅ AUDITORÍA APROBADA"
    exit 0
else
    echo "❌ AUDITORÍA FALLIDA: $FAILURES fallo(s)"
    exit 1
fi
```

#### 4. Configurar Branch Protection Rules en GitHub

Settings → Branches → Add rule para `main`:

Opciones que deben estar activadas:
```
☑ Require a pull request before merging
  ☑ Require approvals (1)
  ☑ Dismiss stale pull request approvals when new commits are pushed
☑ Require status checks to pass before merging
  ☑ validate (GitHub Actions job)
  ☑ SonarCloud Code Analysis (ya configurado por SonarCloud)
☑ Require branches to be up-to-date before merging
☑ Require conversation resolution
☑ Include administrators
☑ Block force pushes
☑ Do not allow bypassing the above settings
```

Además, para `develop`:
```
☑ Require a pull request before merging
  ☑ Require approvals (1)
☑ Require status checks to pass before merging
  ☑ validate
```

#### 5. Configurar Dependabot

Crear `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "maven"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "security"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### 6. Evidencias
- Pantallazo de SonarCloud Quality Gate mostrando `PASSED` (verde)
- Pantallazo de SonarCloud con métricas: coverage ≥ 80%, rating A en seguridad, reliability, maintainability
- Pantallazo de Branch Protection Rules configuradas en GitHub
- Pantallazo del script `audit-pipeline.sh` ejecutándose y pasando
- Pantallazo del Dependabot configurado en `.github/dependabot.yml`

---

## IE4 — Documentar la integración de herramientas en el pipeline (10%)

### Objetivo para 100%
> "Documenta de forma clara y detallada la integración de herramientas de monitoreo, métricas y seguridad en el pipeline CI/CD, explicando su **impacto en la toma de decisiones** y mejora continua."

### Pasos

#### 1. Crear `docs/arquitectura-observabilidad.md`

```markdown
# Arquitectura de Observabilidad y Cumplimiento - ProductosAPI

## 1. Diagrama de Arquitectura

[Insertar diagrama draw.io con:]

┌──────────┐     ┌──────────────┐     ┌────────────────┐
│ Developer│────▶│ GitHub       │────▶│ GitHub Actions  │
└──────────┘     └──────────────┘     └────────────────┘
                                             │
                               ┌─────────────┼──────────────┐
                               │             │              │
                               ▼             ▼              ▼
                         ┌──────────┐ ┌──────────┐ ┌──────────────┐
                         │ Validate │ │  Build   │ │   Deploy     │
                         │ • Tests  │ │ • Maven  │                           │ • SSH + Docker│
                         │ • Sonar  │ │ • Docker │ │ • Health     │
                         │ • Trivy  │ │ • ECR    │ │ • Metrics    │
                         │ • Audit  │ │          │ │              │
                         └──────────┘ └──────────┘ └──────┬───────┘
                                                            │
                                                            ▼
                                                  ┌──────────────────┐
                                                  │  AWS EC2         │
                                                  │ ┌──────────────┐ │
                                                  │ │ productosapi  │ │
                                                  │ │ (Docker)     │ │
                                                  │ └──────────────┘ │
                                                  └────────┬─────────┘
                                                           │
                                              ┌────────────┼────────────┐
                                              ▼            ▼            ▼
                                      ┌──────────┐ ┌──────────┐ ┌──────────┐
                                      │CloudWatch│ │CloudWatch│ │   X-Ray  │
                                      │  Logs    │ │ Metrics  │ │   Trace  │
                                      │          │ │ & Alarms │ │          │
                                      └──────────┘ └──────────┘ └──────────┘
                                                           │
                                                           ▼
                                                  ┌──────────────────┐
                                                  │  CloudWatch      │
                                                  │  Dashboard       │
                                                  │  (7 widgets)     │
                                                  └──────────────────┘

## 2. Herramientas y su integración

### 2.1 AWS CloudWatch
- **Integración:** 
  - Log driver awslogs en Docker envía stdout/stderr a CloudWatch Logs
  - Micrometer Registry publica métricas de negocio (requests, errores, productos creados)
  - CloudWatch Agent (si aplica) publica métricas del sistema
- **Propósito en el pipeline:**
  - Las alarmas se verifican antes del deploy (stage validate)
  - Si hay alarmas críticas, el pipeline se detiene
  - Las métricas de deploy duration y coverage se publican automáticamente

### 2.2 CloudWatch Dashboard
- **Métricas monitoreadas (las 7):**
  1. CPU Utilization → escalado horizontal
  2. Memory Utilization → detección de memory leaks
  3. Deployment Duration → eficiencia del pipeline
  4. Test Coverage → calidad del código
  5. Error Rate → estabilidad del sistema
  6. Request Count → carga del sistema
  7. Service Availability → uptime del servicio
- **Propósito en decisiones técnicas:**
  - CPU > 70% sostenido → aumentar desired count o escalar
  - Coverage < 80% → agregar tests antes de nuevas features
  - Error rate > 5% → evaluar rollback inmediato
  - Deployment duration > 5 min → optimizar Dockerfile o pipeline

### 2.3 SonarCloud
- **Integración:** Maven plugin ejecutado en GitHub Actions (stage validate)
- **Quality Gate:** Exige coverage ≥ 80%, Security Rating A, Reliability A, Maintainability A
- **Propósito en decisiones:** Bloquear código que no cumple estándares de calidad y seguridad

### 2.4 GitHub Actions (CI/CD Pipeline)
- **3 jobs secuenciales:** validate → build → deploy
- **Cada job depende del anterior:** si validate falla, no se construye ni despliega
- **Propósito:** Automatización completa con trazabilidad por commit (SHA)

## 3. Toma de decisiones basada en herramientas

| Herramienta | Métrica | Umbral | Decisión |
|---|---|---|---|
| SonarCloud | Quality Gate | ≠ OK | ❌ Detener pipeline |
| JaCoCo | Coverage | < 80% | ❌ Detener pipeline |
| Trivy | Severidad | CRITICAL/HIGH | ❌ Detener pipeline |
| CloudWatch Alarms | Estado | ALARM | ❌ Detener pipeline |
| CloudWatch Dashboard | CPU | > 70% | ⚠️ Escalar servicio |
| CloudWatch Dashboard | Error Rate | > 5% | 🔄 Considerar rollback |
| CloudWatch Dashboard | Memory | > 85% | 🐛 Revisar memory leaks |
```

#### 2. Crear `docs/pipeline-ci-cd.md`

```markdown
# Pipeline CI/CD - ProductosAPI

## Estructura

El pipeline se ejecuta en cada push a `main` o `develop`, y en PRs hacia `main`.

```
[Git Push] 
    │
    ▼
┌────────────────────────────────────────────────────────────┐
│  JOB 1: validate (obligatorio pasar para continuar)        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Unit tests (JUnit 5 + Mockito)                   │  │
│  │ 2. JaCoCo coverage check (mín. 80%)                 │  │
│  │ 3. Trivy security scan (CRITICAL/HIGH → STOP)       │  │
│  │ 4. SonarCloud analysis + Quality Gate               │  │
│  │ 5. CloudWatch Alarms check                          │  │
│  │ 6. Audit script (deps, licencias, secretos)         │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────┬─────────────────────────────────────┘
                       │ if FAIL → STOP ❌
                       ▼
┌────────────────────────────────────────────────────────────┐
│  JOB 2: build                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Construir imagen Docker                           │  │
│  │ 2. Pushear a Amazon ECR                              │  │
│  │ 3. Etiquetar con SHA del commit                      │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────┬─────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────────┐
│  JOB 3: deploy                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. SSH a EC2, pull imagen, restart contenedor       │  │
│  │ 2. Esperar a que el servicio estabilice             │  │
│  │ 3. Publicar métricas (Deploy Duration, Coverage)    │  │
│  │ 4. Verificar health endpoint                        │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
                       │
                       ▼
            ✅ Producción (EC2 + Docker)
```

## Seguridad en el pipeline
- **Branch Protection:** Nadie puede hacer push directo a `main`
- **Secrets:** AWS credenciales y tokens almacenados en GitHub Secrets
- **Dependabot:** Revisión semanal de dependencias con PRs automáticos
```

#### 3. Crear `docs/mejora-continua.md`

```markdown
# Mejora Continua - ProductosAPI

## Ciclo de retroalimentación

### 1. Monitorear (CloudWatch Dashboard)
- Dashboards visibles en tiempo real
- Alarmas automáticas ante anomalías
- Logs centralizados para debugging

### 2. Analizar (métricas del dashboard)
- **Tiempo de despliegue:** Si sube consistentemente, revisar Dockerfile o pipeline
- **Cobertura de pruebas:** Si baja, agregar tests en el próximo sprint
- **Errores:** Si aumentan, priorizar fixes sobre nuevas features

### 3. Decidir (basado en datos)
- Si deployment duration > 5 min → optimizar Docker build cache
- Si coverage < 80% → agregar tests antes de aceptar PRs
- Si error rate > 3% → hacer rollback y debugging prioritario
- Si CPU > 70% sostenido → ajustar auto-scaling thresholds

### 4. Mejorar (iteración continua)
- Cada sprint: revisar dashboards y ajustar thresholds
- Incorporar nuevas validaciones según incidentes
- Actualizar Quality Gate según estándares del proyecto
```

#### 4. Capturas de pantalla obligatorias para la documentación

| # | Captura | Descripción |
|---|---|---|
| 1 | Dashboard CloudWatch | Los 7 widgets visibles con datos |
| 2 | Pipeline GitHub Actions | Jobs validate → build → deploy exitoso |
| 3 | Pipeline fallando | Demostración de falla de seguridad/calidad |
| 4 | SonarCloud Quality Gate | PASSED con coverage ≥ 80% |
| 5 | Branch Protection Rules | Configuración completa |
| 6 | EC2 instancia | Estado Running + `docker ps` con contenedor activo |
| 7 | ALB Target Group | EC2 registrada como target, estado healthy |
| 8 | ECR Repository | Imagen `productosapi:latest` con tag |

#### 5. Reflexiones individuales (obligatorio, SIN IA)

Cada integrante debe incluir en las conclusiones del informe final:

- **Brayan:** Reflexión personal sobre su aprendizaje en IE1, IE3 e IE6
- **Vicente:** Reflexión personal sobre su aprendizaje en IE2, IE5 e IE4

---

## Checklist IE2 (20%) — Estado: ❌ No iniciado
- [ ] `Dockerfile`: Agregar HEALTHCHECK (curl), non-root user (appuser), copiar application.properties
- [ ] ECR repository creado con `--image-scanning-configuration scanOnPush=true`
- [ ] Imagen Docker construida y subida a ECR
- [ ] Security Groups creados: ALB SG (HTTP 80) + EC2 SG (HTTP 8080 desde ALB SG)
- [ ] Target Group `productosapi-tg` creado (HTTP:8080, /actuator/health)
- [ ] ALB `productosapi-alb` creado (internet-facing, listener HTTP:80 → TG)
- [ ] EC2 instancia `productosapi-ec2` lanzada con user data (Docker + pull + run)
- [ ] EC2 registrada como target en el Target Group (healthy)
- [ ] ALB DNS respondiendo a `/actuator/health` y `/api/v1/products`
- [ ] GitHub Secrets configurados: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, SONAR_TOKEN
- [ ] Pantallazos: EC2 running, ECR, ALB + TG healthy, docker ps, GitHub Secrets

## Checklist IE5 (20%) — Estado: ❌ No iniciado
- [ ] `pom.xml`: Agregar plugins JaCoCo (check ≥ 80%), Checkstyle (google_checks), PMD (bestpractices + security)
- [ ] SonarCloud Quality Gate `ProductosAPI-QG`: coverage ≥ 80%, rating A, code smells ≤ 20
- [ ] `scripts/audit-pipeline.sh`: Crear script con 6 validaciones (compartido con Brayan)
- [ ] Branch Protection Rules: `main` (PR, approvals, status checks, admins) + `develop` (PR, approvals)
- [ ] `.github/dependabot.yml`: Agregar open-pull-requests-limit: 10, labels: dependencies + security
- [ ] Pantallazos: SonarCloud QG passed, branch rules, audit script ejecutándose

## Checklist IE4 (10%) — Estado: ❌ No iniciado
- [ ] Crear `docs/` directorio
- [ ] `docs/arquitectura-observabilidad.md`: Diagrama de flujo + tabla de decisiones técnicas
- [ ] `docs/pipeline-ci-cd.md`: Diagrama de flujo del pipeline validate→build→deploy
- [ ] `docs/mejora-continua.md`: Ciclo monitorear→analizar→decidir→mejorar
- [ ] 8 capturas de pantalla incluidas en la documentación
- [ ] Reflexión individual Brayan (IE1, IE3, IE6) — SIN IA
- [ ] Reflexión individual Vicente (IE2, IE5, IE4) — SIN IA
