# Mejora Continua - ProductosAPI

## Ciclo

### 1. Monitorear
El dashboard de CloudWatch muestra en tiempo real CPU, memoria, errores, cobertura, tiempo de deploy.

### 2. Analizar
- Si el tiempo de deploy sube mucho, revisar el Dockerfile
- Si la cobertura baja, agregar tests antes de aceptar PRs
- Si los errores aumentan, priorizar fixes

### 3. Decidir
| Situacion | Accion |
|---|---|
| Deploy duration > 5 min | Optimizar build cache |
| Coverage < 80% | Agregar tests |
| Error rate > 3% | Rollback y debug |
| CPU > 70% sostenido | Ajustar auto-scaling |

### 4. Mejorar
- Cada sprint revisar dashboards y ajustar thresholds
- Agregar nuevas validaciones segun incidentes
- Actualizar Quality Gate cuando sea necesario
