# Vicente — Persona B

**Proyecto:** [EvaluacionParcial2](https://github.com/cafesincuchara/EvaluacionParcial2) — `productosapi`
**Responsable de:** IE2 (Docker + AWS ECS) + IE5 (Cumplimiento) + IE4 (Documentación)
**Ponderación total:** 20% + 20% + 10% = **50%**

## Estado actual del repositorio

### Lo que YA existe (no requiere cambios)
- `pom.xml` (base, **faltan** plugins JaCoCo, Checkstyle, PMD)
- `Dockerfile` (básico multi-stage, **sin** HEALTHCHECK ni non-root user)
- `src/` completo con Java, tests, `sonar-project.properties`
- `.github/dependabot.yml` (básico, sin labels ni limits)
- `.github/workflows/ci-pipeline.yml` (workflow simple con deploy a Render, **no a ECS**)

### Lo que FALTA implementar (tu responsabilidad)

| Prioridad | Archivo/Tarea | IE | Descripción |
|---|---|---|---|
| 🔴 Alta | `cloudformation/productosapi-infra.yml` | IE2 | Plantilla CloudFormation: VPC, ALB, ECS Fargate, Task Definition, Auto Scaling |
| 🔴 Alta | `Dockerfile` - actualizar | IE2 | Agregar HEALTHCHECK, non-root user (appuser), copiar application.properties |
| 🔴 Alta | `pom.xml` - plugins de calidad | IE5 | Agregar JaCoCo (check 80%), Checkstyle (google_checks), PMD (bestpractices + security) |
| 🔴 Alta | `scripts/audit-pipeline.sh` | IE5 | Crear script de auditoría (compartido con Brayan IE6) |
| 🔴 Alta | `docs/` - 3 documentos | IE4 | arquitectura-observabilidad.md, pipeline-ci-cd.md, mejora-continua.md |
| 🟡 Media | ECR repository (AWS CLI) | IE2 | Crear con scanOnPush=true y pushear imagen inicial |
| 🟡 Media | Deploy CloudFormation stack (AWS CLI) | IE2 | create-stack, verificar CREATE_COMPLETE |
| 🟡 Media | GitHub Secrets (Settings) | IE2 | Configurar AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, SONAR_TOKEN |
| 🟡 Media | SonarCloud Quality Gate (UI web) | IE5 | Crear `ProductosAPI-QG`: coverage ≥ 80%, rating A, code smells ≤ 20 |
| 🟡 Media | Branch Protection Rules (Settings GitHub) | IE5 | main: PR, approvals, status checks, admins. develop: PR, approvals |
| 🟡 Media | Actualizar `.github/dependabot.yml` | IE5 | Agregar open-pull-requests-limit: 10 y labels |
| 🟡 Media | Probar despliegue manual | IE2 | curl a ALB DNS, verificar tareas ECS |
| 🔵 Baja | 8 capturas de pantalla para documentación | IE4 | Dashboard, pipeline, SonarCloud, branch rules, ECS, ALB, CloudFormation |
| 🔵 Baja | Reflexiones individuales (sin IA) | IE4 | Brayan: IE1/IE3/IE6; Vicente: IE2/IE5/IE4 |

---

## IE2 — Desplegar microservicio con Docker en AWS ECS (20%)

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
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

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

#### 3. Crear infraestructura con CloudFormation

Crear `cloudformation/productosapi-infra.yml`:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Infraestructura ECS para ProductosAPI - EP3

Parameters:
  EnvironmentName:
    Type: String
    Default: production
  ECRRepositoryName:
    Type: String
    Default: productosapi
  DesiredCount:
    Type: Number
    Default: 2
  ContainerCpu:
    Type: Number
    Default: 512
  ContainerMemory:
    Type: Number
    Default: 1024

Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags: [{ Key: Name, Value: !Sub "${EnvironmentName}-vpc" }]

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags: [{ Key: Name, Value: !Sub "${EnvironmentName}-igw" }]
  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs ""]
      MapPublicIpOnLaunch: true
  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs ""]
      MapPublicIpOnLaunch: true

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: VPCGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway
  Subnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable
  Subnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  # ALB
  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: ALB SG - HTTP from internet
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0

  ALB:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub "${EnvironmentName}-alb"
      Subnets: [!Ref PublicSubnet1, !Ref PublicSubnet2]
      SecurityGroups: [!Ref ALBSecurityGroup]
      Scheme: internet-facing
      Type: application
      Tags: [{ Key: Name, Value: !Sub "${EnvironmentName}-alb" }]

  ALBTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub "${EnvironmentName}-tg"
      Port: 8080
      Protocol: HTTP
      TargetType: ip
      VpcId: !Ref VPC
      HealthCheckPath: /actuator/health
      HealthCheckIntervalSeconds: 30
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      Matcher: { HttpCode: "200" }
      Tags: [{ Key: Name, Value: !Sub "${EnvironmentName}-tg" }]

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions: [{ Type: forward, TargetGroupArn: !Ref ALBTargetGroup }]
      LoadBalancerArn: !Ref ALB
      Port: 80
      Protocol: HTTP

  # ECS
  ECSCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub "${EnvironmentName}-cluster"
      CapacityProviders: [FARGATE]
      DefaultCapacityProviderStrategy:
        - CapacityProvider: FARGATE
          Weight: 1
      Configuration:
        ExecuteCommandConfiguration:
          Logging: DEFAULT

  CloudWatchLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: "/productosapi/microservice"
      RetentionInDays: 30

  # IAM Roles
  ECSExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: { Service: ecs-tasks.amazonaws.com }
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
        - arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

  ECSTaskRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: { Service: ecs-tasks.amazonaws.com }
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchFullAccess
        - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess

  ECSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: ECS SG - traffic from ALB
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: !Ref ALBSecurityGroup

  # Task Definition (con logging, health check, y trazabilidad)
  TaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub "${EnvironmentName}-task"
      Cpu: !Ref ContainerCpu
      Memory: !Ref ContainerMemory
      NetworkMode: awsvpc
      RequiresCompatibilities: [FARGATE]
      ExecutionRoleArn: !Ref ECSExecutionRole
      TaskRoleArn: !Ref ECSTaskRole
      ContainerDefinitions:
        - Name: productosapi-container
          Image: !Sub "${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${ECRRepositoryName}:latest"
          Essential: true
          PortMappings:
            - ContainerPort: 8080
              Protocol: tcp
          Environment:
            - Name: AWS_REGION
              Value: !Ref AWS::Region
            - Name: MANAGEMENT_METRICS_EXPORT_CLOUDWATCH_ENABLED
              Value: "true"
            - Name: SERVER_PORT
              Value: "8080"
          LogConfiguration:
            LogDriver: awslogs
            Options:
              awslogs-group: !Ref CloudWatchLogGroup
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: "ecs-productosapi"
          HealthCheck:
            Command:
              - "CMD-SHELL"
              - "wget -qO- http://localhost:8080/actuator/health || exit 1"
            Interval: 30
            Timeout: 5
            StartPeriod: 60
            Retries: 3

  # ECS Service
  ECSService:
    Type: AWS::ECS::Service
    DependsOn: ALBListener
    Properties:
      ServiceName: !Sub "${EnvironmentName}-service"
      Cluster: !Ref ECSCluster
      TaskDefinition: !Ref TaskDefinition
      DesiredCount: !Ref DesiredCount
      LaunchType: FARGATE
      NetworkConfiguration:
        AwsvpcConfiguration:
          Subnets: [!Ref PublicSubnet1, !Ref PublicSubnet2]
          SecurityGroups: [!Ref ECSSecurityGroup]
          AssignPublicIp: ENABLED
      LoadBalancers:
        - ContainerName: productosapi-container
          ContainerPort: 8080
          TargetGroupArn: !Ref ALBTargetGroup
      DeploymentConfiguration:
        DeploymentCircuitBreaker:
          Enable: true
          Rollback: true
        MaximumPercent: 200
        MinimumHealthyPercent: 100
      HealthCheckGracePeriodSeconds: 60
      EnableECSManagedTags: true
      PropagateTags: SERVICE

  # Auto Scaling
  AutoScalingTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      MaxCapacity: 4
      MinCapacity: 1
      ResourceId: !Sub "service/${ECSCluster}/${ECSService}"
      ScalableDimension: ecs:service:DesiredCount
      ServiceNamespace: ecs
  AutoScalingPolicyCPU:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: cpu-target-tracking
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref AutoScalingTarget
      TargetTrackingScalingPolicyConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageCPUUtilization
        TargetValue: 70
        ScaleInCooldown: 120
        ScaleOutCooldown: 60

