<?xml version="1.0" encoding="UTF-8"?>
<!--
  test-map2mindmap-fo.xsl
  Unit tests for map2mindmap-fo.xsl (DITA map to XSL-FO/SVG PDF).
  Run: java -jar Saxon-HE-12.9.jar -xsl:test-map2mindmap-fo.xsl -it:run-tests
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <!-- Import the stylesheet under test -->
  <xsl:import href="../dita-ot-mindmap-plugin/xsl/map2mindmap-fo.xsl"/>

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- Test runner -->
  <xsl:template name="run-tests">
    <xsl:variable name="results" as="xs:string*">
      <!-- mm:count-leaves-fn tests -->
      <xsl:call-template name="test-count-leaves-single"/>
      <xsl:call-template name="test-count-leaves-nested"/>
      <xsl:call-template name="test-count-leaves-deep"/>
      <!-- mm:max-depth-fn tests -->
      <xsl:call-template name="test-max-depth-flat"/>
      <xsl:call-template name="test-max-depth-nested"/>
      <!-- mm:node-label tests -->
      <xsl:call-template name="test-label-navtitle-attr"/>
      <xsl:call-template name="test-label-navtitle-element"/>
      <xsl:call-template name="test-label-href-fallback"/>
      <xsl:call-template name="test-label-untitled"/>
      <!-- mm:truncate tests -->
      <xsl:call-template name="test-truncate-short"/>
      <xsl:call-template name="test-truncate-long"/>
      <xsl:call-template name="test-truncate-exact"/>
      <!-- mm:compute-svg-dims tests -->
      <xsl:call-template name="test-svg-dims-small"/>
      <xsl:call-template name="test-svg-dims-returns-3-values"/>
      <!-- mm:compute-bilateral-svg-dims tests -->
      <xsl:call-template name="test-bilateral-dims-symmetric"/>
      <xsl:call-template name="test-bilateral-dims-asymmetric"/>
      <!-- mm:font-size-for-node-h tests -->
      <xsl:call-template name="test-font-size-large"/>
      <xsl:call-template name="test-font-size-small"/>
      <xsl:call-template name="test-font-size-tiny"/>
      <!-- mm:node-bg-color tests -->
      <xsl:call-template name="test-fo-bg-color-valid"/>
      <xsl:call-template name="test-fo-bg-color-missing"/>
      <!-- bilateral variable test -->
      <xsl:call-template name="test-bilateral-default"/>
      <!-- max-chars-int tests -->
      <xsl:call-template name="test-max-chars-int-default"/>
    </xsl:variable>

    <xsl:variable name="passed" select="count($results[starts-with(., 'PASS')])"/>
    <xsl:variable name="failed" select="count($results[starts-with(., 'FAIL')])"/>

    <xsl:for-each select="$results">
      <xsl:value-of select="concat(., '&#10;')"/>
    </xsl:for-each>

    <xsl:text>&#10;==================================================&#10;</xsl:text>
    <xsl:value-of select="concat('map2mindmap-fo.xsl: ', $passed, ' passed, ', $failed, ' failed')"/>
    <xsl:text>&#10;==================================================&#10;</xsl:text>

    <xsl:if test="$failed gt 0">
      <xsl:message>
        <xsl:value-of select="concat('TESTS FAILED: ', $failed, ' failures')"/>
      </xsl:message>
    </xsl:if>
  </xsl:template>

  <!-- ================================================================
       Helpers
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

  <xsl:template name="assert-true">
    <xsl:param name="test-name" as="xs:string"/>
    <xsl:param name="condition" as="xs:boolean"/>
    <xsl:choose>
      <xsl:when test="$condition">
        <xsl:value-of select="concat('PASS: ', $test-name)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('FAIL: ', $test-name, ' — condition is false')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       mm:count-leaves-fn tests
       ================================================================ -->
  <xsl:template name="test-count-leaves-single">
    <xsl:variable name="node" as="element()">
      <topicref class="- map/topicref " navtitle="Leaf"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'count-leaves: single leaf = 1'"/>
      <xsl:with-param name="condition" select="mm:count-leaves-fn($node) = 1"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-count-leaves-nested">
    <xsl:variable name="node" as="element()">
      <topicref class="- map/topicref " navtitle="Parent">
        <topicref class="- map/topicref " navtitle="Child 1"/>
        <topicref class="- map/topicref " navtitle="Child 2"/>
        <topicref class="- map/topicref " navtitle="Child 3"/>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'count-leaves: parent with 3 children = 3'"/>
      <xsl:with-param name="condition" select="mm:count-leaves-fn($node) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-count-leaves-deep">
    <xsl:variable name="node" as="element()">
      <topicref class="- map/topicref " navtitle="Root">
        <topicref class="- map/topicref " navtitle="A">
          <topicref class="- map/topicref " navtitle="A1"/>
          <topicref class="- map/topicref " navtitle="A2"/>
        </topicref>
        <topicref class="- map/topicref " navtitle="B"/>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'count-leaves: 2 nested + 1 flat = 3'"/>
      <xsl:with-param name="condition" select="mm:count-leaves-fn($node) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:max-depth-fn tests
       ================================================================ -->
  <xsl:template name="test-max-depth-flat">
    <xsl:variable name="nodes" as="element()*">
      <topicref class="- map/topicref " navtitle="A"/>
      <topicref class="- map/topicref " navtitle="B"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'max-depth: flat children = depth 1'"/>
      <xsl:with-param name="condition" select="mm:max-depth-fn($nodes, 1) = 1"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-max-depth-nested">
    <xsl:variable name="nodes" as="element()*">
      <topicref class="- map/topicref " navtitle="A">
        <topicref class="- map/topicref " navtitle="A1">
          <topicref class="- map/topicref " navtitle="A1a"/>
        </topicref>
      </topicref>
      <topicref class="- map/topicref " navtitle="B"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'max-depth: 3-level deep = depth 3'"/>
      <xsl:with-param name="condition" select="mm:max-depth-fn($nodes, 1) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-label tests
       ================================================================ -->
  <xsl:template name="test-label-navtitle-attr">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="My Title"/>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'node-label: @navtitle used'"/>
      <xsl:with-param name="expected" select="'My Title'"/>
      <xsl:with-param name="actual" select="mm:node-label($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-label-navtitle-element">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref ">
        <topicmeta class="- map/topicmeta ">
          <navtitle class="- topic/navtitle ">Element Title</navtitle>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'node-label: topicmeta/navtitle element preferred'"/>
      <xsl:with-param name="expected" select="'Element Title'"/>
      <xsl:with-param name="actual" select="mm:node-label($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-label-href-fallback">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " href="topics/my-topic.dita"/>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'node-label: @href fallback (strip path + extension)'"/>
      <xsl:with-param name="expected" select="'my-topic'"/>
      <xsl:with-param name="actual" select="mm:node-label($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-label-untitled">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref "/>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'node-label: fallback to Untitled'"/>
      <xsl:with-param name="expected" select="'Untitled'"/>
      <xsl:with-param name="actual" select="mm:node-label($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:truncate tests
       ================================================================ -->
  <xsl:template name="test-truncate-short">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'truncate: short text unchanged'"/>
      <xsl:with-param name="expected" select="'Hello'"/>
      <xsl:with-param name="actual" select="mm:truncate('Hello', 20)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-truncate-long">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'truncate: long text gets ellipsis'"/>
      <xsl:with-param name="expected" select="'This is a very long...'"/>
      <xsl:with-param name="actual" select="mm:truncate('This is a very long text here', 20)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-truncate-exact">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'truncate: exactly max length unchanged'"/>
      <xsl:with-param name="expected" select="'12345678901234567890'"/>
      <xsl:with-param name="actual" select="mm:truncate('12345678901234567890', 20)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:compute-svg-dims tests
       ================================================================ -->
  <xsl:template name="test-svg-dims-small">
    <xsl:variable name="dims" select="mm:compute-svg-dims(5, 2)"/>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-true">
        <xsl:with-param name="test-name" select="'svg-dims: width positive for 5 leaves, depth 2'"/>
        <xsl:with-param name="condition" select="$dims[1] gt 0"/>
      </xsl:call-template>
      <xsl:call-template name="assert-true">
        <xsl:with-param name="test-name" select="'svg-dims: height positive'"/>
        <xsl:with-param name="condition" select="$dims[2] gt 0"/>
      </xsl:call-template>
      <xsl:call-template name="assert-true">
        <xsl:with-param name="test-name" select="'svg-dims: eff-h within range'"/>
        <xsl:with-param name="condition" select="$dims[3] ge $min-node-h and $dims[3] le $node-h"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-svg-dims-returns-3-values">
    <xsl:variable name="dims" select="mm:compute-svg-dims(10, 3)"/>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'svg-dims: returns exactly 3 values'"/>
      <xsl:with-param name="condition" select="count($dims) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:compute-bilateral-svg-dims tests
       ================================================================ -->
  <xsl:template name="test-bilateral-dims-symmetric">
    <xsl:variable name="dims" select="mm:compute-bilateral-svg-dims(10, 10, 2, 2)"/>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-true">
        <xsl:with-param name="test-name" select="'bilateral-dims: returns 3 values'"/>
        <xsl:with-param name="condition" select="count($dims) = 3"/>
      </xsl:call-template>
      <xsl:call-template name="assert-true">
        <xsl:with-param name="test-name" select="'bilateral-dims: width includes both sides'"/>
        <xsl:with-param name="condition" select="$dims[1] gt ($node-w * 3)"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-bilateral-dims-asymmetric">
    <xsl:variable name="dims-sym" select="mm:compute-bilateral-svg-dims(10, 10, 2, 2)"/>
    <xsl:variable name="dims-asym" select="mm:compute-bilateral-svg-dims(5, 15, 2, 3)"/>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'bilateral-dims: asymmetric has different width'"/>
      <xsl:with-param name="condition" select="$dims-asym[1] != $dims-sym[1]"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:font-size-for-node-h tests
       ================================================================ -->
  <xsl:template name="test-font-size-large">
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'font-size: 32px node → size 10'"/>
      <xsl:with-param name="condition" select="mm:font-size-for-node-h(32) = 10"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-font-size-small">
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'font-size: 22px node → size 9'"/>
      <xsl:with-param name="condition" select="mm:font-size-for-node-h(22) = 9"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-font-size-tiny">
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'font-size: 16px node → size 7'"/>
      <xsl:with-param name="condition" select="mm:font-size-for-node-h(16) = 7"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-bg-color (FO variant) tests
       ================================================================ -->
  <xsl:template name="test-fo-bg-color-valid">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-color" value="#abc"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'fo:bg-color: 3-digit hex valid'"/>
      <xsl:with-param name="expected" select="'#abc'"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-fo-bg-color-missing">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test"/>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'fo:bg-color: missing returns empty'"/>
      <xsl:with-param name="expected" select="''"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       bilateral variable test (default page-size is A4)
       ================================================================ -->
  <xsl:template name="test-bilateral-default">
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'bilateral: A4-landscape default is false'"/>
      <xsl:with-param name="condition" select="not($bilateral)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       max-chars-int variable test (default param '20' → integer 20)
       ================================================================ -->
  <xsl:template name="test-max-chars-int-default">
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'max-chars-int: default value is 20'"/>
      <xsl:with-param name="condition" select="$max-chars-int = 20"/>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
