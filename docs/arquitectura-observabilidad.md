# Arquitectura de Observabilidad - ProductosAPI

## Diagrama de flujo

```
[Dev] -> [GitHub] -> [GitHub Actions]
                        |
            +-----------+-----------+
            |           |           |
            v           v           v
      [Validate]    [Build]     [Deploy]
      (tests,       (Maven,     (ECS,
       Sonar,        Docker,     health,
       audit)        ECR)        metrics)
                        |
                        v
                  [AWS ECS Fargate]
                  (2 tareas)
                        |
            +-----------+-----------+
            |                       |
            v                       v
      [CloudWatch Logs]      [CloudWatch Metrics]
```

## Evidencias

![EC2 instancia](assets/ec2-instance.png)
![ECR imagenes](assets/ecr-images.png)
![ALB + TG healthy](assets/alb-tg-healthy.png)
![curl ALB response](assets/curl-alb-response.png)

## Herramientas

| Herramienta | Para que sirve |
|---|---|
| CloudWatch Logs | Guarda los logs del microservicio (stdout/stderr) |
| CloudWatch Metrics | Metricas de CPU, memoria, etc. |
| SonarCloud | Calidad de codigo y cobertura |
| GitHub Actions | Pipeline CI/CD automatizado |

## Decisiones basadas en datos

| Metrica | Si pasa esto | Decision |
|---|---|---|
| Quality Gate falla | Codigo no cumple | No desplegar |
| Cobertura < 80% | Faltan tests | Agregar tests |
| CPU > 70% | Mucha carga | Escalar servicio |
| Error rate > 5% | Errores frecuentes | Hacer rollback |
