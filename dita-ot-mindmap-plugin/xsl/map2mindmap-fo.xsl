<?xml version="1.0" encoding="UTF-8"?>
<!--
  map2mindmap-fo.xsl
  XSLT 3.0 stylesheet for DITA-OT mindmap-pdf transtype.
  Transforms a resolved DITA map into XSL-FO with an inline SVG
  tree diagram. Apache FOP renders the FO to PDF.

  Features:
  - Filters @processing-role="resource-only" and @toc="no"
  - Topicgroup transparency (children promoted to parent)
  - Topichead support (label-only nodes)
  - Multi-page: overview + detail pages for large maps (> 30 leaves)
  - PDF bookmarks for navigation sidebar
  - Custom node colors via topicmeta/data
  - Adaptive node sizing for wide maps
  - Bilateral layout (left+right) for A3/A2 formats
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:svg="http://www.w3.org/2000/svg"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <!-- Parameters from Ant build -->
  <xsl:param name="page-size" as="xs:string" select="'A4-landscape'"/>
  <xsl:param name="max-chars" as="xs:string" select="'20'"/>
  <!-- Safe integer conversion: fallback to 20 if non-numeric -->
  <xsl:variable name="max-chars-int" as="xs:integer"
      select="if ($max-chars castable as xs:integer) then xs:integer($max-chars) else 20"/>

  <!-- Threshold for multi-page mode: maps with more leaves get split -->
  <xsl:variable name="multipage-threshold" as="xs:integer" select="30"/>

  <!-- Bilateral layout for large formats (A3, A2) -->
  <xsl:variable name="bilateral" as="xs:boolean"
      select="starts-with($page-size, 'A3') or starts-with($page-size, 'A2')"/>

  <!-- Layout constants (defaults; may be reduced adaptively) -->
  <xsl:variable name="node-w" as="xs:integer" select="150"/>
  <xsl:variable name="node-h" as="xs:integer" select="32"/>
  <xsl:variable name="h-gap" as="xs:integer" select="50"/>
  <xsl:variable name="v-gap" as="xs:integer" select="12"/>
  <xsl:variable name="margin" as="xs:integer" select="30"/>
  <xsl:variable name="min-node-h" as="xs:integer" select="16"/>

  <!-- Usable body dimensions (mm) for each page size.
       Page minus margins (12mm×2), region-before (18mm), region-after (10mm). -->
  <xsl:variable name="body-w-mm" as="xs:double"
      select="if (starts-with($page-size, 'A2')) then 570
              else if (starts-with($page-size, 'A3')) then 396
              else if (starts-with($page-size, 'letter')) then 255
              else 273"/>
  <xsl:variable name="body-h-mm" as="xs:double"
      select="if (starts-with($page-size, 'A2')) then 368
              else if (starts-with($page-size, 'A3')) then 245
              else if (starts-with($page-size, 'letter')) then 164
              else 158"/>

  <!-- Color palette for depth levels -->
  <xsl:variable name="colors" as="xs:string*"
      select="('#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
               '#8c564b', '#e377c2', '#7f7f7f', '#17becf', '#bcbd22')"/>

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
       Function: mm:count-leaves-fn
       ================================================================ -->
  <xsl:function name="mm:count-leaves-fn" as="xs:integer">
    <xsl:param name="node" as="element()"/>
    <xsl:variable name="children" select="mm:effective-children($node)"/>
    <xsl:choose>
      <xsl:when test="empty($children)">
        <xsl:sequence select="1"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="sum(for $c in $children return mm:count-leaves-fn($c))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ================================================================
       Function: mm:max-depth-fn
       ================================================================ -->
  <xsl:function name="mm:max-depth-fn" as="xs:integer">
    <xsl:param name="nodes" as="element()*"/>
    <xsl:param name="current-depth" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="empty($nodes)">
        <xsl:sequence select="$current-depth - 1"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="max(
          for $n in $nodes return
            let $children := mm:effective-children($n)
            return if (exists($children))
                   then mm:max-depth-fn($children, $current-depth + 1)
                   else $current-depth
        )"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ================================================================
       Function: mm:node-bg-color
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
       Function: mm:node-label
       ================================================================ -->
  <xsl:function name="mm:node-label" as="xs:string">
    <xsl:param name="ref" as="element()"/>
    <xsl:choose>
      <xsl:when test="$ref/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:value-of select="string($ref/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')])"/>
      </xsl:when>
      <xsl:when test="$ref/@navtitle">
        <xsl:value-of select="string($ref/@navtitle)"/>
      </xsl:when>
      <xsl:when test="$ref/@href">
        <xsl:value-of select="replace(replace(string($ref/@href), '^.*/', ''), '\.[^.]+$', '')"/>
      </xsl:when>
      <xsl:otherwise>Untitled</xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ================================================================
       Function: mm:truncate
       ================================================================ -->
  <xsl:function name="mm:truncate" as="xs:string">
    <xsl:param name="label" as="xs:string"/>
    <xsl:param name="max" as="xs:integer"/>
    <xsl:value-of select="if (string-length($label) gt $max)
                          then concat(substring($label, 1, $max - 1), '...')
                          else $label"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:compute-svg-dims
       Computes SVG width, height, and effective node height for
       unilateral (right-only) layout.
       Returns a sequence: (svg-w, svg-h, eff-node-h)
       ================================================================ -->
  <xsl:function name="mm:compute-svg-dims" as="xs:integer+">
    <xsl:param name="leaf-count" as="xs:integer"/>
    <xsl:param name="depth" as="xs:integer"/>

    <xsl:variable name="svg-w" as="xs:integer"
        select="($depth + 1) * ($node-w + $h-gap) + 2 * $margin"/>
    <xsl:variable name="svg-h-natural" as="xs:integer"
        select="$leaf-count * ($node-h + $v-gap) + 2 * $margin"/>
    <xsl:variable name="max-svg-h" as="xs:integer"
        select="xs:integer(round($svg-w * $body-h-mm div $body-w-mm))"/>
    <xsl:variable name="svg-h" as="xs:integer"
        select="min(($svg-h-natural, $max-svg-h))"/>

    <!-- Compute effective node height: use available space per leaf × 0.72 -->
    <xsl:variable name="avail-per-leaf" as="xs:double"
        select="($svg-h - 2 * $margin) div max(($leaf-count, 1))"/>
    <xsl:variable name="eff-h" as="xs:integer"
        select="min(($node-h, max(($min-node-h, xs:integer(floor($avail-per-leaf * 0.72))))))"/>

    <xsl:sequence select="($svg-w, $svg-h, $eff-h)"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:compute-bilateral-svg-dims
       Computes SVG width, height, and effective node height for
       bilateral (left+right) layout.
       Parameters: left-leaves, right-leaves, left-depth, right-depth
       Returns a sequence: (svg-w, svg-h, eff-node-h)
       ================================================================ -->
  <xsl:function name="mm:compute-bilateral-svg-dims" as="xs:integer+">
    <xsl:param name="left-leaves" as="xs:integer"/>
    <xsl:param name="right-leaves" as="xs:integer"/>
    <xsl:param name="left-depth" as="xs:integer"/>
    <xsl:param name="right-depth" as="xs:integer"/>

    <!-- Width: left side + root + right side -->
    <xsl:variable name="svg-w" as="xs:integer"
        select="$margin
                + $left-depth * ($node-w + $h-gap)
                + $node-w
                + $right-depth * ($node-w + $h-gap)
                + $margin"/>

    <!-- Height based on max leaves per side (each side uses full height) -->
    <xsl:variable name="max-side-leaves" as="xs:integer"
        select="max(($left-leaves, $right-leaves, 3))"/>
    <xsl:variable name="svg-h-natural" as="xs:integer"
        select="$max-side-leaves * ($node-h + $v-gap) + 2 * $margin"/>
    <xsl:variable name="max-svg-h" as="xs:integer"
        select="xs:integer(round($svg-w * $body-h-mm div $body-w-mm))"/>
    <xsl:variable name="svg-h" as="xs:integer"
        select="min(($svg-h-natural, $max-svg-h))"/>

    <!-- Effective node height based on available space per leaf -->
    <xsl:variable name="avail-per-leaf" as="xs:double"
        select="($svg-h - 2 * $margin) div max(($max-side-leaves, 1))"/>
    <xsl:variable name="eff-h" as="xs:integer"
        select="min(($node-h, max(($min-node-h, xs:integer(floor($avail-per-leaf * 0.72))))))"/>

    <xsl:sequence select="($svg-w, $svg-h, $eff-h)"/>
  </xsl:function>

  <!-- ================================================================
       Function: mm:font-size-for-node-h
       Returns appropriate font size based on effective node height.
       ================================================================ -->
  <xsl:function name="mm:font-size-for-node-h" as="xs:integer">
    <xsl:param name="eff-h" as="xs:integer"/>
    <xsl:sequence select="if ($eff-h ge 28) then 10
                          else if ($eff-h ge 22) then 9
                          else if ($eff-h ge 18) then 8
                          else 7"/>
  </xsl:function>

  <!-- ================================================================
       Root template
       ================================================================ -->
  <xsl:template match="/">
    <xsl:apply-templates select="*[contains(@class, ' map/map ')]"/>
  </xsl:template>

  <!-- ================================================================
       Map template: generates XSL-FO document with SVG mindmap
       ================================================================ -->
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:variable name="map-title" as="xs:string"
        select="string((*[contains(@class, ' topic/title ')], @title, 'Mindmap')[1])"/>

    <xsl:variable name="page-width" as="xs:string"
        select="if (starts-with($page-size, 'A2')) then '594mm'
                else if (starts-with($page-size, 'A3')) then '420mm'
                else if (starts-with($page-size, 'letter')) then '279mm'
                else '297mm'"/>
    <xsl:variable name="page-height" as="xs:string"
        select="if (starts-with($page-size, 'A2')) then '420mm'
                else if (starts-with($page-size, 'A3')) then '297mm'
                else if (starts-with($page-size, 'letter')) then '216mm'
                else '210mm'"/>

    <xsl:variable name="topicrefs" select="mm:effective-children(.)"/>

    <xsl:variable name="total-leaves" as="xs:integer"
        select="if (empty($topicrefs)) then 1
                else sum(for $t in $topicrefs return mm:count-leaves-fn($t))"/>
    <xsl:variable name="max-depth" as="xs:integer"
        select="if (empty($topicrefs)) then 1
                else mm:max-depth-fn($topicrefs, 1)"/>

    <fo:root>
      <fo:layout-master-set>
        <fo:simple-page-master master-name="mindmap-page"
            page-width="{$page-width}" page-height="{$page-height}"
            margin="12mm">
          <fo:region-body margin-top="18mm" margin-bottom="10mm"/>
          <fo:region-before extent="16mm"/>
          <fo:region-after extent="8mm"/>
        </fo:simple-page-master>
      </fo:layout-master-set>

      <!-- PDF Bookmarks -->
      <xsl:variable name="is-multipage" as="xs:boolean"
          select="$total-leaves gt $multipage-threshold and count($topicrefs) gt 1"/>
      <fo:bookmark-tree>
        <fo:bookmark internal-destination="page-overview">
          <fo:bookmark-title><xsl:value-of select="$map-title"/></fo:bookmark-title>
          <xsl:if test="$is-multipage">
            <xsl:for-each select="$topicrefs">
              <fo:bookmark internal-destination="{concat('branch-', position())}">
                <fo:bookmark-title><xsl:value-of select="mm:node-label(.)"/></fo:bookmark-title>
              </fo:bookmark>
            </xsl:for-each>
          </xsl:if>
        </fo:bookmark>
      </fo:bookmark-tree>

      <xsl:choose>
        <xsl:when test="$is-multipage">
          <xsl:call-template name="render-overview-page">
            <xsl:with-param name="map-title" select="$map-title"/>
            <xsl:with-param name="topicrefs" select="$topicrefs"/>
          </xsl:call-template>

          <xsl:for-each select="$topicrefs">
            <xsl:variable name="branch-children" select="mm:effective-children(.)"/>
            <xsl:call-template name="render-branch-page">
              <xsl:with-param name="branch-title" select="mm:node-label(.)"/>
              <xsl:with-param name="branch-id" select="concat('branch-', position())"/>
              <xsl:with-param name="branch-node" select="."/>
              <xsl:with-param name="branch-children" select="$branch-children"/>
              <xsl:with-param name="branch-leaves" select="mm:count-leaves-fn(.)"/>
              <xsl:with-param name="branch-depth"
                  select="if (empty($branch-children)) then 1
                          else mm:max-depth-fn($branch-children, 1)"/>
              <xsl:with-param name="branch-pos" select="position()"/>
            </xsl:call-template>
          </xsl:for-each>
        </xsl:when>

        <xsl:otherwise>
          <xsl:call-template name="render-single-page">
            <xsl:with-param name="map-title" select="$map-title"/>
            <xsl:with-param name="topicrefs" select="$topicrefs"/>
            <xsl:with-param name="total-leaves" select="$total-leaves"/>
            <xsl:with-param name="max-depth" select="$max-depth"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </fo:root>
  </xsl:template>

  <!-- ================================================================
       Template: render-single-page
       Renders all branches on a single page.
       In bilateral mode (A3/A2): root centered, branches split left/right.
       In unilateral mode (A4/letter): root on left, branches to the right.
       ================================================================ -->
  <xsl:template name="render-single-page">
    <xsl:param name="map-title" as="xs:string"/>
    <xsl:param name="topicrefs" as="element()*"/>
    <xsl:param name="total-leaves" as="xs:integer"/>
    <xsl:param name="max-depth" as="xs:integer"/>

    <xsl:variable name="branch-count" as="xs:integer" select="count($topicrefs)"/>

    <xsl:choose>
      <!-- ====== BILATERAL LAYOUT (A3 / A2) ====== -->
      <xsl:when test="$bilateral and $branch-count ge 2">
        <xsl:variable name="split" as="xs:integer"
            select="xs:integer(ceiling($branch-count div 2))"/>
        <xsl:variable name="right-refs" select="$topicrefs[position() le $split]"/>
        <xsl:variable name="left-refs" select="$topicrefs[position() gt $split]"/>

        <xsl:variable name="right-leaves" as="xs:integer"
            select="max((sum(for $r in $right-refs return mm:count-leaves-fn($r)), 3))"/>
        <xsl:variable name="left-leaves" as="xs:integer"
            select="max((sum(for $l in $left-refs return mm:count-leaves-fn($l)), 3))"/>
        <xsl:variable name="right-depth" as="xs:integer"
            select="max((mm:max-depth-fn($right-refs, 1), 1))"/>
        <xsl:variable name="left-depth" as="xs:integer"
            select="max((mm:max-depth-fn($left-refs, 1), 1))"/>

        <xsl:variable name="dims" as="xs:integer+"
            select="mm:compute-bilateral-svg-dims($left-leaves, $right-leaves, $left-depth, $right-depth)"/>
        <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
        <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
        <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
        <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

        <!-- Root node center-x -->
        <xsl:variable name="root-cx" as="xs:double"
            select="$margin + $left-depth * ($node-w + $h-gap) + $node-w div 2"/>
        <xsl:variable name="root-x" as="xs:double" select="$root-cx - $node-w div 2"/>
        <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

        <fo:page-sequence master-reference="mindmap-page" id="page-overview">
          <xsl:call-template name="page-header">
            <xsl:with-param name="title" select="$map-title"/>
          </xsl:call-template>
          <xsl:call-template name="page-footer"/>
          <fo:flow flow-name="xsl-region-body">
            <fo:block text-align="center">
              <fo:instream-foreign-object
                  content-width="scale-to-fit" content-height="scale-to-fit"
                  width="100%" scaling="uniform">
                <svg:svg width="{$svg-w}" height="{$svg-h}"
                         viewBox="0 0 {$svg-w} {$svg-h}">

                  <!-- Root node -->
                  <svg:rect x="{$root-x}" y="{$root-cy - $eff-h div 2}"
                            width="{$node-w}" height="{$eff-h}"
                            rx="6" ry="6"
                            fill="{$colors[1]}" stroke="#14527a" stroke-width="2"/>
                  <svg:text x="{$root-cx}" y="{$root-cy}"
                            text-anchor="middle" dominant-baseline="central"
                            fill="white" font-family="Helvetica, Arial, sans-serif"
                            font-size="{$font-sz + 1}" font-weight="bold">
                    <xsl:value-of select="mm:truncate($map-title, $max-chars-int)"/>
                  </svg:text>

                  <!-- RIGHT side branches -->
                  <xsl:call-template name="render-children">
                    <xsl:with-param name="children" select="$right-refs"/>
                    <xsl:with-param name="parent-edge-x" select="$root-x + $node-w"/>
                    <xsl:with-param name="parent-cy" select="$root-cy"/>
                    <xsl:with-param name="alloc-top" select="xs:double($margin)"/>
                    <xsl:with-param name="alloc-bottom" select="xs:double($svg-h - $margin)"/>
                    <xsl:with-param name="depth" select="1"/>
                    <xsl:with-param name="total-child-leaves" select="$right-leaves"/>
                    <xsl:with-param name="eff-node-h" select="$eff-h"/>
                    <xsl:with-param name="direction" select="'right'"/>
                  </xsl:call-template>

                  <!-- LEFT side branches -->
                  <xsl:call-template name="render-children">
                    <xsl:with-param name="children" select="$left-refs"/>
                    <xsl:with-param name="parent-edge-x" select="$root-x"/>
                    <xsl:with-param name="parent-cy" select="$root-cy"/>
                    <xsl:with-param name="alloc-top" select="xs:double($margin)"/>
                    <xsl:with-param name="alloc-bottom" select="xs:double($svg-h - $margin)"/>
                    <xsl:with-param name="depth" select="1"/>
                    <xsl:with-param name="total-child-leaves" select="$left-leaves"/>
                    <xsl:with-param name="eff-node-h" select="$eff-h"/>
                    <xsl:with-param name="direction" select="'left'"/>
                  </xsl:call-template>

                </svg:svg>
              </fo:instream-foreign-object>
            </fo:block>
          </fo:flow>
        </fo:page-sequence>
      </xsl:when>

      <!-- ====== UNILATERAL LAYOUT (A4 / letter / single branch) ====== -->
      <xsl:otherwise>
        <xsl:variable name="leaf-count" as="xs:integer" select="max(($total-leaves, 3))"/>
        <xsl:variable name="depth" as="xs:integer" select="max(($max-depth, 1))"/>
        <xsl:variable name="dims" as="xs:integer+" select="mm:compute-svg-dims($leaf-count, $depth)"/>
        <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
        <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
        <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
        <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

        <fo:page-sequence master-reference="mindmap-page" id="page-overview">
          <xsl:call-template name="page-header">
            <xsl:with-param name="title" select="$map-title"/>
          </xsl:call-template>
          <xsl:call-template name="page-footer"/>
          <fo:flow flow-name="xsl-region-body">
            <fo:block text-align="center">
              <fo:instream-foreign-object
                  content-width="scale-to-fit" content-height="scale-to-fit"
                  width="100%" scaling="uniform">
                <svg:svg width="{$svg-w}" height="{$svg-h}"
                         viewBox="0 0 {$svg-w} {$svg-h}">
                  <xsl:variable name="root-x" as="xs:integer" select="$margin"/>
                  <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

                  <svg:rect x="{$root-x}" y="{$root-cy - $eff-h div 2}"
                            width="{$node-w}" height="{$eff-h}"
                            rx="6" ry="6"
                            fill="{$colors[1]}" stroke="#14527a" stroke-width="2"/>
                  <svg:text x="{$root-x + $node-w div 2}" y="{$root-cy}"
                            text-anchor="middle" dominant-baseline="central"
                            fill="white" font-family="Helvetica, Arial, sans-serif"
                            font-size="{$font-sz + 1}" font-weight="bold">
                    <xsl:value-of select="mm:truncate($map-title, $max-chars-int)"/>
                  </svg:text>

                  <xsl:if test="exists($topicrefs)">
                    <xsl:call-template name="render-children">
                      <xsl:with-param name="children" select="$topicrefs"/>
                      <xsl:with-param name="parent-edge-x" select="$root-x + $node-w"/>
                      <xsl:with-param name="parent-cy" select="$root-cy"/>
                      <xsl:with-param name="alloc-top" select="xs:double($margin)"/>
                      <xsl:with-param name="alloc-bottom" select="xs:double($svg-h - $margin)"/>
                      <xsl:with-param name="depth" select="1"/>
                      <xsl:with-param name="total-child-leaves" select="$leaf-count"/>
                      <xsl:with-param name="eff-node-h" select="$eff-h"/>
                      <xsl:with-param name="direction" select="'right'"/>
                    </xsl:call-template>
                  </xsl:if>
                </svg:svg>
              </fo:instream-foreign-object>
            </fo:block>
          </fo:flow>
        </fo:page-sequence>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       Template: render-overview-page
       Shows root + top-level branches only (2 levels) as a summary.
       In bilateral mode: root centered, branches split left/right.
       ================================================================ -->
  <xsl:template name="render-overview-page">
    <xsl:param name="map-title" as="xs:string"/>
    <xsl:param name="topicrefs" as="element()*"/>

    <xsl:variable name="branch-count" as="xs:integer" select="count($topicrefs)"/>

    <xsl:choose>
      <!-- ====== BILATERAL OVERVIEW ====== -->
      <xsl:when test="$bilateral and $branch-count ge 2">
        <xsl:variable name="split" as="xs:integer"
            select="xs:integer(ceiling($branch-count div 2))"/>
        <xsl:variable name="right-refs" select="$topicrefs[position() le $split]"/>
        <xsl:variable name="left-refs" select="$topicrefs[position() gt $split]"/>

        <xsl:variable name="right-count" as="xs:integer" select="count($right-refs)"/>
        <xsl:variable name="left-count" as="xs:integer" select="count($left-refs)"/>

        <xsl:variable name="dims" as="xs:integer+"
            select="mm:compute-bilateral-svg-dims(
              max(($left-count, 3)), max(($right-count, 3)), 1, 1)"/>
        <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
        <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
        <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
        <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

        <xsl:variable name="root-cx" as="xs:double"
            select="$margin + 1 * ($node-w + $h-gap) + $node-w div 2"/>
        <xsl:variable name="root-x" as="xs:double" select="$root-cx - $node-w div 2"/>
        <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

        <fo:page-sequence master-reference="mindmap-page" id="page-overview">
          <xsl:call-template name="page-header">
            <xsl:with-param name="title" select="concat($map-title, ' — Overview')"/>
          </xsl:call-template>
          <xsl:call-template name="page-footer"/>
          <fo:flow flow-name="xsl-region-body">
            <fo:block text-align="center">
              <fo:instream-foreign-object
                  content-width="scale-to-fit" content-height="scale-to-fit"
                  width="100%" scaling="uniform">
                <svg:svg width="{$svg-w}" height="{$svg-h}"
                         viewBox="0 0 {$svg-w} {$svg-h}">

                  <!-- Root node -->
                  <svg:rect x="{$root-x}" y="{$root-cy - $eff-h div 2}"
                            width="{$node-w}" height="{$eff-h}"
                            rx="6" ry="6"
                            fill="{$colors[1]}" stroke="#14527a" stroke-width="2"/>
                  <svg:text x="{$root-cx}" y="{$root-cy}"
                            text-anchor="middle" dominant-baseline="central"
                            fill="white" font-family="Helvetica, Arial, sans-serif"
                            font-size="{$font-sz + 1}" font-weight="bold">
                    <xsl:value-of select="mm:truncate($map-title, $max-chars-int)"/>
                  </svg:text>

                  <!-- RIGHT side branches (overview: no recursion) -->
                  <xsl:variable name="right-x" as="xs:double"
                      select="$root-x + $node-w + $h-gap"/>
                  <xsl:variable name="alloc-height" as="xs:double"
                      select="$svg-h - 2 * $margin"/>

                  <xsl:for-each select="$right-refs">
                    <xsl:variable name="pos" select="position()"/>
                    <xsl:variable name="my-top" as="xs:double"
                        select="$margin + (($pos - 1) div $right-count) * $alloc-height"/>
                    <xsl:variable name="my-bottom" as="xs:double"
                        select="$margin + ($pos div $right-count) * $alloc-height"/>
                    <xsl:variable name="my-cy" as="xs:double"
                        select="($my-top + $my-bottom) div 2"/>
                    <xsl:variable name="label" select="mm:node-label(.)"/>
                    <xsl:variable name="leaf-info"
                        select="concat(' (', mm:count-leaves-fn(.), ' nodes)')"/>
                    <xsl:variable name="custom-color" as="xs:string"
                        select="mm:node-bg-color(.)"/>
                    <xsl:variable name="color-index" as="xs:integer"
                        select="(($pos - 1) mod count($colors)) + 1"/>
                    <xsl:variable name="node-color" as="xs:string"
                        select="if ($custom-color != '') then $custom-color
                                else $colors[$color-index]"/>

                    <xsl:variable name="cx1" as="xs:double"
                        select="$root-x + $node-w + $h-gap div 2"/>
                    <svg:path d="M {$root-x + $node-w} {$root-cy}
                                 C {$cx1} {$root-cy}, {$cx1} {$my-cy}, {$right-x} {$my-cy}"
                              fill="none" stroke="#aaa" stroke-width="1.5"/>

                    <svg:rect x="{$right-x}" y="{$my-cy - $eff-h div 2}"
                              width="{$node-w}" height="{$eff-h}"
                              rx="6" ry="6"
                              fill="{$node-color}" stroke-width="1" stroke="{$node-color}"/>
                    <xsl:variable name="label-y" as="xs:double"
                        select="if ($eff-h ge 26) then $my-cy - 2 else $my-cy"/>
                    <svg:text x="{$right-x + $node-w div 2}" y="{$label-y}"
                              text-anchor="middle" dominant-baseline="central"
                              fill="white" font-family="Helvetica, Arial, sans-serif"
                              font-size="{$font-sz}" font-weight="bold">
                      <xsl:value-of select="mm:truncate($label, $max-chars-int)"/>
                    </svg:text>
                    <xsl:if test="$eff-h ge 26">
                      <svg:text x="{$right-x + $node-w div 2}" y="{$my-cy + 9}"
                                text-anchor="middle" dominant-baseline="central"
                                fill="white" fill-opacity="0.7"
                                font-family="Helvetica, Arial, sans-serif" font-size="7">
                        <xsl:value-of select="$leaf-info"/>
                      </svg:text>
                    </xsl:if>
                  </xsl:for-each>

                  <!-- LEFT side branches (overview: no recursion) -->
                  <xsl:variable name="left-x" as="xs:double"
                      select="$root-x - $h-gap - $node-w"/>

                  <xsl:for-each select="$left-refs">
                    <xsl:variable name="pos" select="position()"/>
                    <!-- Global position for consistent color indexing -->
                    <xsl:variable name="global-pos" as="xs:integer" select="$split + $pos"/>
                    <xsl:variable name="my-top" as="xs:double"
                        select="$margin + (($pos - 1) div $left-count) * $alloc-height"/>
                    <xsl:variable name="my-bottom" as="xs:double"
                        select="$margin + ($pos div $left-count) * $alloc-height"/>
                    <xsl:variable name="my-cy" as="xs:double"
                        select="($my-top + $my-bottom) div 2"/>
                    <xsl:variable name="label" select="mm:node-label(.)"/>
                    <xsl:variable name="leaf-info"
                        select="concat(' (', mm:count-leaves-fn(.), ' nodes)')"/>
                    <xsl:variable name="custom-color" as="xs:string"
                        select="mm:node-bg-color(.)"/>
                    <xsl:variable name="color-index" as="xs:integer"
                        select="(($global-pos - 1) mod count($colors)) + 1"/>
                    <xsl:variable name="node-color" as="xs:string"
                        select="if ($custom-color != '') then $custom-color
                                else $colors[$color-index]"/>

                    <!-- Left-side connector (Bezier curving left) -->
                    <xsl:variable name="cx1" as="xs:double"
                        select="$root-x - $h-gap div 2"/>
                    <svg:path d="M {$root-x} {$root-cy}
                                 C {$cx1} {$root-cy}, {$cx1} {$my-cy}, {$left-x + $node-w} {$my-cy}"
                              fill="none" stroke="#aaa" stroke-width="1.5"/>

                    <svg:rect x="{$left-x}" y="{$my-cy - $eff-h div 2}"
                              width="{$node-w}" height="{$eff-h}"
                              rx="6" ry="6"
                              fill="{$node-color}" stroke-width="1" stroke="{$node-color}"/>
                    <xsl:variable name="label-y" as="xs:double"
                        select="if ($eff-h ge 26) then $my-cy - 2 else $my-cy"/>
                    <svg:text x="{$left-x + $node-w div 2}" y="{$label-y}"
                              text-anchor="middle" dominant-baseline="central"
                              fill="white" font-family="Helvetica, Arial, sans-serif"
                              font-size="{$font-sz}" font-weight="bold">
                      <xsl:value-of select="mm:truncate($label, $max-chars-int)"/>
                    </svg:text>
                    <xsl:if test="$eff-h ge 26">
                      <svg:text x="{$left-x + $node-w div 2}" y="{$my-cy + 9}"
                                text-anchor="middle" dominant-baseline="central"
                                fill="white" fill-opacity="0.7"
                                font-family="Helvetica, Arial, sans-serif" font-size="7">
                        <xsl:value-of select="$leaf-info"/>
                      </svg:text>
                    </xsl:if>
                  </xsl:for-each>

                </svg:svg>
              </fo:instream-foreign-object>
            </fo:block>
          </fo:flow>
        </fo:page-sequence>
      </xsl:when>

      <!-- ====== UNILATERAL OVERVIEW ====== -->
      <xsl:otherwise>
        <xsl:variable name="leaf-count" as="xs:integer" select="max(($branch-count, 3))"/>
        <xsl:variable name="dims" as="xs:integer+" select="mm:compute-svg-dims($leaf-count, 1)"/>
        <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
        <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
        <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
        <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

        <fo:page-sequence master-reference="mindmap-page" id="page-overview">
          <xsl:call-template name="page-header">
            <xsl:with-param name="title" select="concat($map-title, ' — Overview')"/>
          </xsl:call-template>
          <xsl:call-template name="page-footer"/>
          <fo:flow flow-name="xsl-region-body">
            <fo:block text-align="center">
              <fo:instream-foreign-object
                  content-width="scale-to-fit" content-height="scale-to-fit"
                  width="100%" scaling="uniform">
                <svg:svg width="{$svg-w}" height="{$svg-h}"
                         viewBox="0 0 {$svg-w} {$svg-h}">
                  <xsl:variable name="root-x" as="xs:integer" select="$margin"/>
                  <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

                  <svg:rect x="{$root-x}" y="{$root-cy - $eff-h div 2}"
                            width="{$node-w}" height="{$eff-h}"
                            rx="6" ry="6"
                            fill="{$colors[1]}" stroke="#14527a" stroke-width="2"/>
                  <svg:text x="{$root-x + $node-w div 2}" y="{$root-cy}"
                            text-anchor="middle" dominant-baseline="central"
                            fill="white" font-family="Helvetica, Arial, sans-serif"
                            font-size="{$font-sz + 1}" font-weight="bold">
                    <xsl:value-of select="mm:truncate($map-title, $max-chars-int)"/>
                  </svg:text>

                  <xsl:variable name="child-x" as="xs:double"
                      select="$root-x + $node-w + $h-gap"/>
                  <xsl:variable name="alloc-height" as="xs:double"
                      select="$svg-h - 2 * $margin"/>

                  <xsl:for-each select="$topicrefs">
                    <xsl:variable name="pos" select="position()"/>
                    <xsl:variable name="my-top" as="xs:double"
                        select="$margin + (($pos - 1) div $branch-count) * $alloc-height"/>
                    <xsl:variable name="my-bottom" as="xs:double"
                        select="$margin + ($pos div $branch-count) * $alloc-height"/>
                    <xsl:variable name="my-cy" as="xs:double"
                        select="($my-top + $my-bottom) div 2"/>
                    <xsl:variable name="label" select="mm:node-label(.)"/>
                    <xsl:variable name="leaf-info"
                        select="concat(' (', mm:count-leaves-fn(.), ' nodes)')"/>
                    <xsl:variable name="custom-color" as="xs:string"
                        select="mm:node-bg-color(.)"/>
                    <xsl:variable name="color-index" as="xs:integer"
                        select="(($pos - 1) mod count($colors)) + 1"/>
                    <xsl:variable name="node-color" as="xs:string"
                        select="if ($custom-color != '') then $custom-color
                                else $colors[$color-index]"/>

                    <xsl:variable name="cx1" as="xs:double"
                        select="$root-x + $node-w + $h-gap div 2"/>
                    <svg:path d="M {$root-x + $node-w} {$root-cy}
                                 C {$cx1} {$root-cy}, {$cx1} {$my-cy}, {$child-x} {$my-cy}"
                              fill="none" stroke="#aaa" stroke-width="1.5"/>

                    <svg:rect x="{$child-x}" y="{$my-cy - $eff-h div 2}"
                              width="{$node-w}" height="{$eff-h}"
                              rx="6" ry="6"
                              fill="{$node-color}" stroke-width="1" stroke="{$node-color}"/>
                    <xsl:variable name="label-y" as="xs:double"
                        select="if ($eff-h ge 26) then $my-cy - 2 else $my-cy"/>
                    <svg:text x="{$child-x + $node-w div 2}" y="{$label-y}"
                              text-anchor="middle" dominant-baseline="central"
                              fill="white" font-family="Helvetica, Arial, sans-serif"
                              font-size="{$font-sz}" font-weight="bold">
                      <xsl:value-of select="mm:truncate($label, $max-chars-int)"/>
                    </svg:text>
                    <xsl:if test="$eff-h ge 26">
                      <svg:text x="{$child-x + $node-w div 2}" y="{$my-cy + 9}"
                                text-anchor="middle" dominant-baseline="central"
                                fill="white" fill-opacity="0.7"
                                font-family="Helvetica, Arial, sans-serif" font-size="7">
                        <xsl:value-of select="$leaf-info"/>
                      </svg:text>
                    </xsl:if>
                  </xsl:for-each>
                </svg:svg>
              </fo:instream-foreign-object>
            </fo:block>
          </fo:flow>
        </fo:page-sequence>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================
       Template: render-branch-page
       Renders one top-level branch as a full subtree on its own page.
       Always unilateral (right-only) since it shows a single branch.
       ================================================================ -->
  <xsl:template name="render-branch-page">
    <xsl:param name="branch-title" as="xs:string"/>
    <xsl:param name="branch-id" as="xs:string"/>
    <xsl:param name="branch-node" as="element()"/>
    <xsl:param name="branch-children" as="element()*"/>
    <xsl:param name="branch-leaves" as="xs:integer"/>
    <xsl:param name="branch-depth" as="xs:integer"/>
    <xsl:param name="branch-pos" as="xs:integer"/>

    <xsl:variable name="leaf-count" as="xs:integer" select="max(($branch-leaves, 3))"/>
    <xsl:variable name="depth" as="xs:integer" select="max(($branch-depth, 1))"/>
    <xsl:variable name="dims" as="xs:integer+" select="mm:compute-svg-dims($leaf-count, $depth)"/>
    <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
    <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
    <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
    <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

    <fo:page-sequence master-reference="mindmap-page" id="{$branch-id}">
      <xsl:call-template name="page-header">
        <xsl:with-param name="title" select="$branch-title"/>
      </xsl:call-template>
      <xsl:call-template name="page-footer"/>
      <fo:flow flow-name="xsl-region-body">
        <fo:block text-align="center">
          <fo:instream-foreign-object
              content-width="scale-to-fit" content-height="scale-to-fit"
              width="100%" scaling="uniform">
            <svg:svg width="{$svg-w}" height="{$svg-h}"
                     viewBox="0 0 {$svg-w} {$svg-h}">
              <xsl:variable name="root-x" as="xs:integer" select="$margin"/>
              <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

              <xsl:variable name="custom-color" as="xs:string" select="mm:node-bg-color($branch-node)"/>
              <xsl:variable name="color-index" as="xs:integer"
                  select="(($branch-pos - 1) mod count($colors)) + 1"/>
              <xsl:variable name="root-color" as="xs:string"
                  select="if ($custom-color != '') then $custom-color else $colors[$color-index]"/>

              <svg:rect x="{$root-x}" y="{$root-cy - $eff-h div 2}"
                        width="{$node-w}" height="{$eff-h}"
                        rx="6" ry="6"
                        fill="{$root-color}" stroke="#14527a" stroke-width="2"/>
              <svg:text x="{$root-x + $node-w div 2}" y="{$root-cy}"
                        text-anchor="middle" dominant-baseline="central"
                        fill="white" font-family="Helvetica, Arial, sans-serif"
                        font-size="{$font-sz + 1}" font-weight="bold">
                <xsl:value-of select="mm:truncate($branch-title, $max-chars-int)"/>
              </svg:text>

              <xsl:if test="exists($branch-children)">
                <xsl:call-template name="render-children">
                  <xsl:with-param name="children" select="$branch-children"/>
                  <xsl:with-param name="parent-edge-x" select="$root-x + $node-w"/>
                  <xsl:with-param name="parent-cy" select="$root-cy"/>
                  <xsl:with-param name="alloc-top" select="xs:double($margin)"/>
                  <xsl:with-param name="alloc-bottom" select="xs:double($svg-h - $margin)"/>
                  <xsl:with-param name="depth" select="1"/>
                  <xsl:with-param name="total-child-leaves" select="$leaf-count"/>
                  <xsl:with-param name="eff-node-h" select="$eff-h"/>
                  <xsl:with-param name="direction" select="'right'"/>
                </xsl:call-template>
              </xsl:if>
            </svg:svg>
          </fo:instream-foreign-object>
        </fo:block>
      </fo:flow>
    </fo:page-sequence>
  </xsl:template>

  <!-- ================================================================
       Template: page-header
       ================================================================ -->
  <xsl:template name="page-header">
    <xsl:param name="title" as="xs:string"/>
    <fo:static-content flow-name="xsl-region-before">
      <fo:block font-size="14pt" font-weight="bold"
                font-family="Helvetica, Arial, sans-serif"
                text-align="center"
                border-after-style="solid" border-after-width="0.5pt"
                border-after-color="#1f77b4"
                padding-after="4pt" space-after="4pt">
        <xsl:value-of select="$title"/>
      </fo:block>
    </fo:static-content>
  </xsl:template>

  <!-- ================================================================
       Template: page-footer
       ================================================================ -->
  <xsl:template name="page-footer">
    <fo:static-content flow-name="xsl-region-after">
      <fo:block font-size="7pt" text-align="center" color="#999"
                font-family="Helvetica, Arial, sans-serif">
        Generated by DITA-OT Mindmap Plugin — Page <fo:page-number/>
      </fo:block>
    </fo:static-content>
  </xsl:template>

  <!-- ================================================================
       Named template: render-children
       Distributes vertical space proportionally and renders nodes.
       Supports both directions: 'right' (default) and 'left'.

       parent-edge-x: the x coordinate of the parent's connecting edge
         - For 'right': the right edge of the parent node
         - For 'left': the left edge of the parent node
       ================================================================ -->
  <xsl:template name="render-children">
    <xsl:param name="children" as="element()*"/>
    <xsl:param name="parent-edge-x" as="xs:double"/>
    <xsl:param name="parent-cy" as="xs:double"/>
    <xsl:param name="alloc-top" as="xs:double"/>
    <xsl:param name="alloc-bottom" as="xs:double"/>
    <xsl:param name="depth" as="xs:integer"/>
    <xsl:param name="total-child-leaves" as="xs:integer"/>
    <xsl:param name="eff-node-h" as="xs:integer" select="$node-h"/>
    <xsl:param name="direction" as="xs:string" select="'right'"/>

    <xsl:variable name="is-left" as="xs:boolean" select="$direction = 'left'"/>

    <!-- Child node x position depends on direction -->
    <xsl:variable name="child-x" as="xs:double"
        select="if ($is-left)
                then $parent-edge-x - $h-gap - $node-w
                else $parent-edge-x + $h-gap"/>

    <xsl:variable name="alloc-height" as="xs:double"
        select="$alloc-bottom - $alloc-top"/>
    <xsl:variable name="color-index" as="xs:integer"
        select="(($depth) mod count($colors)) + 1"/>
    <xsl:variable name="font-sz" as="xs:integer"
        select="mm:font-size-for-node-h($eff-node-h)"/>

    <!-- Pre-compute leaf counts once for all children -->
    <xsl:variable name="leaf-counts" as="xs:integer*"
        select="for $c in $children return mm:count-leaves-fn($c)"/>
    <xsl:variable name="prefix-sums" as="xs:integer*"
        select="0, (for $i in 1 to count($children) - 1
                    return sum($leaf-counts[position() le $i]))"/>

    <xsl:for-each select="$children">
      <xsl:variable name="pos" select="position()"/>

      <xsl:variable name="my-leaves" as="xs:integer"
          select="$leaf-counts[$pos]"/>
      <xsl:variable name="preceding-leaves" as="xs:integer"
          select="$prefix-sums[$pos]"/>

      <xsl:variable name="my-top" as="xs:double"
          select="$alloc-top + ($preceding-leaves div max(($total-child-leaves, 1))) * $alloc-height"/>
      <xsl:variable name="my-bottom" as="xs:double"
          select="$alloc-top + (($preceding-leaves + $my-leaves) div max(($total-child-leaves, 1))) * $alloc-height"/>
      <xsl:variable name="my-cy" as="xs:double"
          select="($my-top + $my-bottom) div 2"/>

      <xsl:variable name="label" as="xs:string" select="mm:node-label(.)"/>
      <xsl:variable name="display-label" as="xs:string" select="mm:truncate($label, $max-chars-int)"/>

      <xsl:variable name="custom-color" as="xs:string" select="mm:node-bg-color(.)"/>
      <xsl:variable name="node-color" as="xs:string"
          select="if ($custom-color != '') then $custom-color else $colors[$color-index]"/>

      <!-- Connector: direction-aware Bezier curve -->
      <xsl:choose>
        <xsl:when test="$is-left">
          <!-- Left: parent left edge → child right edge -->
          <xsl:variable name="cx1" as="xs:double"
              select="$parent-edge-x - $h-gap div 2"/>
          <svg:path d="M {$parent-edge-x} {$parent-cy}
                       C {$cx1} {$parent-cy}, {$cx1} {$my-cy}, {$child-x + $node-w} {$my-cy}"
                    fill="none" stroke="#aaa" stroke-width="1.5"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Right: parent right edge → child left edge -->
          <xsl:variable name="cx1" as="xs:double"
              select="$parent-edge-x + $h-gap div 2"/>
          <svg:path d="M {$parent-edge-x} {$parent-cy}
                       C {$cx1} {$parent-cy}, {$cx1} {$my-cy}, {$child-x} {$my-cy}"
                    fill="none" stroke="#aaa" stroke-width="1.5"/>
        </xsl:otherwise>
      </xsl:choose>

      <!-- Node rectangle (adaptive height) -->
      <svg:rect x="{$child-x}" y="{$my-cy - $eff-node-h div 2}"
                width="{$node-w}" height="{$eff-node-h}"
                rx="4" ry="4"
                fill="{$node-color}" stroke-width="1"
                stroke="{$node-color}"/>

      <!-- Node label -->
      <svg:text x="{$child-x + $node-w div 2}" y="{$my-cy}"
                text-anchor="middle" dominant-baseline="central"
                fill="white" font-family="Helvetica, Arial, sans-serif"
                font-size="{$font-sz}">
        <xsl:value-of select="$display-label"/>
      </svg:text>

      <!-- Recurse into grandchildren -->
      <xsl:variable name="grandchildren" select="mm:effective-children(.)"/>
      <xsl:if test="exists($grandchildren)">
        <xsl:call-template name="render-children">
          <xsl:with-param name="children" select="$grandchildren"/>
          <xsl:with-param name="parent-edge-x"
              select="if ($is-left) then $child-x else $child-x + $node-w"/>
          <xsl:with-param name="parent-cy" select="$my-cy"/>
          <xsl:with-param name="alloc-top" select="$my-top"/>
          <xsl:with-param name="alloc-bottom" select="$my-bottom"/>
          <xsl:with-param name="depth" select="$depth + 1"/>
          <xsl:with-param name="total-child-leaves" select="$my-leaves"/>
          <xsl:with-param name="eff-node-h" select="$eff-node-h"/>
          <xsl:with-param name="direction" select="$direction"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
