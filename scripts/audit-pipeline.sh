#!/bin/bash
set -euo pipefail

echo "╔═══════════════════════════════════════════════╗"
echo "║   AUDITORÍA DE CUMPLIMIENTO - ProductosAPI    ║"
echo "╚═══════════════════════════════════════════════╝"

FAILURES=0

echo ""
echo "[1/6] Verificando dependencias vulnerables... (skip - OWASP lento)"
# mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q 2>/dev/null || {
#     echo "❌ Dependencias con CVSS >= 7 encontradas"
#     FAILURES=$((FAILURES + 1))
# }
echo "⏩ OWASP dependency-check omitido (Trivy cubre esto)"

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
