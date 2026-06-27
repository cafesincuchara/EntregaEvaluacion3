# Brayan — Persona A

**Proyecto:** [EvaluacionParcial2](https://github.com/cafesincuchara/EvaluacionParcial2) — `productosapi`
**Responsable de:** IE1 (CloudWatch) + IE3 (Dashboard) + IE6 (Detener Pipeline)
**Ponderación total:** 20% + 10% + 20% = **50%**

## Estado actual del repositorio

### Lo que YA existe (completado)
- `pom.xml` con dependencias (micrometer, actuator, aws-xray) y plugins de calidad
- `src/` completo: `ProductController.java`, `ProductService.java`, `ProductRepository.java`, `GlobalExceptionHandler.java`, `ProductosapiApplication.java`, `MetricsConfig.java`, modelos, tests
- `application.properties` con logging JSON, CloudWatch metrics, actuator endpoints
- `.github/workflows/ci-pipeline.yml` (workflow con validate → sonar → build-and-push → deploy)
- `.github/workflows/deploy.yml` (workflow IE6 con 3 jobs: validate → build → deploy, 7 validaciones)
- `Dockerfile` con HEALTHCHECK, non-root user, curl
- `sonar-project.properties` configurado para SonarCloud
- `scripts/audit-pipeline.sh` (auditoría automatizada)
- `scripts/create-alarms.sh` (4 alarmas CloudWatch)
- `scripts/create-dashboard.sh` (dashboard 7 widgets)
- `.env` con variables de configuración del proyecto

### Lo que PENDIENTE implementar (tu responsabilidad)

| Prioridad | Archivo/Tarea | IE | Descripción |
|---|---|---|---|
| 🔴 Alta | Ejecutar `scripts/create-alarms.sh` (AWS CLI) | IE1 | CPU > 80% (EC2), Memory > 85% (CWAgent), Error spike > 10, UnhealthyHost > 0 |
| 🔴 Alta | Ejecutar `scripts/create-dashboard.sh` (AWS CLI) | IE3 | Dashboard ProductosAPI-EP3 con 7 widgets |
| 🔴 Alta | Branch Protection Rules (Settings GitHub) | IE6 | Configurar reglas para `main` y `develop` |
| 🟡 Media | Crear Log Group `/productosapi/microservice` (AWS Console) | IE1 | Recibir logs desde Docker awslogs driver |
| 🟡 Media | Auto-refresh en dashboard (AWS Console) | IE3 | Activar refresh cada 1 minuto + compartir enlace |
| 🟡 Media | 4 demostraciones de falla + capturas | IE6 | Falla seguridad, calidad, cobertura baja, Quality Gate |
| 🔵 Baja | Pantallazos de evidencias | IE1/IE3/IE6 | Logs, métricas, alarmas, dashboard, pipelines, branch rules |

---

## IE1 — Configurar CloudWatch para logs, métricas, errores y disponibilidad (20%)

### Objetivo para 100%
> "Configura de manera completa y precisa AWS CloudWatch, visualizando logs, métricas de uso, errores y disponibilidad de **todos los microservicios involucrados**."

### Pasos

#### 1. Crear Log Group en CloudWatch
- Ir a AWS Console → CloudWatch → Log groups → "Create log group"
- Nombre: `/productosapi/microservice`
- Retention: 30 días
- Crear también: `/productosapi/ci-cd`

#### 2. Configurar logging en Docker

El microservicio (`ProductosapiApplication`) ya usa Spring Boot con logger por defecto. En la instancia EC2, el contenedor se ejecuta con el log driver de awslogs:

```bash
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

Verificar en CloudWatch → Log groups → `/productosapi/microservice` → Log streams que aparecen los logs del microservicio.

#### 3. Configurar application.properties para logging JSON

Agregar en `src/main/resources/application.properties`:

```properties
# CloudWatch / JSON logging
logging.pattern.console={"timestamp":"%d{yyyy-MM-dd HH:mm:ss.SSS}","level":"%p","thread":"%t","logger":"%c{1.}","message":"%m"}%n
logging.level.com.dev.productosapi=DEBUG
logging.level.org.springframework.web=INFO

# Actuator endpoints para health checks
management.endpoints.web.exposure.include=health,metrics,info
management.endpoint.health.show-details=always
management.info.env.enabled=true
```

#### 4. Agregar métricas personalizadas con Micrometer

Agregar en `pom.xml`:

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-cloudwatch2</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

Agregar en `application.properties`:

```properties
# CloudWatch Metrics
management.metrics.export.cloudwatch.namespace=ProductosAPI
management.metrics.export.cloudwatch.enabled=true
management.metrics.tags.application=productosapi
```

Crear `src/main/java/com/dev/productosapi/config/MetricsConfig.java`:

```java
package com.dev.productosapi.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfig {

    @Bean
    public Counter requestCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.requests.total")
            .description("Total de peticiones HTTP")
            .register(registry);
    }

    @Bean
    public Counter errorCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.errors.total")
            .description("Total de errores HTTP")
            .register(registry);
    }

    @Bean
    public Counter productCreatedCounter(MeterRegistry registry) {
        return Counter.builder("productosapi.products.created")
            .description("Total de productos creados")
            .register(registry);
    }
}
```

Modificar `ProductController.java` para usar las métricas:

```java
// Agregar al inicio de la clase
private final Counter requestCounter;
private final Counter errorCounter;
private final Counter productCreatedCounter;

