<?xml version="1.0" encoding="UTF-8"?>
<!--
  map2mindmap-html.xsl
  XSLT 3.0 stylesheet for DITA-OT mindmap-html transtype.
  Transforms a resolved DITA map into a standalone HTML page
  with an interactive jsMind mindmap visualization.

  Features:
  - Filters @processing-role="resource-only" and @toc="no"
  - Topicgroup transparency (children promoted to parent)
  - Topichead support (label-only nodes)
  - JSON control character escaping
  - Bilateral layout (left/right) in full mode
  - Node styling: background-color, foreground-color, font-weight, leading-line-color
  - Zoom and expand-to-depth controls
  - Draggable mindmap view
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <xsl:output method="html" encoding="UTF-8" indent="yes"
              html-version="5" include-content-type="no"/>

  <!-- Parameters passed from Ant build.xml -->
  <xsl:param name="jsmind-theme" as="xs:string" select="'primary'"/>
  <xsl:param name="jsmind-editable" as="xs:string" select="'false'"/>
  <xsl:param name="jsmind-mode" as="xs:string" select="'full'"/>
  <xsl:param name="mindmap-lang" as="xs:string" select="'en'"/>

  <!-- ================================================================
       Function: mm:escape-json
       Escapes a string for safe embedding in JSON values inside
       HTML <script> blocks.
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
       Function: mm:escape-js-single
       Escapes a string for safe embedding in a JS single-quoted string.
       ================================================================ -->
  <xsl:function name="mm:escape-js-single" as="xs:string">
    <xsl:param name="str" as="xs:string"/>
    <xsl:value-of select="
      replace(
        replace(
          replace(
            replace(
              replace(
                replace($str, '\\', '\\\\'),
              '''', '\\'''),
            '&#10;', '\\n'),
          '&#13;', '\\r'),
        '/', '\\/'),
      '&lt;', '\\u003c')
    "/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:is-visible-topicref
       ================================================================ -->
  <xsl:function name="mm:is-visible-topicref" as="xs:boolean">
    <xsl:param name="ref" as="element()"/>
    <xsl:sequence select="
      not($ref/@processing-role = 'resource-only')
      and not($ref/@toc = 'no')
    "/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:node-bg-color
       Extracts background color from topicmeta/data[@name='mindmap-color'].
       ================================================================ -->
  <xsl:function name="mm:node-bg-color" as="xs:string">
    <xsl:param name="ref" as="element()"/>
    <xsl:variable name="color-data"
        select="$ref/*[contains(@class, ' map/topicmeta ')]
                     /*[contains(@class, ' topic/data ')]
                       [@name = 'mindmap-color']/@value"/>
    <xsl:variable name="raw" as="xs:string"
        select="if (exists($color-data)) then string($color-data[1]) else ''"/>
    <xsl:value-of select="if (matches($raw, '^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$')
                              or matches($raw, '^[a-zA-Z]+$'))
                          then $raw else ''"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:node-fg-color
       Extracts foreground (text) color from topicmeta/data[@name='mindmap-fg-color'].
       ================================================================ -->
  <xsl:function name="mm:node-fg-color" as="xs:string">
    <xsl:param name="ref" as="element()"/>
    <xsl:variable name="color-data"
        select="$ref/*[contains(@class, ' map/topicmeta ')]
                     /*[contains(@class, ' topic/data ')]
                       [@name = 'mindmap-fg-color']/@value"/>
    <xsl:variable name="raw" as="xs:string"
        select="if (exists($color-data)) then string($color-data[1]) else ''"/>
    <xsl:value-of select="if (matches($raw, '^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$')
                              or matches($raw, '^[a-zA-Z]+$'))
                          then $raw else ''"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:node-line-color
       Extracts leading line color from topicmeta/data[@name='mindmap-line-color'].
       ================================================================ -->
  <xsl:function name="mm:node-line-color" as="xs:string">
    <xsl:param name="ref" as="element()"/>
    <xsl:variable name="color-data"
        select="$ref/*[contains(@class, ' map/topicmeta ')]
                     /*[contains(@class, ' topic/data ')]
                       [@name = 'mindmap-line-color']/@value"/>
    <xsl:variable name="raw" as="xs:string"
        select="if (exists($color-data)) then string($color-data[1]) else ''"/>
    <xsl:value-of select="if (matches($raw, '^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$')
                              or matches($raw, '^[a-zA-Z]+$'))
                          then $raw else ''"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:node-font-weight
       Extracts font weight from topicmeta/data[@name='mindmap-font-weight'].
       ================================================================ -->
  <xsl:function name="mm:node-font-weight" as="xs:string">
    <xsl:param name="ref" as="element()"/>
    <xsl:variable name="weight-data"
        select="$ref/*[contains(@class, ' map/topicmeta ')]
                     /*[contains(@class, ' topic/data ')]
                       [@name = 'mindmap-font-weight']/@value"/>
    <xsl:variable name="raw" as="xs:string"
        select="if (exists($weight-data)) then string($weight-data[1]) else ''"/>
    <!-- Only allow 'bold' or 'normal' -->
    <xsl:value-of select="if ($raw = 'bold' or $raw = 'normal') then $raw else ''"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:effective-children
       ================================================================ -->
  <xsl:function name="mm:effective-children" as="element()*">
    <xsl:param name="parent" as="element()"/>
    <xsl:for-each select="$parent/*[contains(@class, ' map/topicref ')][mm:is-visible-topicref(.)]">
      <xsl:choose>
        <xsl:when test="contains(@class, ' mapgroup-d/topicgroup ')">
          <xsl:sequence select="mm:effective-children(.)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <!-- ================================================================
       Root template
       ================================================================ -->
  <xsl:template match="/">
    <xsl:apply-templates select="*[contains(@class, ' map/map ')]"/>
  </xsl:template>

  <!-- ================================================================
       Map template: generates the complete HTML page
       ================================================================ -->
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:variable name="map-title" as="xs:string"
        select="string((*[contains(@class, ' topic/title ')], @title, 'Mindmap')[1])"/>

    <!-- Build jsMind JSON data -->
    <xsl:variable name="jsmind-json" as="xs:string">
      <xsl:value-of>
        <xsl:text>{&#10;</xsl:text>
        <xsl:text>  "meta": {"name": "</xsl:text>
        <xsl:value-of select="mm:escape-json($map-title)"/>
        <xsl:text>"},&#10;</xsl:text>
        <xsl:text>  "format": "node_tree",&#10;</xsl:text>
        <xsl:text>  "data": </xsl:text>
        <xsl:call-template name="node-to-json">
          <xsl:with-param name="node-id" select="'root'"/>
          <xsl:with-param name="node-topic" select="$map-title"/>
          <xsl:with-param name="children" select="mm:effective-children(.)"/>
          <xsl:with-param name="is-root" select="true()"/>
          <xsl:with-param name="indent" select="'  '"/>
        </xsl:call-template>
        <xsl:text>&#10;}</xsl:text>
      </xsl:value-of>
    </xsl:variable>

    <!-- Emit HTML5 document -->
    <html lang="{$mindmap-lang}">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title><xsl:value-of select="$map-title"/> — Mindmap</title>
        <link type="text/css" rel="stylesheet" href="jsmind/jsmind.css"/>
        <script type="text/javascript" src="jsmind/jsmind.js">
          <xsl:text> </xsl:text>
        </script>
        <script type="text/javascript" src="jsmind/jsmind.draggable-node.js">
          <xsl:text> </xsl:text>
        </script>
        <script type="text/javascript" src="jsmind/jsmind.screenshot.js">
          <xsl:text> </xsl:text>
        </script>
        <link rel="stylesheet" href="mindmap.css"/>
      </head>
      <body>
        <header>
          <h1><xsl:value-of select="$map-title"/></h1>
          <div class="controls">
            <button onclick="jm.expand_all()" title="Expand all nodes">Expand All</button>
            <button onclick="jm.collapse_all()" title="Collapse all nodes">Collapse All</button>
            <span class="separator"></span>
            <button onclick="jm.expand_to_depth(1)" title="Expand to level 1">Depth 1</button>
            <button onclick="jm.expand_to_depth(2)" title="Expand to level 2">Depth 2</button>
            <button onclick="jm.expand_to_depth(3)" title="Expand to level 3">Depth 3</button>
            <span class="separator"></span>
            <button onclick="zoomIn()" title="Zoom in">+</button>
            <button onclick="zoomOut()" title="Zoom out">−</button>
            <button onclick="zoomReset()" title="Reset zoom">Reset</button>
            <span class="separator"></span>
            <button onclick="exportScreenshot()" title="Download as PNG">Screenshot</button>
            <button onclick="window.print()" title="Print or save as PDF">Print</button>
          </div>
        </header>
        <div id="jsmind_container"></div>
        <noscript>
          <p>This interactive mindmap requires JavaScript to render.
             Please enable JavaScript or use the PDF output instead.</p>
        </noscript>
        <script type="text/javascript">
          <xsl:text>&#10;var mind = </xsl:text>
          <xsl:value-of select="$jsmind-json" disable-output-escaping="yes"/>
          <xsl:text>;&#10;&#10;</xsl:text>
          <xsl:text>var options = {&#10;</xsl:text>
          <xsl:text>  container: 'jsmind_container',&#10;</xsl:text>
          <xsl:text>  theme: '</xsl:text>
          <xsl:value-of select="mm:escape-js-single($jsmind-theme)"/>
          <xsl:text>',&#10;</xsl:text>
          <xsl:text>  editable: </xsl:text>
          <xsl:value-of select="if ($jsmind-editable = 'true') then 'true' else 'false'"/>
          <xsl:text>,&#10;</xsl:text>
          <xsl:text>  mode: '</xsl:text>
          <xsl:value-of select="mm:escape-js-single($jsmind-mode)"/>
          <xsl:text>',&#10;</xsl:text>
          <xsl:text>  support_html: false,&#10;</xsl:text>
          <xsl:text>  log_level: 'warn',&#10;</xsl:text>
          <xsl:text>  view: {&#10;</xsl:text>
          <xsl:text>    draggable: true,&#10;</xsl:text>
          <xsl:text>    hide_scrollbars_when_draggable: true,&#10;</xsl:text>
          <xsl:text>    node_overflow: 'wrap',&#10;</xsl:text>
          <xsl:text>    line_style: 'curved',&#10;</xsl:text>
          <xsl:text>    line_width: 2,&#10;</xsl:text>
          <xsl:text>    line_color: '#555',&#10;</xsl:text>
          <xsl:text>    expander_style: 'number',&#10;</xsl:text>
          <xsl:text>    zoom: {min: 0.3, max: 3.0, step: 0.1}&#10;</xsl:text>
          <xsl:text>  },&#10;</xsl:text>
          <xsl:text>  layout: {&#10;</xsl:text>
          <xsl:text>    hspace: 80,&#10;</xsl:text>
          <xsl:text>    vspace: 25,&#10;</xsl:text>
          <xsl:text>    pspace: 13,&#10;</xsl:text>
          <xsl:text>    cousin_space: 10&#10;</xsl:text>
          <xsl:text>  }&#10;</xsl:text>
          <xsl:text>};&#10;&#10;</xsl:text>
          <xsl:text>var jm = new jsMind(options);&#10;</xsl:text>
          <xsl:text>jm.show(mind);&#10;&#10;</xsl:text>
          <xsl:text>var currentZoom = 1.0;&#10;</xsl:text>
          <xsl:text>function zoomIn() {&#10;</xsl:text>
          <xsl:text>  currentZoom = Math.min(currentZoom + 0.2, 3.0);&#10;</xsl:text>
          <xsl:text>  jm.view.setZoom(currentZoom);&#10;</xsl:text>
          <xsl:text>}&#10;</xsl:text>
          <xsl:text>function zoomOut() {&#10;</xsl:text>
          <xsl:text>  currentZoom = Math.max(currentZoom - 0.2, 0.3);&#10;</xsl:text>
          <xsl:text>  jm.view.setZoom(currentZoom);&#10;</xsl:text>
          <xsl:text>}&#10;</xsl:text>
          <xsl:text>function zoomReset() {&#10;</xsl:text>
          <xsl:text>  currentZoom = 1.0;&#10;</xsl:text>
          <xsl:text>  jm.view.setZoom(currentZoom);&#10;</xsl:text>
          <xsl:text>}&#10;</xsl:text>
          <xsl:text>function exportScreenshot() {&#10;</xsl:text>
          <xsl:text>  if (jm.screenshot) {&#10;</xsl:text>
          <xsl:text>    jm.screenshot.shootDownload();&#10;</xsl:text>
          <xsl:text>  } else {&#10;</xsl:text>
          <xsl:text>    alert('Screenshot plugin not available');&#10;</xsl:text>
          <xsl:text>  }&#10;</xsl:text>
          <xsl:text>}&#10;</xsl:text>
        </script>
      </body>
    </html>
  </xsl:template>

  <!-- ================================================================
       Named template: convert a node to jsMind JSON
       Handles both the root (map title) and topicrefs recursively.
       Supports node styling: background-color, foreground-color,
       font-weight, leading-line-color via DITA <data> elements.
       ================================================================ -->
  <xsl:template name="node-to-json">
    <xsl:param name="node-id" as="xs:string"/>
    <xsl:param name="node-topic" as="xs:string"/>
    <xsl:param name="node-bg-color" as="xs:string" select="''"/>
    <xsl:param name="node-fg-color" as="xs:string" select="''"/>
    <xsl:param name="node-font-weight" as="xs:string" select="''"/>
    <xsl:param name="node-line-color" as="xs:string" select="''"/>
    <xsl:param name="node-direction" as="xs:string" select="''"/>
    <xsl:param name="children" as="element()*" select="()"/>
    <xsl:param name="is-root" as="xs:boolean" select="false()"/>
    <xsl:param name="indent" as="xs:string" select="'  '"/>

    <xsl:variable name="child-indent" select="concat($indent, '  ')"/>

    <xsl:text>{&#10;</xsl:text>
    <xsl:value-of select="$child-indent"/>
    <xsl:text>"id": "</xsl:text>
    <xsl:value-of select="mm:escape-json($node-id)"/>
    <xsl:text>",&#10;</xsl:text>

    <xsl:value-of select="$child-indent"/>
    <xsl:text>"topic": "</xsl:text>
    <xsl:value-of select="mm:escape-json($node-topic)"/>
    <xsl:text>",&#10;</xsl:text>

    <xsl:value-of select="$child-indent"/>
    <xsl:text>"expanded": </xsl:text>
    <xsl:value-of select="if ($is-root or count($children) le 6) then 'true' else 'false'"/>

    <!-- Optional: direction for bilateral layout (left/right of root) -->
    <xsl:if test="$node-direction != ''">
      <xsl:text>,&#10;</xsl:text>
      <xsl:value-of select="$child-indent"/>
      <xsl:text>"direction": "</xsl:text>
      <xsl:value-of select="$node-direction"/>
      <xsl:text>"</xsl:text>
    </xsl:if>

    <!-- Optional: node data (styling properties from DITA metadata) -->
    <xsl:variable name="has-data" as="xs:boolean"
        select="$node-bg-color != '' or $node-fg-color != ''
                or $node-font-weight != '' or $node-line-color != ''"/>
    <xsl:if test="$has-data">
      <xsl:text>,&#10;</xsl:text>
      <xsl:value-of select="$child-indent"/>
      <xsl:text>"data": {</xsl:text>
      <xsl:variable name="data-parts" as="xs:string*">
        <xsl:if test="$node-bg-color != ''">
          <xsl:sequence select="concat('&quot;background-color&quot;: &quot;', mm:escape-json($node-bg-color), '&quot;')"/>
        </xsl:if>
        <xsl:if test="$node-fg-color != ''">
          <xsl:sequence select="concat('&quot;foreground-color&quot;: &quot;', mm:escape-json($node-fg-color), '&quot;')"/>
        </xsl:if>
        <xsl:if test="$node-font-weight != ''">
          <xsl:sequence select="concat('&quot;font-weight&quot;: &quot;', mm:escape-json($node-font-weight), '&quot;')"/>
        </xsl:if>
        <xsl:if test="$node-line-color != ''">
          <xsl:sequence select="concat('&quot;leading-line-color&quot;: &quot;', mm:escape-json($node-line-color), '&quot;')"/>
        </xsl:if>
      </xsl:variable>
      <xsl:value-of select="string-join($data-parts, ', ')"/>
      <xsl:text>}</xsl:text>
    </xsl:if>

    <!-- Recurse into children -->
    <xsl:if test="exists($children)">
      <xsl:variable name="child-count" as="xs:integer" select="count($children)"/>
      <!-- In full mode, split root's children: first half right, second half left -->
      <xsl:variable name="split" as="xs:integer"
          select="if ($is-root and $jsmind-mode = 'full' and $child-count ge 2)
                  then xs:integer(ceiling($child-count div 2))
                  else 0"/>

      <xsl:text>,&#10;</xsl:text>
      <xsl:value-of select="$child-indent"/>
      <xsl:text>"children": [&#10;</xsl:text>
      <xsl:for-each select="$children">
        <xsl:if test="position() gt 1">
          <xsl:text>,&#10;</xsl:text>
        </xsl:if>
        <!-- Extract this topicref's label -->
        <xsl:variable name="ref-id" as="xs:string"
            select="string((@id, generate-id())[1])"/>
        <xsl:variable name="ref-topic" as="xs:string">
          <xsl:choose>
            <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
              <xsl:value-of select="string(*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')])"/>
            </xsl:when>
            <xsl:when test="@navtitle">
              <xsl:value-of select="string(@navtitle)"/>
            </xsl:when>
            <xsl:when test="@href">
              <xsl:value-of select="replace(replace(string(@href), '^.*/', ''), '\.[^.]+$', '')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="'Untitled'"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>

        <!-- Extract optional styling from topicmeta/data -->
        <xsl:variable name="ref-bg-color" as="xs:string" select="mm:node-bg-color(.)"/>
        <xsl:variable name="ref-fg-color" as="xs:string" select="mm:node-fg-color(.)"/>
        <xsl:variable name="ref-font-weight" as="xs:string" select="mm:node-font-weight(.)"/>
        <xsl:variable name="ref-line-color" as="xs:string" select="mm:node-line-color(.)"/>

        <!-- Direction for bilateral layout: first half right, second half left -->
        <xsl:variable name="ref-direction" as="xs:string"
            select="if ($split gt 0)
                    then (if (position() le $split) then 'right' else 'left')
                    else ''"/>

        <xsl:value-of select="concat($child-indent, '  ')"/>
        <xsl:call-template name="node-to-json">
          <xsl:with-param name="node-id" select="$ref-id"/>
          <xsl:with-param name="node-topic" select="$ref-topic"/>
          <xsl:with-param name="node-bg-color" select="$ref-bg-color"/>
          <xsl:with-param name="node-fg-color" select="$ref-fg-color"/>
          <xsl:with-param name="node-font-weight" select="$ref-font-weight"/>
          <xsl:with-param name="node-line-color" select="$ref-line-color"/>
          <xsl:with-param name="node-direction" select="$ref-direction"/>
          <xsl:with-param name="children" select="mm:effective-children(.)"/>
          <xsl:with-param name="indent" select="concat($child-indent, '  ')"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
      <xsl:value-of select="$child-indent"/>
      <xsl:text>]</xsl:text>
    </xsl:if>

    <xsl:text>&#10;</xsl:text>
    <xsl:value-of select="$indent"/>
    <xsl:text>}</xsl:text>
  </xsl:template>

</xsl:stylesheet>
