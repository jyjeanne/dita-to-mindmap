<?xml version="1.0" encoding="UTF-8"?>
<!--
  mindmap2jsmind.xsl
  XSLT 3.0 stylesheet for transforming custom <mindmap> XML format
  into jsMind node_tree JSON.

  This is for standalone use with the custom <mindmap> XML format
  defined in the project specs. For DITA map input via DITA-OT,
  use map2mindmap-html.xsl instead.

  Usage: saxon -s:sample-mindmap.xml -xsl:mindmap2jsmind.xsl -o:output.json
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <xsl:output method="text" encoding="UTF-8" indent="no"/>

  <!-- ================================================================
       Function: mm:escape-json
       Escapes a string for safe embedding in JSON string values.
       ================================================================ -->
  <xsl:function name="mm:escape-json" as="xs:string">
    <xsl:param name="str" as="xs:string"/>
    <xsl:value-of select="
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace($str, '\\', '\\\\'),
                '&quot;', '\\&quot;'),
              '&#10;', '\\n'),
            '&#13;', '\\r'),
          '&#9;', '\\t'),
        '/', '\\/'),
      '&lt;', '\\u003c')
    "/>
  </xsl:function>

  <!-- ================================================================
       Root template: match <mindmap> and generate JSON envelope
       ================================================================ -->
  <xsl:template match="/mindmap">
    <xsl:text>{&#10;</xsl:text>
    <xsl:text>  "meta": {"name": "</xsl:text>
    <xsl:value-of select="mm:escape-json(string(node/@title))"/>
    <xsl:text>"},&#10;</xsl:text>
    <xsl:text>  "format": "node_tree",&#10;</xsl:text>
    <xsl:text>  "data": </xsl:text>
    <xsl:apply-templates select="node">
      <xsl:with-param name="indent" select="'    '"/>
    </xsl:apply-templates>
    <xsl:text>&#10;}</xsl:text>
  </xsl:template>

  <!-- ================================================================
       Node template: recursive JSON generation
       ================================================================ -->
  <xsl:template match="node">
    <xsl:param name="indent" as="xs:string" select="'  '"/>
    <xsl:variable name="child-indent" select="concat($indent, '  ')"/>

    <xsl:text>{&#10;</xsl:text>

    <!-- id -->
    <xsl:value-of select="$indent"/>
    <xsl:text>"id": "</xsl:text>
    <xsl:value-of select="mm:escape-json(string(@id))"/>
    <xsl:text>",&#10;</xsl:text>

    <!-- topic (from @title) -->
    <xsl:value-of select="$indent"/>
    <xsl:text>"topic": "</xsl:text>
    <xsl:value-of select="mm:escape-json(string(@title))"/>
    <xsl:text>"</xsl:text>

    <!-- expanded -->
    <xsl:text>,&#10;</xsl:text>
    <xsl:value-of select="$indent"/>
    <xsl:text>"expanded": </xsl:text>
    <xsl:value-of select="if (@expanded = 'true') then 'true' else 'false'"/>

    <!-- data object: background-color, icon, url -->
    <xsl:variable name="has-data" as="xs:boolean"
        select="exists(@color) or exists(@icon) or exists(@url)"/>
    <xsl:if test="$has-data">
      <xsl:text>,&#10;</xsl:text>
      <xsl:value-of select="$indent"/>
      <xsl:text>"data": {</xsl:text>
      <xsl:variable name="data-parts" as="xs:string*">
        <xsl:if test="@color">
          <xsl:sequence select="concat('&quot;background-color&quot;: &quot;', mm:escape-json(string(@color)), '&quot;')"/>
        </xsl:if>
        <xsl:if test="@icon">
          <xsl:sequence select="concat('&quot;icon&quot;: &quot;', mm:escape-json(string(@icon)), '&quot;')"/>
        </xsl:if>
        <xsl:if test="@url">
          <xsl:sequence select="concat('&quot;url&quot;: &quot;', mm:escape-json(string(@url)), '&quot;')"/>
        </xsl:if>
      </xsl:variable>
      <xsl:value-of select="string-join($data-parts, ', ')"/>
      <xsl:text>}</xsl:text>
    </xsl:if>

    <!-- children -->
    <xsl:if test="node">
      <xsl:text>,&#10;</xsl:text>
      <xsl:value-of select="$indent"/>
      <xsl:text>"children": [&#10;</xsl:text>
      <xsl:for-each select="node">
        <xsl:if test="position() gt 1">
          <xsl:text>,&#10;</xsl:text>
        </xsl:if>
        <xsl:value-of select="$child-indent"/>
        <xsl:apply-templates select=".">
          <xsl:with-param name="indent" select="concat($child-indent, '  ')"/>
        </xsl:apply-templates>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
      <xsl:value-of select="$indent"/>
      <xsl:text>]</xsl:text>
    </xsl:if>

    <xsl:text>&#10;</xsl:text>
    <xsl:value-of select="substring($indent, 3)"/>
    <xsl:text>}</xsl:text>
  </xsl:template>

</xsl:stylesheet>