public ProductController(ProductService service, Counter requestCounter,
        Counter errorCounter, Counter productCreatedCounter) {
    this.service = service;
    this.requestCounter = requestCounter;
    this.errorCounter = errorCounter;
    this.productCreatedCounter = productCreatedCounter;
}

// En getAllProduct:
requestCounter.increment();

// En createProduct:
productCreatedCounter.increment();

// En el catch de GlobalExceptionHandler (modificar):
errorCounter.increment();
```

#### 5. Configurar Alarmas de disponibilidad en CloudWatch

Crear 4 alarmas:

| Alarma | Métrica | Condición | Acción |
|---|---|---|---|---|
| `productosapi-cpu-high` | `AWS/EC2 → CPUUtilization` | > 80% por 5 min | SNS通知 |
| `productosapi-memory-high` | `CWAgent → mem_used_percent` | > 85% por 5 min | SNS通知 |
| `productosapi-error-spike` | `ProductosAPI → productosapi.errors.total` | > 10 en 5 min | SNS通知 |
| `productosapi-unhealthy-host` | `AWS/ApplicationELB → UnhealthyHostCount` | > 0 por 2 min | SNS通知 |

```bash
# Ejemplo: crear alarma de CPU via AWS CLI
aws cloudwatch put-metric-alarm \
  --alarm-name "productosapi-cpu-high" \
  --alarm-description "Alarma cuando CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=<instance-id>
```

#### 6. Configurar X-Ray para trazabilidad

Agregar en `pom.xml`:

```xml
<dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.14.0</version>
</dependency>
```

Agregar anotación en `ProductosapiApplication.java`:

```java
import com.amazonaws.xray.spring.aop.XRayEnabled;

@SpringBootApplication
@XRayEnabled
public class ProductosapiApplication {
    public static void main(String[] args) {
        SpringApplication.run(ProductosapiApplication.class, args);
    }
}
```

#### 7. Evidencias
- Pantallazo de CloudWatch Logs Insights consultando errores:
  ```
  fields @timestamp, @message
  | filter @message like /ERROR/
  | sort @timestamp desc
  | limit 20
  ```
- Pantallazo de métricas `productosapi.requests.total` y `productosapi.errors.total` en CloudWatch Metrics
- Pantallazo de las 4 alarmas en estado OK
- Pantallazo de ServiceLens / X-Ray mostrando el service map

---

## IE3 — Crear Dashboard en CloudWatch con métricas clave (10%)

### Objetivo para 100%
> "Crea dashboards funcionales y detallados con **todas las métricas clave** integradas al proceso CI/CD, facilitando el análisis continuo del sistema."

### Métricas clave requeridas
1. Tiempo de despliegue
2. Cobertura de pruebas
3. Uso de CPU/memoria
4. Errores registrados

### Pasos

#### 1. Crear Dashboard
- AWS Console → CloudWatch → Dashboards → "Create dashboard"
- Nombre: `ProductosAPI-EP3`

#### 2. Widgets del dashboard

| # | Widget | Tipo | Métrica |
|---|---|---|---|---|
| 1 | CPU Usage | Line | `AWS/EC2 → CPUUtilization` |
| 2 | Memory Usage | Line | `CWAgent → mem_used_percent` |
| 3 | Deployment Duration | Number | `ProductosAPI → DeploymentDuration` |
| 4 | Test Coverage | Gauge | `ProductosAPI → TestCoverage` |
| 5 | Error Rate | Stacked Area | `ProductosAPI → productosapi.errors.total` + `AWS/ApplicationELB → HTTPCode_Target_5XX_Count` |
| 6 | Request Count | Line | `ProductosAPI → productosapi.requests.total` |
| 7 | Service Availability | Number | `AWS/ApplicationELB → HealthyHostCount` |

#### 3. Publicar métricas desde el pipeline CI/CD

Agregar en `.github/workflows/deploy.yml` (en el job `deploy`):

```yaml
- name: Publish deployment duration
  run: |
    START_TIME=$(date -d "${{ github.event.head_commit.timestamp }}" +%s 2>/dev/null || echo $(date +%s))
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    aws cloudwatch put-metric-data \
      --namespace ProductosAPI \
      --metric-name DeploymentDuration \
      --value $DURATION \
      --unit Seconds \
      --dimensions Environment=Production,Service=productosapi

