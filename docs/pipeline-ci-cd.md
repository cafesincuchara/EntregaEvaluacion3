# Pipeline CI/CD - ProductosAPI

## Flujo

Cada vez que se hace push a `main` o `develop`, el pipeline corre estos pasos en orden:

```
Push -> [Validate] -> [Build] -> [Deploy] -> Produccion
```

### Validate (si falla, se detiene todo)
- Tests unitarios (JUnit 5)
- JaCoCo: cobertura minima 80%
- SonarCloud: Quality Gate
- Checkstyle + PMD: calidad de codigo
- Script de auditoria

### Build
- Compilar con Maven
- Construir imagen Docker
- Subir a Amazon ECR

### Deploy
- Forzar nuevo deployment en ECS Fargate
- Esperar que el servicio estabilice
- Verificar health endpoint

## Seguridad
- Nadie hace push directo a `main` (branch protection)
- Las credenciales AWS estan en GitHub Secrets
- Dependabot revisa dependencias cada semana
