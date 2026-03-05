<?xml version="1.0" encoding="UTF-8"?>
<!--
  test-map2mindmap-html.xsl
  Unit tests for map2mindmap-html.xsl (DITA map to jsMind HTML).
  Run: java -jar Saxon-HE-12.9.jar -xsl:test-map2mindmap-html.xsl -it:run-tests
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <!-- Import the stylesheet under test -->
  <xsl:import href="../dita-ot-mindmap-plugin/xsl/map2mindmap-html.xsl"/>

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- Test runner -->
  <xsl:template name="run-tests">
    <xsl:variable name="results" as="xs:string*">
      <!-- mm:escape-json tests -->
      <xsl:call-template name="test-escape-json-combined"/>
      <!-- mm:escape-js-single tests -->
      <xsl:call-template name="test-escape-js-single"/>
      <!-- mm:is-visible-topicref tests -->
      <xsl:call-template name="test-visible-topicref"/>
      <xsl:call-template name="test-invisible-resource-only"/>
      <xsl:call-template name="test-invisible-toc-no"/>
      <!-- mm:node-bg-color tests -->
      <xsl:call-template name="test-bg-color-valid-hex"/>
      <xsl:call-template name="test-bg-color-named"/>
      <xsl:call-template name="test-bg-color-invalid"/>
      <xsl:call-template name="test-bg-color-missing"/>
      <!-- mm:node-fg-color tests -->
      <xsl:call-template name="test-fg-color-valid"/>
      <!-- mm:node-font-weight tests -->
      <xsl:call-template name="test-font-weight-bold"/>
      <xsl:call-template name="test-font-weight-invalid"/>
      <!-- mm:node-line-color tests -->
      <xsl:call-template name="test-line-color-valid"/>
      <!-- mm:effective-children tests -->
      <xsl:call-template name="test-effective-children-basic"/>
      <xsl:call-template name="test-effective-children-topicgroup"/>
      <xsl:call-template name="test-effective-children-filter"/>
      <!-- node-to-json template tests -->
      <xsl:call-template name="test-node-json-basic"/>
      <xsl:call-template name="test-node-json-with-data"/>
      <xsl:call-template name="test-node-json-bilateral"/>
    </xsl:variable>

    <xsl:variable name="passed" select="count($results[starts-with(., 'PASS')])"/>
    <xsl:variable name="failed" select="count($results[starts-with(., 'FAIL')])"/>

    <xsl:for-each select="$results">
      <xsl:value-of select="concat(., '&#10;')"/>
    </xsl:for-each>

    <xsl:text>&#10;==================================================&#10;</xsl:text>
    <xsl:value-of select="concat('map2mindmap-html.xsl: ', $passed, ' passed, ', $failed, ' failed')"/>
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

  <xsl:template name="assert-contains">
    <xsl:param name="test-name" as="xs:string"/>
    <xsl:param name="haystack" as="xs:string"/>
    <xsl:param name="needle" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="contains($haystack, $needle)">
        <xsl:value-of select="concat('PASS: ', $test-name)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat('FAIL: ', $test-name, ' — does not contain [', $needle, ']')"/>
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
       mm:escape-json combined test
       ================================================================ -->
  <xsl:template name="test-escape-json-combined">
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'html:escape-json: quotes + slash'"/>
      <xsl:with-param name="expected" select="'a\/b \&quot;c\&quot;'"/>
      <xsl:with-param name="actual" select="mm:escape-json('a/b &quot;c&quot;')"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:escape-js-single tests
       ================================================================ -->
  <xsl:template name="test-escape-js-single">
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-equals">
        <xsl:with-param name="test-name" select="'escape-js-single: plain text'"/>
        <xsl:with-param name="expected" select="'hello'"/>
        <xsl:with-param name="actual" select="mm:escape-js-single('hello')"/>
      </xsl:call-template>
      <xsl:call-template name="assert-equals">
        <xsl:with-param name="test-name" select="'escape-js-single: single quote escaped'"/>
        <xsl:with-param name="expected" select="'it\''s'"/>
        <xsl:with-param name="actual" select="mm:escape-js-single('it''s')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <!-- ================================================================
       mm:is-visible-topicref tests
       ================================================================ -->
  <xsl:template name="test-visible-topicref">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Visible"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'is-visible: normal topicref is visible'"/>
      <xsl:with-param name="condition" select="mm:is-visible-topicref($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-invisible-resource-only">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " processing-role="resource-only" navtitle="Hidden"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'is-visible: resource-only is hidden'"/>
      <xsl:with-param name="condition" select="not(mm:is-visible-topicref($ref))"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-invisible-toc-no">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " toc="no" navtitle="No TOC"/>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'is-visible: toc=no is hidden'"/>
      <xsl:with-param name="condition" select="not(mm:is-visible-topicref($ref))"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-bg-color tests
       ================================================================ -->
  <xsl:template name="test-bg-color-valid-hex">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-color" value="#1f77b4"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'bg-color: valid 6-digit hex'"/>
      <xsl:with-param name="expected" select="'#1f77b4'"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-bg-color-named">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-color" value="red"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'bg-color: named color accepted'"/>
      <xsl:with-param name="expected" select="'red'"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-bg-color-invalid">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-color" value="rgb(1,2,3)"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'bg-color: invalid format rejected'"/>
      <xsl:with-param name="expected" select="''"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-bg-color-missing">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test"/>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'bg-color: missing returns empty'"/>
      <xsl:with-param name="expected" select="''"/>
      <xsl:with-param name="actual" select="mm:node-bg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-fg-color test
       ================================================================ -->
  <xsl:template name="test-fg-color-valid">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-fg-color" value="#fff"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'fg-color: valid 3-digit hex'"/>
      <xsl:with-param name="expected" select="'#fff'"/>
      <xsl:with-param name="actual" select="mm:node-fg-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-font-weight tests
       ================================================================ -->
  <xsl:template name="test-font-weight-bold">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-font-weight" value="bold"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'font-weight: bold accepted'"/>
      <xsl:with-param name="expected" select="'bold'"/>
      <xsl:with-param name="actual" select="mm:node-font-weight($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-font-weight-invalid">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-font-weight" value="700"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'font-weight: numeric rejected'"/>
      <xsl:with-param name="expected" select="''"/>
      <xsl:with-param name="actual" select="mm:node-font-weight($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:node-line-color test
       ================================================================ -->
  <xsl:template name="test-line-color-valid">
    <xsl:variable name="ref" as="element()">
      <topicref class="- map/topicref " navtitle="Test">
        <topicmeta class="- map/topicmeta ">
          <data class="- topic/data " name="mindmap-line-color" value="#00cc00"/>
        </topicmeta>
      </topicref>
    </xsl:variable>
    <xsl:call-template name="assert-equals">
      <xsl:with-param name="test-name" select="'line-color: valid hex accepted'"/>
      <xsl:with-param name="expected" select="'#00cc00'"/>
      <xsl:with-param name="actual" select="mm:node-line-color($ref)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       mm:effective-children tests
       ================================================================ -->
  <xsl:template name="test-effective-children-basic">
    <xsl:variable name="parent" as="element()">
      <map class="- map/map ">
        <topicref class="- map/topicref " navtitle="A"/>
        <topicref class="- map/topicref " navtitle="B"/>
        <topicref class="- map/topicref " navtitle="C"/>
      </map>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'effective-children: 3 basic topicrefs'"/>
      <xsl:with-param name="condition" select="count(mm:effective-children($parent)) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-effective-children-topicgroup">
    <xsl:variable name="parent" as="element()">
      <map class="- map/map ">
        <topicref class="- map/topicref " navtitle="A"/>
        <topicgroup class="- map/topicref mapgroup-d/topicgroup ">
          <topicref class="- map/topicref " navtitle="B1"/>
          <topicref class="- map/topicref " navtitle="B2"/>
        </topicgroup>
      </map>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'effective-children: topicgroup promotes children (3 total)'"/>
      <xsl:with-param name="condition" select="count(mm:effective-children($parent)) = 3"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="test-effective-children-filter">
    <xsl:variable name="parent" as="element()">
      <map class="- map/map ">
        <topicref class="- map/topicref " navtitle="Visible"/>
        <topicref class="- map/topicref " navtitle="Hidden" processing-role="resource-only"/>
        <topicref class="- map/topicref " navtitle="No TOC" toc="no"/>
      </map>
    </xsl:variable>
    <xsl:call-template name="assert-true">
      <xsl:with-param name="test-name" select="'effective-children: filters resource-only and toc=no'"/>
      <xsl:with-param name="condition" select="count(mm:effective-children($parent)) = 1"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ================================================================
       node-to-json template tests
       ================================================================ -->
  <xsl:template name="test-node-json-basic">
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:call-template name="node-to-json">
          <xsl:with-param name="node-id" select="'test1'"/>
          <xsl:with-param name="node-topic" select="'Test Topic'"/>
          <xsl:with-param name="is-root" select="true()"/>
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:call-template>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-basic: has id'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;id&quot;: &quot;test1&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-basic: has topic'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;topic&quot;: &quot;Test Topic&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-basic: root is expanded'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;expanded&quot;: true'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-node-json-with-data">
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:call-template name="node-to-json">
          <xsl:with-param name="node-id" select="'styled'"/>
          <xsl:with-param name="node-topic" select="'Styled Node'"/>
          <xsl:with-param name="node-bg-color" select="'#ff0000'"/>
          <xsl:with-param name="node-fg-color" select="'#ffffff'"/>
          <xsl:with-param name="node-font-weight" select="'bold'"/>
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:call-template>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="checks" as="xs:string*">
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-data: has data object'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;data&quot;:'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-data: has background-color'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;background-color&quot;: &quot;#ff0000&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-data: has foreground-color'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;foreground-color&quot;: &quot;#ffffff&quot;'"/>
      </xsl:call-template>
      <xsl:call-template name="assert-contains">
        <xsl:with-param name="test-name" select="'node-json-data: has font-weight'"/>
        <xsl:with-param name="haystack" select="$result"/>
        <xsl:with-param name="needle" select="'&quot;font-weight&quot;: &quot;bold&quot;'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="$checks"/>
  </xsl:template>

  <xsl:template name="test-node-json-bilateral">
    <xsl:variable name="result" as="xs:string">
      <xsl:value-of>
        <xsl:call-template name="node-to-json">
          <xsl:with-param name="node-id" select="'branch1'"/>
          <xsl:with-param name="node-topic" select="'Left Branch'"/>
          <xsl:with-param name="node-direction" select="'left'"/>
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:call-template>
      </xsl:value-of>
    </xsl:variable>
    <xsl:call-template name="assert-contains">
      <xsl:with-param name="test-name" select="'node-json-bilateral: has direction left'"/>
      <xsl:with-param name="haystack" select="$result"/>
      <xsl:with-param name="needle" select="'&quot;direction&quot;: &quot;left&quot;'"/>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