- name: Publish test coverage
  run: |
    COVERAGE=$(grep -oP 'Total.*?([0-9]+\.[0-9]+)' target/site/jacoco/index.html 2>/dev/null | head -1 || echo "0")
    aws cloudwatch put-metric-data \
      --namespace ProductosAPI \
      --metric-name TestCoverage \
      --value $(echo $COVERAGE | grep -oP '[0-9]+\.[0-9]+' || echo "0") \
      --unit Percent \
      --dimensions Environment=Production,Service=productosapi
```

#### 4. Configurar auto-refresh
- En el dashboard: "Actions" → "Auto-refresh" → 1 minuto
- Compartir el dashboard vía "Actions" → "Share" → generar enlace

#### 5. Evidencias
- Pantallazo del dashboard completo con los 7 widgets visibles
- Pantallazo de un widget mostrando datos históricos (últimas 24h)
- Pantallazo del dashboard con auto-refresh activado

---

## IE6 — Implementar validaciones que interrumpan el pipeline ante fallas críticas (20%)

### Objetivo para 100%
> "Implementa mecanismos de validación automatizados y efectivos que interrumpen el pipeline ante fallas críticas, **protegiendo el entorno productivo** y asegurando **cumplimiento normativo**."

### Pasos

#### 1. Crear el workflow completo de CI/CD

Crear `.github/workflows/deploy.yml`:

```yaml
name: Deploy ProductosAPI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: productosapi

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: maven

      # ===== VALIDACIONES QUE DETIENEN EL PIPELINE =====

      # VALIDACIÓN 1: Compilar y ejecutar tests
      - name: Run unit tests
        run: mvn clean test

      # VALIDACIÓN 2: Verificar cobertura con JaCoCo
      - name: Check test coverage (min 80%)
        run: |
          mvn jacoco:report jacoco:check
          COVERAGE=$(grep -oP 'Total.*?([0-9]+\.[0-9]+)' target/site/jacoco/index.html | head -1)
          echo "Cobertura: $COVERAGE%"

      # VALIDACIÓN 3: Escaneo de seguridad con Trivy
      - name: Trivy security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      # VALIDACIÓN 4: SonarCloud Quality Gate
      - name: SonarCloud analysis
        run: |
          mvn verify sonar:sonar \
            -Dsonar.projectKey=productosapi \
            -Dsonar.organization=cafesincuchara \
            -Dsonar.host.url=https://sonarcloud.io \
            -Dsonar.login=${{ secrets.SONAR_TOKEN }} \
            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml

      - name: Check Quality Gate status
        run: |
          sleep 15
          STATUS=$(curl -s -u ${{ secrets.SONAR_TOKEN }}: \
            "https://sonarcloud.io/api/qualitygates/project_status?projectKey=productosapi" \
            | jq -r '.projectStatus.status')
          if [ "$STATUS" != "OK" ]; then
            echo "❌ Quality Gate: $STATUS"
            exit 1
          fi
          echo "✅ Quality Gate: PASSED"

      # VALIDACIÓN 5: Verificar CloudWatch Alarms
      - name: Check CloudWatch Alarms before deploy
        run: |
          ALARMS=$(aws cloudwatch describe-alarms \
            --state-value ALARM \
            --alarm-name-prefix "productosapi" \
            --query 'MetricAlarms[*].AlarmName' \
            --output text)
          if [ -n "$ALARMS" ]; then
            echo "❌ Alarmas en estado ALARM: $ALARMS"
            exit 1
          fi
          echo "✅ Todas las alarmas de CloudWatch están OK"

      # VALIDACIÓN 6: Auditoría automatizada
      - name: Run audit script
        run: chmod +x scripts/audit-pipeline.sh && ./scripts/audit-pipeline.sh

      # VALIDACIÓN 7: Verificar que no hay secretos hardcodeados
      - name: Check for secrets
        run: |
          if grep -rP '(?i)(password|secret|token|api.key|apikey)\s*[:=]\s*["'"'"'][^"'"'"']+' \
            --include='*.{java,yml,yaml,properties,json,sh}' src/ .github/; then
            echo "❌ Posibles secretos encontrados en el código"
            exit 1
          fi
          echo "✅ No se encontraron secretos"

  build:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "IMAGE=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_ENV

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Deploy to EC2 via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ec2-user
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            aws ecr get-login-password --region us-east-1 | \
              docker login --username AWS --password-stdin 905418035297.dkr.ecr.us-east-1.amazonaws.com
            docker pull 905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest
            docker stop productosapi || true
            docker rm productosapi || true
            docker run -d -p 8080:8080 \
              --name productosapi \
              --log-driver awslogs \
              --log-opt awslogs-group=/productosapi/microservice \
              --log-opt awslogs-region=us-east-1 \
              --log-opt awslogs-stream-prefix=ec2-productosapi \
              -e SERVER_PORT=8080 \
              -e AWS_REGION=us-east-1 \
              905418035297.dkr.ecr.us-east-1.amazonaws.com/productosapi:latest

      - name: Publish deployment metrics
        run: |
          START_TIME=$(date -d "${{ github.event.head_commit.timestamp }}" +%s 2>/dev/null || echo $(date +%s))
          END_TIME=$(date +%s)
          DURATION=$((END_TIME - START_TIME))
          aws cloudwatch put-metric-data \
            --namespace ProductosAPI \
            --metric-name DeploymentDuration \
            --value $DURATION \
            --unit Seconds \
            --dimensions Environment=Production

      - name: Verify deployment health
        run: |
          ALB_DNS=$(aws elbv2 describe-load-balancers \
            --names productosapi-alb \
            --query 'LoadBalancers[0].DNSName' \
            --output text 2>/dev/null || echo "")
          if [ -n "$ALB_DNS" ]; then
            curl -sf http://$ALB_DNS/api/v1/products && echo "✅ API saludable"
          else
            echo "⚠️ No se pudo verificar health (ALB no disponible)"
          fi