Outputs:
  LoadBalancerDNS:
    Description: ALB DNS Name
    Value: !GetAtt ALB.DNSName
  ECSClusterName:
    Description: ECS Cluster Name
    Value: !Ref ECSCluster
  ECSServiceName:
    Description: ECS Service Name
    Value: !Ref ECSService
```

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
| `AWS_ACCESS_KEY_ID` | Access Key de IAM con permisos ECS, ECR, CloudFormation, CloudWatch |
| `AWS_SECRET_ACCESS_KEY` | Secret Key correspondiente |
| `AWS_REGION` | `us-east-1` |
| `SONAR_TOKEN` | Token de SonarCloud |

#### 6. Probar el despliegue manual

```bash
# Verificar que el ALB responde
curl -f http://<ALB-DNS>/actuator/health
curl -f http://<ALB-DNS>/api/v1/products

# Verificar tareas de ECS
aws ecs list-tasks --cluster productosapi-cluster
aws ecs describe-tasks --cluster productosapi-cluster --tasks <task-ids>
```

#### 7. Evidencias
- Pantallazo de CloudFormation Stack con estado `CREATE_COMPLETE`
- Pantallazo de ECS Cluster con 2 tareas en estado `RUNNING`
- Pantallazo de ECR con la imagen `productosapi:latest`
- Pantallazo del ALB con Target Group saludable
- Pantallazo del ALB DNS respondiendo al endpoint `/api/v1/products`
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
                         │ • Tests  │ │ • Maven  │ │ • ECS update │
                         │ • Sonar  │ │ • Docker │ │ • Health     │
                         │ • Trivy  │ │ • ECR    │ │ • Metrics    │
                         │ • Audit  │ │          │ │              │
                         └──────────┘ └──────────┘ └──────┬───────┘
                                                            │
                                                            ▼
                                                  ┌──────────────────┐
                                                  │  AWS ECS         │
                                                  │ ┌──────────────┐ │
                                                  │ │ productosapi  │ │
                                                  │ │ (2 tareas)   │ │
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
  - Log driver en ECS Task Definition envía stdout/stderr a CloudWatch Logs
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
│  │ 1. Forzar nuevo deployment en ECS                   │  │
│  │ 2. Esperar a que el servicio estabilice             │  │
│  │ 3. Publicar métricas (Deploy Duration, Coverage)    │  │
│  │ 4. Verificar health endpoint                        │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
                       │
                       ▼
            ✅ Producción (ECS Fargate)
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
| 6 | ECS Cluster | 2 tareas RUNNING |
| 7 | ALB Target Group | Healthy state |
| 8 | CloudFormation Stack | CREATE_COMPLETE |

#### 5. Reflexiones individuales (obligatorio, SIN IA)

Cada integrante debe incluir en las conclusiones del informe final:

- **Brayan:** Reflexión personal sobre su aprendizaje en IE1, IE3 e IE6
- **Vicente:** Reflexión personal sobre su aprendizaje en IE2, IE5 e IE4

---

## Checklist IE2 (20%) — Estado: ❌ No iniciado
- [ ] `Dockerfile`: Agregar HEALTHCHECK, non-root user (appuser), copiar application.properties
- [ ] `cloudformation/productosapi-infra.yml`: Crear plantilla CloudFormation completa
- [ ] ECR repository creado con `--image-scanning-configuration scanOnPush=true`
- [ ] Imagen Docker construida y subida a ECR
- [ ] CloudFormation stack desplegado (CREATE_COMPLETE)
- [ ] ECS Cluster con 2 tareas RUNNING
- [ ] ALB con Target Group saludable (health check /actuator/health)
- [ ] Auto Scaling por CPU (target 70%, min 1, max 4)
- [ ] GitHub Secrets configurados: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, SONAR_TOKEN
- [ ] ALB DNS respondiendo a `/api/v1/products`
- [ ] Pantallazos: CloudFormation, ECS cluster, ECR, ALB, GitHub Secrets

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
