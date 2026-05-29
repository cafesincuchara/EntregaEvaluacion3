# Evaluacion Parcial 2 - Pipeline CI/CD

**Integrantes:** Brayan Gonzalez, Vicente Herrera  
**Repositorio:** [EvaluacionParcial2](https://github.com/cafesincuchara/EvaluacionParcial2)  
**API en produccion:** [https://productosapi-eta0.onrender.com](https://productosapi-eta0.onrender.com)  
**SonarCloud:** [https://sonarcloud.io/dashboard?id=productosapi](https://sonarcloud.io/dashboard?id=productosapi&branch=main)

---

## Resumen del proyecto

Microservicio REST en Spring Boot 3.4 con operaciones CRUD de productos (GET, POST, PUT, DELETE) y base de datos H2 en memoria. El pipeline automatiza todo el ciclo de vida: compilar, testear, analizar calidad, contenerizar, y desplegar.

---

## Pipeline CI/CD (GitHub Actions)

El pipeline se ejecuta en cada push a `main` o `develop` y esta compuesto por 4 jobs secuenciales:

```
[push] → [test] → [sonar] → [docker] → [deploy]
```

Cada job depende del anterior mediante `needs`, asi si algo falla en el camino no se sigue adelante.

### 1. test
Compila el proyecto y ejecuta 15 pruebas unitarias con JUnit 5 y Mockito. Usa el wrapper de Maven con JDK 21 (Temurin) y cachea las dependencias.

### 2. sonar
Analiza el codigo con SonarCloud usando el plugin de Maven. Escanea bugs, code smells, vulnerabilidades y coverage. Si el quality gate falla, el pipeline se detiene y no despliega.

### 3. docker
Construye la imagen del contenedor con Docker Buildx usando un Dockerfile multi-stage. La imagen se etiqueta con el SHA del commit para trazabilidad.

### 4. Despliegue en Render
Llama a la API de Render (`POST /v1/services/{id}/deploys`) para activar un deploy automatico del servicio.

---

## IE1 - Contenerizacion (Dockerfile)

Usamos un Dockerfile multi-stage:

- **Stage 1 (builder):** imagen `maven:3.9.9-eclipse-temurin-21-alpine`, compila el JAR.
- **Stage 2 (runtime):** imagen `eclipse-temurin:21-jre-alpine`, minima y segura, solo copia el JAR.
- El puerto se configura con `${PORT:-8080}` para que Render lo asigne dinamicamente.

Incluimos un `.dockerignore` para excluir `target/`, `.git/`, `.idea/` y archivos markdown, reduciendo el contexto de build.

---

## IE2 - Pruebas automatizadas

Tenemos 3 clases de prueba con JUnit 5:

| Clase | Tipo | Cantidad |
|-------|------|----------|
| `ProductosapiApplicationTests` | Contexto de Spring | 1 test |
| `ProductControllerTest` | MockMvc (controlador) | 6 tests |
| `ProductServiceTest` | Mockito (servicio) | 8 tests |
| **Total** | | **15 tests** |

Cubrimos todos los casos: listar, obtener por ID (existente y no encontrado), crear, actualizar y eliminar. Las pruebas se ejecutan primero en el pipeline y si alguna falla no se sigue.

---

## IE3 - Seguridad y calidad

- **Dependabot:** configurado para revisar semanalmente dependencias de Maven y GitHub Actions, crea PRs automaticos cuando hay versiones nuevas.
- **SonarCloud:** analiza el codigo en cada push a `main`. Busca vulnerabilidades, bugs, code smells y duplicacion. Configurado con `sonar.organization=cafesincuchara` en el `pom.xml`.
- **Bloqueo por seguridad:** el pipeline es secuencial con `needs`. Si SonarCloud encuentra un problema grave (quality gate fallado), el job `sonar` falla y no se ejecutan `docker` ni `deploy`. Asi aseguramos que codigo con problemas no llegue a produccion.

---

## IE4 - Despliegue automatico y trazabilidad

El despliegue se hace automaticamente contra **Render** usando su API REST. Cuando los 3 jobs anteriores pasan, el job `deploy` envia un POST al endpoint de deploys con el token de API (guardado en GitHub Secrets).

**Trazabilidad:**
- El pipeline usa `needs` entre todos los jobs, por lo que cada etapa queda registrada en GitHub Actions.
- La imagen Docker se etiqueta con `${{ github.sha }}` para saber exactamente que commit genero cada deploy.
- El servicio vive en `https://productosapi-eta0.onrender.com`.

---

## IE5 - Orquestacion (Docker Compose)

Configuramos `docker-compose.yml` con:

- **2 replicas** del servicio para tolerancia a fallos y balanceo de carga basico.
- **Limites de recursos:** cada contenedor tiene un maximo de 0.50 CPUs y 512MB de RAM, con reservas de 0.25 CPUs y 256MB.
- **Politica de reinicio:** `on-failure` para que si un contenedor se cae inesperadamente se levante solo.
- Variables de entorno manejadas con `env_file: .env`.

```bash
# Para levantar localmente
docker compose up -d
```

---

## Declaracion de uso de IA

Durante el trabajo usamos Gemini como apoyo tecnico para:
- Entender la sintaxis de limites de memoria y CPU en docker-compose.yml.
- Conectar los jobs en GitHub Actions con `needs` para asegurar la trazabilidad.
- Estructurar y mejorar la redaccion de este README.

---

## Reflexiones Individuales

**Brayan Gonzalez**

yo he comprendido q el funcionamiento de la orquestacion basicamente
seria el manual de instrucciones para el servidor al cual subimos nuestro proyecto,
en el fondo seria como queremos q el lo ejecute y el despliegue vendria siendo la orden final
que le damos una vez superadas todas las pruebas del pipeline y que bueno todo esto tendria como
finalidad tener una mayor eficiencia ya que mientras los programadores escriben codigo todo los demas procesos
que tengan que ver con pruebas esto lo haria la maquina automaticamente, no habria errores gracias a las
reglas que definimos, y la escabilidad, que en pocas palabras gracias al compose el servidor ya sabria
como manejar esos recursos sin asfixiarse por la reparticion del trafico en el compose

**Vicente Herrera**
La IA siempre servira para poder ayudar en los trabajos que nos toma tiempo organizar y llevar acabo, 
es nuestro deber como estudiantes el saber como usarla para aprender mas de lo sabemos. Durante el proyecto 
aprendi de mejor manera el uso de API keys y su gran manejo para poder usar paginas como sonar, render etc. 
Tener tantos servicios puede ser cansador pero con GitHub Action siempre se mejora la productividad de los jobs que puede repetir y 
lanzar.