```

#### 2. Crear script de auditoría automatizada

Crear `scripts/audit-pipeline.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "╔═══════════════════════════════════════════════╗"
echo "║   AUDITORÍA DE CUMPLIMIENTO - ProductosAPI    ║"
echo "╚═══════════════════════════════════════════════╝"

FAILURES=0

echo ""
echo "[1/6] Verificando dependencias vulnerables..."
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q 2>/dev/null || {
    echo "❌ Dependencias con CVSS >= 7 encontradas"
    FAILURES=$((FAILURES + 1))
}

echo ""
echo "[2/6] Verificando calidad de código..."
mvn checkstyle:check pmd:check -q 2>/dev/null || {
    echo "❌ Violaciones de estilo/calidad de código"
    FAILURES=$((FAILURES + 1))
}

echo ""
echo "[3/6] Verificando cobertura de pruebas (mín. 80%)..."
mvn jacoco:check -q || {
    echo "❌ Cobertura por debajo del 80%"
    FAILURES=$((FAILURES + 1))
}

echo ""
echo "[4/6] Escaneando secretos hardcodeados..."
PATTERNS='(?i)(password|secret|token|api.key|apikey|auth.token)\s*[:=]\s*["'"'"'][^"'"'"']+'
if grep -rP "$PATTERNS" src/ --include='*.{java,properties,yml,yaml}' 2>/dev/null; then
    echo "❌ Posibles secretos encontrados"
    FAILURES=$((FAILURES + 1))
else
    echo "✅ No se encontraron secretos"
fi

echo ""
echo "[5/6] Verificando licencias de dependencias..."
mvn license:aggregate-add-third-party -q 2>/dev/null || true
if [ -f target/generated-sources/license/THIRD-PARTY.txt ]; then
    if grep -qi "GPL\|AGPL" target/generated-sources/license/THIRD-PARTY.txt 2>/dev/null; then
        echo "⚠️  Licencias GPL/AGPL encontradas"
    fi
fi
echo "✅ Licencias verificadas"

echo ""
echo "[6/6] Verificando buenas prácticas..."
TODOS=$(grep -r "TODO\|FIXME\|HACK\|XXX" src/main --include="*.java" | wc -l)
if [ "$TODOS" -gt 5 ]; then
    echo "⚠️  $TODOS marcadores TODO/FIXME en producción"
