# Evaluación Parcial 2 - Pipeline CI/CD
## Arquitectura del Pipeline

El proceso está automatizado usando GitHub Actions y se divide en 4 pasos principales que se ejecutan en orden:

1. Test: Se compila el proyecto y se corren las pruebas unitarias usando Maven.
2. Sonar: Se analiza el código con SonarCloud para detectar vulnerabilidades o bugs.
3. Docker: Se construye la imagen del contenedor de forma optimizada.
4. Deploy: Se despliega automáticamente la aplicación en un entorno simulado.

## Orquestación y Escalabilidad
Para levantar la aplicación hemos decidido usar Docker Compose.
Para asegurar que el sistema sea estable y escalable, configuramos el archivo docker-compose.yml con:
Réplicas: Definimos 2 réplicas del servicio para tener alta disponibilidad.
Límites de recursos: Le asignamos un máximo de 0.50 CPUs y 512MB de memoria RAM a cada contenedor, 
esto es para evitar que la aplicación consuma todos los recursos y bote el servidor.

## Trazabilidad y Calidad
Vicente Herrera
Para asegurar que nunca llegue código con errores a producción, configuramos el pipeline para que sea estrictamente secuencial,
esto lo logramos usando el parámetro needs en GitHub Actions. El paso de "Deploy" depende obligatoriamente de que el paso 
de "Docker" haya terminado bien, el cual a su vez depende de "Sonar" y "Test". Si una prueba unitaria falla o 
Sonar detecta un problema de seguridad grave, el proceso se corta inmediatamente y no se despliega nada.

## Declaración de uso de IA
Durante el trabajo, utilizamos Gemini como apoyo técnico para:
Entender cómo escribir correctamente la sintaxis de los límites de memoria y CPU en el archivo docker-compose.yml.
Entender cómo conectar los jobs en GitHub Actions para asegurar la trazabilidad.

## Reflexiones Individuales
Brayan Gonzalez

yo he comprendido q el funcionamiento de la orquestacion basicamente
seria el manual de instrucciones para el servidor al cual subimos nuestro proyecto, 
en el fondo seria como queremos q el lo ejecute y el despliegue vendria siendo la orden final
que le damos una vez superadas todas las pruebas del pipeline y que bueno todo esto tendria como
finalidad tener una mayor eficiencia ya que mientras los programadores escriben codigo todo los demas procesos 
que tengan que ver con pruebas esto lo haria la maquina automaticamente, no habria errores gracias a las 
reglas que definimos, y la escabilidad,  que en pocas palabras gracias al compose el servidor ya sabria 
como manejar esos recursos sin asfixiarse por la reparticion del trafico en el compose
Vicente Herrera


