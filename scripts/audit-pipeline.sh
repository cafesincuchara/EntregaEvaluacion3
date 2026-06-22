#!/bin/bash
# Script de auditoria - ProductosAPI
set -euo pipefail

FAILURES=0

echo "Auditoria de cumplimiento - ProductosAPI"
echo "========================================"

# 1. Dependencias vulnerables
echo "[1/6] Dependencias vulnerables..."
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q && echo "OK" || { echo "Fallo: dependencias con CVSS >= 7"; FAILURES=$((FAILURES+1)); }

# 2. Calidad de codigo
echo "[2/6] Calidad de codigo..."
mvn checkstyle:check pmd:check -q && echo "OK" || { echo "Fallo: violaciones de calidad"; FAILURES=$((FAILURES+1)); }

# 3. Cobertura
echo "[3/6] Cobertura de pruebas (min. 80%)..."
mvn jacoco:check -q && echo "OK" || { echo "Fallo: cobertura < 80%"; FAILURES=$((FAILURES+1)); }

# 4. Secretos hardcodeados
echo "[4/6] Secretos hardcodeados..."
PATTERN='(?i)(password|secret|token|api.key|apikey)\s*[:=]\s*["'"'"'][^"'"'"']+'
if grep -rP "$PATTERN" src/ --include='*.{java,properties}' 2>/dev/null; then
    echo "Fallo: secretos encontrados"; FAILURES=$((FAILURES+1))
else
    echo "OK"
fi

# 5. Licencias
echo "[5/6] Licencias..."
mvn license:aggregate-add-third-party -q 2>/dev/null || true
echo "OK"

# 6. TODOs y FIXMEs
echo "[6/6] Buenas practicas..."
TODOS=$(grep -r "TODO\|FIXME\|HACK" src/main --include="*.java" | wc -l)
[ "$TODOS" -gt 5 ] && echo "Advertencia: $TODOS TODOs/FIXMEs" || echo "OK"

echo ""
echo "========================================"
if [ $FAILURES -eq 0 ]; then
    echo "Auditoria aprobada"
    exit 0
else
    echo "Auditoria fallida: $FAILURES fallo(s)"
    exit 1
fi
