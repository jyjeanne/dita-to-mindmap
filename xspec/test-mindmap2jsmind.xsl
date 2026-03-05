<?xml version="1.0" encoding="UTF-8"?>
<!--
  test-mindmap2jsmind.xsl
  Unit tests for mindmap2jsmind.xsl (custom XML to jsMind JSON).
  Run: java -jar Saxon-HE-12.9.jar -xsl:test-mindmap2jsmind.xsl -it:run-tests
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <!-- Import the stylesheet under test -->
  <xsl:import href="../dita-ot-mindmap-plugin/xsl/mindmap2jsmind.xsl"/>

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- Test runner -->
  <xsl:template name="run-tests">
    <xsl:variable name="results" as="xs:string*">
      <xsl:call-template name="test-escape-json-plain"/>
      <xsl:call-template name="test-escape-json-quotes"/>
      <xsl:call-template name="test-escape-json-backslash"/>
      <xsl:call-template name="test-escape-json-newline"/>
      <xsl:call-template name="test-escape-json-tab"/>
      <xsl:call-template name="test-escape-json-slash"/>
      <xsl:call-template name="test-escape-json-html"/>
      <xsl:call-template name="test-escape-json-empty"/>
      <xsl:call-template name="test-simple-node-json"/>
      <xsl:call-template name="test-node-with-color"/>
      <xsl:call-template name="test-node-with-icon"/>
      <xsl:call-template name="test-node-with-all-data"/>
      <xsl:call-template name="test-node-with-url-in-data"/>
      <xsl:call-template name="test-node-with-children"/>
      <xsl:call-template name="test-root-mindmap"/>
    </xsl:variable>

    <xsl:variable name="passed" select="count($results[starts-with(., 'PASS')])"/>
    <xsl:variable name="failed" select="count($results[starts-with(., 'FAIL')])"/>

    <xsl:for-each select="$results">
      <xsl:value-of select="concat(., '&#10;')"/>
    </xsl:for-each>

    <xsl:text>&#10;==================================================&#10;</xsl:text>
    <xsl:value-of select="concat('mindmap2jsmind.xsl: ', $passed, ' passed, ', $failed, ' failed')"/>
    <xsl:text>&#10;==================================================&#10;</xsl:text>

    <xsl:if test="$failed gt 0">
      <xsl:message>
        <xsl:value-of select="concat('TESTS FAILED: ', $failed, ' failures')"/>
      </xsl:message>
    </xsl:if>
  </xsl:template>

  <!-- ================================================================
       Helper: assert-equals
       ================================================================ -->
  <xsl:template name="assert-equals">
    <xsl:param name="test-name" as="xs:string"/>
    <xsl:param name="expected" as="xs:string"/>
    <xsl:param name="actual" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$expected = $actual">
        <xsl:value-of select="concat('PASS: ', $test-name)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('FAIL: ', $test-name, ' — expected [', $expected, '] but got [', $actual, ']')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="assert-contains">
    <xsl:param name="test-name" as="xs:string"/>
    <xsl:param name="haystack" as="xs:string"/>
    <xsl:param name="needle" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="contains($haystack, $needle)">
        <xsl:value-of select="concat('PASS: ', $test-name)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('FAIL: ', $test-name, ' — [', $haystack, '] does not contain [', $needle, ']')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       mm:escape-json tests
       ================================================================ -->
  <xsl:template name="test-escape-json-plain">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: plain text unchanged'"/>
      <xsl:with-param name="expected" select="'Hello World'"/>
      <xsl:with-param name="actual" select="mm:escape-json('Hello World')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-quotes">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: double quotes escaped'"/>
      <xsl:with-param name="expected" select="'say \&quot;hello\&quot;'"/>
      <xsl:with-param name="actual" select="mm:escape-json('say &quot;hello&quot;')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-backslash">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: backslash escaped'"/>
      <xsl:with-param name="expected" select="'path\\to\\file'"/>
      <xsl:with-param name="actual" select="mm:escape-json('path\to\file')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-newline">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: newline escaped'"/>
      <xsl:with-param name="expected" select="'line1\nline2'"/>
      <xsl:with-param name="actual" select="mm:escape-json(concat('line1', '&#10;', 'line2'))"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-tab">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: tab escaped'"/>
      <xsl:with-param name="expected" select="'col1\tcol2'"/>
      <xsl:with-param name="actual" select="mm:escape-json(concat('col1', '&#9;', 'col2'))"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-slash">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: forward slash escaped'"/>
      <xsl:with-param name="expected" select="'a\/b'"/>
      <xsl:with-param name="actual" select="mm:escape-json('a/b')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-html">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: HTML angle bracket escaped'"/>
      <xsl:with-param name="expected" select="'\u003cp>'"/>
      <xsl:with-param name="actual" select="mm:escape-json('&lt;p>')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-escape-json-empty">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'escape-json: empty string unchanged'"/>
      <xsl:with-param name="expected" select="''"/>
      <xsl:with-param name="actual" select="mm:escape-json('')"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       Node template tests (using inline XML)
       ================================================================ -->
  <xsl:template name="test-simple-node-json">
    <xsl:variable name="test-node" as="element()">
      <node id="n1" title="Test Node"/>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'simple-node: has id'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;id&quot;: &quot;n1&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'simple-node: has topic'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;topic&quot;: &quot;Test Node&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'simple-node: expanded false'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;expanded&quot;: false'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-node-with-color">
    <xsl:variable name="test-node" as="element()">
      <node id="c1" title="Colored" color="#ff0000"/>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:call-template name="assert-contains">
      <xsl:with-param name="test-name" select="'node-with-color: has background-color data'"/>
      <xsl:with-param name="haystack" select="$result"/>
      <xsl:with-param name="needle" select="'&quot;background-color&quot;: &quot;#ff0000&quot;'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-node-with-icon">
    <xsl:variable name="test-node" as="element()">
      <node id="i1" title="With Icon" icon="info"/>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:call-template name="assert-contains">
      <xsl:with-param name="test-name" select="'node-with-icon: has icon in data'"/>
      <xsl:with-param name="haystack" select="$result"/>
      <xsl:with-param name="needle" select="'&quot;icon&quot;: &quot;info&quot;'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-node-with-all-data">
    <xsl:variable name="test-node" as="element()">
      <node id="a1" title="Full Node" color="#ff7f0e" icon="gear" url="topic.dita"/>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-all-data: has background-color'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;background-color&quot;: &quot;#ff7f0e&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-all-data: has icon'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;icon&quot;: &quot;gear&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-all-data: has url'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;url&quot;: &quot;topic.dita&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-all-data: all in same data object'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;data&quot;: {'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-node-with-url-in-data">
    <xsl:variable name="test-node" as="element()">
      <node id="u1" title="Link Node" url="prerequis.dita"/>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:call-template name="assert-contains">
      <xsl:with-param name="test-name" select="'node-url: url is in data object'"/>
      <xsl:with-param name="haystack" select="$result"/>
      <xsl:with-param name="needle" select="'&quot;url&quot;: &quot;prerequis.dita&quot;'"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-node-with-children">
    <xsl:variable name="test-node" as="element()">
      <node id="p1" title="Parent">
        <node id="c1" title="Child 1"/>
        <node id="c2" title="Child 2"/>
      </node>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-node">
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:apply-templates>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-with-children: has children array'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;children&quot;: ['"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-with-children: contains Child 1'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;topic&quot;: &quot;Child 1&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-with-children: contains Child 2'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;topic&quot;: &quot;Child 2&quot;'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-root-mindmap">
    <xsl:variable name="test-doc">
      <mindmap>
        <node id="root" title="My Mindmap" expanded="true">
          <node id="b1" title="Branch 1">
            <node id="l1" title="Leaf 1"/>
          </node>
          <node id="b2" title="Branch 2"/>
        </node>
      </mindmap>
    </xsl:variable>
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates select="$test-doc/mindmap"/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'root-mindmap: has meta name'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;name&quot;: &quot;My Mindmap&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'root-mindmap: has format node_tree'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;format&quot;: &quot;node_tree&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'root-mindmap: has root id'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;id&quot;: &quot;root&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'root-mindmap: has nested leaf'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;topic&quot;: &quot;Leaf 1&quot;'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

</xsl:stylesheet>
