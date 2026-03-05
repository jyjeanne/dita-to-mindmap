#!/bin/bash
# Run all XSLT unit tests using Saxon HE
# Must be run from the project root directory
# Usage: bash xspec/run-tests.sh

DITA_OT_LIB="build/dita-ot/dita-ot-4.4/lib"

if [ ! -f "$DITA_OT_LIB/Saxon-HE-12.9.jar" ]; then
  echo "ERROR: Saxon JAR not found. Run './gradlew downloadDitaOt' first."
  exit 1
fi

# Build classpath with Saxon + xmlresolver dependencies (semicolon for Windows)
CP="$DITA_OT_LIB/Saxon-HE-12.9.jar;$DITA_OT_LIB/xmlresolver-5.3.3.jar;$DITA_OT_LIB/xmlresolver-5.3.3-data.jar"

FAILED=0
TOTAL=0

for test_file in xspec/test-*.xsl; do
  test_name=$(basename "$test_file" .xsl)
  echo ""
  echo "Running: $test_name"
  echo "--------------------------------------------------"
  TOTAL=$((TOTAL + 1))

  OUTPUT=$(java -cp "$CP" net.sf.saxon.Transform \
    -xsl:"$test_file" \
    -it:run-tests 2>&1)

  echo "$OUTPUT"

  if echo "$OUTPUT" | grep -q "^FAIL:"; then
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=================================================="
echo "Test Suites: $((TOTAL - FAILED))/$TOTAL passed"
echo "=================================================="

exit $FAILED
