# EntregaEvaluacion3 — ProductosAPI

Microservicio Spring Boot 3.4 con Java 21, Maven, desplegado en AWS.

## Build & test

```bash
./mvnw clean test          # Tests unitarios + JaCoCo coverage
./mvnw clean compile       # Compilar sin tests
./mvnw clean install -DskipTests  # Build completo
```

## Estructura

```
src/main/java/com/dev/productosapi/
├── controller/   → ProductController (REST)
├── service/      → ProductService (lógica)
├── repository/   → ProductRepository (JPA)
├── model/        → Product (entidad)
├── config/       → MetricsConfig
└── exception/    → GlobalExceptionHandler, ErrorResponse
```

## Pipeline CI/CD (GitHub Actions)

3 jobs secuenciales: `validate → build → deploy`
- validate: tests + JaCoCo (80%) + Trivy + SonarCloud + auditoría
- build: compilar + Dockerizar + push a ECR
- deploy: SSH a EC2 + pull + restart

## AWS

- ALB: `http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/api/v1/products`
- ECR + EC2 + Docker + CloudWatch
- Dashboard con 7 widgets

## Skills cargados automáticamente

- java-spring (por pom.xml)
- database-sql (por migraciones si existen)
