<?xml version="1.0" encoding="UTF-8"?>
<!--
  map2mindmap-svg.xsl
  XSLT 3.0 stylesheet for DITA-OT mindmap-svg transtype.
  Transforms a resolved DITA map into a standalone SVG mindmap diagram.
  Reuses utility functions and render-children template from map2mindmap-fo.xsl.
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:svg="http://www.w3.org/2000/svg"
    xmlns:mm="urn:mindmap:local"
    exclude-result-prefixes="xs mm">

  <!-- Import the FO stylesheet for all utility functions and render-children -->
  <xsl:import href="map2mindmap-fo.xsl"/>

  <xsl:output method="xml" encoding="UTF-8" indent="yes"
              omit-xml-declaration="no"/>

  <!-- Override root template -->
  <xsl:template match="/">
    <xsl:apply-templates select="*[contains(@class, ' map/map ')]" mode="svg-standalone"/>
  </xsl:template>

  <!-- ================================================================
       Map template: generates standalone SVG
       ================================================================ -->
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="svg-standalone">
    <xsl:variable name="map-title" as="xs:string"
        select="string((*[contains(@class, ' topic/title ')], @title, 'Mindmap')[1])"/>

    <xsl:variable name="topicrefs" select="mm:effective-children(.)"/>

    <xsl:variable name="total-leaves" as="xs:integer"
        select="if (empty($topicrefs)) then 1
                else sum(for $t in $topicrefs return mm:count-leaves-fn($t))"/>
    <xsl:variable name="max-depth" as="xs:integer"
        select="if (empty($topicrefs)) then 1
                else mm:max-depth-fn($topicrefs, 1)"/>

    <xsl:variable name="branch-count" as="xs:integer" select="count($topicrefs)"/>

    <xsl:choose>
      <!-- ====== BILATERAL LAYOUT ====== -->
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

        <xsl:variable name="root-cx" as="xs:double"
            select="$margin + $left-depth * ($node-w + $h-gap) + $node-w div 2"/>
        <xsl:variable name="root-x" as="xs:double" select="$root-cx - $node-w div 2"/>
        <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

        <svg:svg xmlns:svg="http://www.w3.org/2000/svg"
                 width="{$svg-w}" height="{$svg-h}"
                 viewBox="0 0 {$svg-w} {$svg-h}">
          <svg:title><xsl:value-of select="$map-title"/></svg:title>
          <svg:style>text { font-family: Helvetica, Arial, sans-serif; }</svg:style>

          <!-- Background -->
          <svg:rect width="100%" height="100%" fill="#fafafa"/>

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
      </xsl:when>

      <!-- ====== UNILATERAL LAYOUT ====== -->
      <xsl:otherwise>
        <xsl:variable name="leaf-count" as="xs:integer" select="max(($total-leaves, 3))"/>
        <xsl:variable name="depth" as="xs:integer" select="max(($max-depth, 1))"/>
        <xsl:variable name="dims" as="xs:integer+" select="mm:compute-svg-dims($leaf-count, $depth)"/>
        <xsl:variable name="svg-w" as="xs:integer" select="$dims[1]"/>
        <xsl:variable name="svg-h" as="xs:integer" select="$dims[2]"/>
        <xsl:variable name="eff-h" as="xs:integer" select="$dims[3]"/>
        <xsl:variable name="font-sz" as="xs:integer" select="mm:font-size-for-node-h($eff-h)"/>

        <xsl:variable name="root-x" as="xs:integer" select="$margin"/>
        <xsl:variable name="root-cy" as="xs:double" select="$svg-h div 2"/>

        <svg:svg xmlns:svg="http://www.w3.org/2000/svg"
                 width="{$svg-w}" height="{$svg-h}"
                 viewBox="0 0 {$svg-w} {$svg-h}">
          <svg:title><xsl:value-of select="$map-title"/></svg:title>
          <svg:style>text { font-family: Helvetica, Arial, sans-serif; }</svg:style>

          <!-- Background -->
          <svg:rect width="100%" height="100%" fill="#fafafa"/>

          <!-- Root node -->
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
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