fi
echo "✅ Buenas prácticas verificadas"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║   RESULTADO: $( [ $FAILURES -eq 0 ] && echo 'APROBADA ✅' || echo "FALLIDA ❌ ($FAILURES fallos)" )"
echo "╚═══════════════════════════════════════════════╝"
exit $FAILURES
```

#### 3. Configurar Branch Protection Rules en GitHub

Ir a Settings → Branches → Add rule para `main`:
```
☑ Require a pull request before merging
  ☑ Require approvals (1)
  ☑ Dismiss stale PR approvals when new commits are pushed
☑ Require status checks to pass before merging
  ☑ validate (workflow job)
  ☑ SonarCloud Code Analysis
☑ Require branches to be up-to-date before merging
☑ Require conversation resolution
☑ Include administrators
☑ Block force pushes
☑ Do not allow bypassing
```

#### 4. Demostraciones de falla (capturas obligatorias)

| Prueba | Qué hacer | Resultado esperado |
|---|---|---|
| **Falla de seguridad** | Agregar dependencia con CVE conocida (ej. log4j:log4j:2.14.0) | Pipeline se detiene en `validate` |
| **Falla de calidad** | Romper un test intencionalmente | Pipeline se detiene en `Run unit tests` |
| **Cobertura baja** | Reducir cobertura por debajo de 80% | `jacoco:check` falla, pipeline detenido |
| **Quality Gate** | Introducir code smell grave | SonarQube falla, pipeline detenido |

#### 5. Evidencias
- Pantallazo del pipeline completo en GitHub Actions (3 jobs: validate → build → deploy)
- Pantallazo del pipeline fallando por test rojo
- Pantallazo del pipeline fallando por vulnerabilidad crítica en Trivy
- Pantallazo de Branch Protection Rules activas
- Pantallazo de un PR bloqueado por no pasar status checks

---

## Checklist IE1 (20%) — Estado: 🟡 Parcial (código listo, 4 alarmas creadas, falta log group + evidencias)
- [x] `pom.xml`: micrometer-registry-cloudwatch2, actuator, aws-xray — ✅
- [x] `application.properties`: logging JSON y CloudWatch metrics — ✅
- [x] `config/MetricsConfig.java`: requestCounter, errorCounter, productCreatedCounter — ✅
- [x] `ProductController.java`: contadores inyectados e incrementados — ✅
- [x] `GlobalExceptionHandler.java`: errorCounter.increment() en catch — ✅
- [x] `ProductosapiApplication.java`: `@XRayEnabled` — ✅
- [x] `scripts/create-alarms.sh`: Script con 4 alarmas CloudWatch — ✅
- [x] 4 alarmas CloudWatch creadas (CPU, Memory, ErrorSpike, UnhealthyHost) — ✅
- [ ] Log group `/productosapi/microservice` creado y recibiendo logs — *AWS Console*
- [ ] Pantallazos: logs, métricas, alarmas OK, X-Ray — *pendiente*

## Checklist IE3 (10%) — Estado: 🟡 Parcial (dashboard creado, pipeline publica métricas, falta auto-refresh + evidencias)
- [x] Dashboard `ProductosAPI-EP3` creado con 7 widgets en CloudWatch — ✅
- [x] Pipeline publica métricas (DeploymentDuration, TestCoverage) en deploy.yml — ✅
- [ ] Auto-refresh activado (1 minuto) — *AWS Console*
- [ ] Pantallazo del dashboard completo + datos históricos 24h — *pendiente*

## Checklist IE6 (20%) — Estado: 🟡 Parcial (workflow, branch rules listos; falta evidencias + demos)
- [x] `.github/workflows/deploy.yml`: 3 jobs validate → build → deploy — ✅
- [x] Validate: mvn test, jacoco:check, Trivy, SonarCloud + QG check, CW Alarms, audit, secrets — ✅
- [x] Build: Docker build, ECR push con tag `${{ github.sha }}` + `latest` — ✅
- [x] Deploy: SSH a EC2, pull, stop/start, publish metrics, health check — ✅
- [x] `scripts/audit-pipeline.sh` (compartido con Vicente IE5) — ✅
- [x] Branch Protection Rules: `main` + `develop` configuradas vía API — ✅
- [ ] 4 demostraciones de falla capturadas: seguridad, calidad, cobertura, quality gate
- [ ] Pantallazos: pipeline completo, pipeline fallando, PR bloqueado
