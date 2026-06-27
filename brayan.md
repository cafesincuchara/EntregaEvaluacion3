# Brayan — Guía de tareas pendientes

**Responsable de:** IE5 (Políticas de cumplimiento) + IE6 (Pipeline se detiene ante fallas)
**Ponderación total:** 20% + 20% = **40%**

> ⚠️ Todo lo relacionado con AWS (EC2, ALB, ECR, CloudWatch alarms/dashboard/log groups) lo realiza Vicente. Brayan solo se enfoca en GitHub, SonarCloud, pipeline y capturas.

---

## Tarea 1 — Obtener SONAR_TOKEN (🔴 Alta prioridad)

### Paso 1: Generar token en SonarCloud
1. Ir a https://sonarcloud.io → Iniciar sesión con GitHub
2. Entrar a la organización `cafesincuchara`
3. Ir a **Account** → **Security** → **Generate Tokens**
4. Nombre: `productosapi-token` → Generate → **Copiar el token** (no se vuelve a ver)

### Paso 2: Crear GitHub Secret
1. Ir al repo → Settings → Secrets and variables → Actions → **New repository secret**
2. Name: `SONAR_TOKEN`
3. Secret: pegar el token copiado
4. Add secret

---

## Tarea 2 — Configurar Quality Gate en SonarCloud (IE5)

### Qué hacer en SonarCloud:
1. Ir a https://sonarcloud.io → proyecto `productosapi` → Quality Gates
2. Crear Quality Gate llamado `ProductosAPI-QG`
3. Configurar condiciones:
   - **Coverage** ≥ 80% → Error
   - **Maintainability Rating** = A → Error
   - **Code Smells** ≤ 20 → Error
4. Marcarlo como Quality Gate **por defecto** del proyecto

### Verificar en el pipeline:
El workflow `deploy.yml` ya tiene un step que chequea el Quality Gate después del análisis de SonarCloud. Si el QG falla, el pipeline se detiene automáticamente.

---

## Tarea 3 — Verificar Branch Protection Rules (IE5)

Ya están configuradas vía API, pero verificar manualmente:
1. Repo → Settings → Branches → **Branch protection rules**
2. `main` debe tener:
   - ☑ Require a pull request before merging
   - ☑ Require approvals (1)
   - ☑ Require status checks (`validate`, `SonarCloud Code Analysis`)
   - ☑ Include administrators
   - ☑ Block force pushes
3. `develop` debe tener:
   - ☑ Require a pull request before merging
   - ☑ Require approvals (1)
   - ☑ Require status checks (`validate`)
4. Si falta algo, corregir manualmente en la UI

---

## Tarea 4 — 4 Demostraciones de falla + capturas (IE6)

Para cada una: **crear una branch, hacer el cambio, crear PR a main, capturar pantallazo del pipeline fallando, luego revertir**.

### Falla 1 — Seguridad (Trivy)
```xml
<!-- En pom.xml, agregar dependencia con CVE conocida: -->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.14.0</version>  <!-- CVE-2021-44228 -->
</dependency>
```
**Resultado:** Trivy detecta vulnerabilidad CRÍTICA → pipeline detenido en validate

### Falla 2 — Calidad (test rojo)
```java
// En un test, romper una aserción intencionalmente:
assertEquals(999, 1);  // va a fallar
```
**Resultado:** `mvn test` falla → pipeline detenido en validate

### Falla 3 — Cobertura baja (JaCoCo)
```java
// Agregar un método NUEVO sin test:
public String metodoSinTest() { return "sin cobertura"; }
```
**Resultado:** JaCoCo detecta cobertura < 80% → `jacoco:check` falla → pipeline detenido

### Falla 4 — Quality Gate (SonarCloud)
```java
// Agregar código con code smell grave:
public void metodoLargo() {
    // repetir lógica 50 veces...
}
```
**Resultado:** SonarCloud Quality Gate falla → pipeline detenido

### Para cada falla, capturar:
1. Código modificado
2. Pipeline en GitHub Actions mostrando el job `validate` en rojo
3. Pipeline detenido (jobs `build` y `deploy` no ejecutados)

---

## Tarea 5 — Capturas de evidencia (IE6)

Tomar pantallazos de:

| # | Qué capturar | Dónde |
|---|---|---|
| 1 | Pipeline completo exitoso (3 jobs: validate → build → deploy en verde) | GitHub Actions |
| 2 | Pipeline fallando por seguridad (Trivy) | GitHub Actions |
| 3 | Pipeline fallando por calidad (test rojo) | GitHub Actions |
| 4 | Pipeline fallando por cobertura (JaCoCo) | GitHub Actions |
| 5 | Pipeline fallando por Quality Gate (SonarCloud) | GitHub Actions |
| 6 | Branch Protection Rules de `main` | Settings → Branches |
| 7 | PR bloqueado por status checks | Pull Requests |
| 8 | Quality Gate en SonarCloud | SonarCloud → Quality Gates |

Las capturas se guardan en `docs/assets/` y se referencian en los archivos de documentación.

---

## Resumen de entregables de Brayan

| Tarea | IE | Estado |
|---|---|---|
| SONAR_TOKEN generado y configurado | IE5 | ❌ Pendiente |
| Quality Gate configurado en SonarCloud | IE5 | ❌ Pendiente |
| Branch Protection verificada | IE5 | ✅ Hecho (verificar) |
| Demo falla #1 — Seguridad (Trivy) + captura | IE6 | ❌ Pendiente |
| Demo falla #2 — Test rojo + captura | IE6 | ❌ Pendiente |
| Demo falla #3 — Cobertura baja + captura | IE6 | ❌ Pendiente |
| Demo falla #4 — Quality Gate + captura | IE6 | ❌ Pendiente |
| Captura pipeline exitoso | IE6 | ❌ Pendiente |
| Captura PR bloqueado | IE6 | ❌ Pendiente |
