# Specification: DITA-OT Mindmap Plugin (`com.github.jyjeanne.mindmap`)

**Version**: 2.3
**Date**: 04/03/2026
**Status**: Implementation
**Author**: jyjeanne

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 26/02/2026 | Initial design specs (spec2-spec5): data structure evaluation, custom `<mindmap>` XML, XSLT 1.0 prototype |
| 1.3 | 26/02/2026 | Added HTML template, DITA-OT plugin skeleton, PDF export concept |
| 2.0 | 04/03/2026 | Full rewrite: standard DITA map input, XSLT 3.0, Gradle build, SVG/FO PDF pipeline, jsMind v0.9.1 bundled |
| 2.1 | 04/03/2026 | Review: added phases, prerequisites, edge cases, testing, limitations, troubleshooting, accessibility |
| 2.2 | 04/03/2026 | Phase 1 complete: fixed build.gradle.kts (3 errors), build.xml (FOP classpath → pdf2.fop), plugin.xml (added pdf2.fop dependency), added Zip packaging task |
| 2.3 | 04/03/2026 | Phase 2+3 complete: DITA edge case handling, 5 bug fixes (XSS, FOP filename, JSON escaping, perf optimization), Phase 3 enhancements (mode, lang, colors, screenshot, noscript, max-chars) |
| 2.4 | 04/03/2026 | Code review #2: 5 additional fixes (editable JS sanitization, color validation regex, locktitle in test-colors, escape-json sync). Phase 4 integration test (10/10 pass). P4.1 multi-page PDF, P3.6 bookmarks, P4.5 CI workflow |
| 2.5 | 04/03/2026 | Code review #3: 7 bugs fixed (bookmark IDs missing in single-page, overview nodes same color, rgba() FOP compat, escape-js-single incomplete, CI permissions, dead params). 12/12 integration tests pass |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites and System Requirements](#2-prerequisites-and-system-requirements)
3. [Project Structure](#3-project-structure)
4. [Input Format](#4-input-format)
5. [Output Formats](#5-output-formats)
6. [Plugin Descriptor](#6-plugin-descriptor-pluginxml)
7. [Ant Build Targets](#7-ant-build-targets-buildxml)
8. [XSLT 3.0 Stylesheets](#8-xslt-30-stylesheets)
9. [jsMind Library](#9-jsmind-library)
10. [Gradle Build](#10-gradle-build)
11. [Data Structure Decision](#11-data-structure-decision)
12. [JSON Output Format](#12-json-output-format)
13. [Error Handling and Edge Cases](#13-error-handling-and-edge-cases)
14. [Known Limitations](#14-known-limitations)
15. [Accessibility](#15-accessibility)
16. [Performance](#16-performance)
17. [Testing Strategy](#17-testing-strategy)
18. [Troubleshooting](#18-troubleshooting)
19. [Development Phases](#19-development-phases)

---

## 1. Overview

This plugin extends DITA Open Toolkit 4.4 with two custom transtypes that transform
standard DITA map files (`.ditamap`) into mindmap visualizations:

| Transtype | Output | Description |
|-----------|--------|-------------|
| `mindmap-html` | Standalone HTML | Interactive mindmap powered by jsMind v0.9.1 (bundled locally) |
| `mindmap-pdf` | PDF document | Static SVG tree diagram rendered via XSL-FO + Apache FOP |

The `<topicref>` hierarchy of any DITA map is read as the mindmap tree.
Each `<topicref>` becomes a node; its label is resolved from `topicmeta/navtitle`,
`@navtitle`, or `@href` (filename fallback).

A secondary standalone XSLT (`mindmap2jsmind.xsl`) is also provided for transforming
a custom `<mindmap>` XML format directly to jsMind JSON outside the DITA-OT pipeline.

---

## 2. Prerequisites and System Requirements

### 2.1 Runtime Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| Java (JDK or JRE) | 17+ | Required by DITA-OT 4.4 and Gradle 8.5 |
| DITA-OT | 4.4 | Processing pipeline (downloaded automatically by Gradle) |
| Saxon HE | 12.x | XSLT 3.0 processor (bundled with DITA-OT 4.4) |
| Apache FOP | 2.11 | PDF rendering (bundled with DITA-OT 4.4 via `org.dita.pdf2.fop`) |

### 2.2 Build Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| Gradle | 8.5 | Build automation (via wrapper, no global install needed) |
| `io.github.jyjeanne.dita-ot-gradle` | 2.8.5 | Gradle plugin for DITA-OT tasks |

### 2.3 Development Requirements (optional, for rebuilding jsMind)

| Component | Version | Purpose |
|-----------|---------|---------|
| Node.js | 18+ | Building jsMind from source |
| npm | 9+ | Package management |

### 2.4 Supported Platforms

| Platform | Status |
|----------|--------|
| Windows 10/11 | Tested (primary) |
| macOS 12+ | Expected compatible |
| Linux (Ubuntu 22.04+) | Expected compatible |

---

## 3. Project Structure

```
test-jsmind/
├── build.gradle.kts                          Gradle build (Kotlin DSL)
├── settings.gradle.kts                       rootProject.name = "dita-mindmap"
├── gradlew / gradlew.bat                     Gradle 8.5 wrapper
├── gradle/wrapper/
│   ├── gradle-wrapper.jar
│   └── gradle-wrapper.properties
│
├── dita-ot-mindmap-plugin/                   DITA-OT plugin
│   ├── plugin.xml                            Plugin descriptor (2 transtypes)
│   ├── build.xml                             Ant build targets
│   ├── xsl/
│   │   ├── map2mindmap-html.xsl              XSLT 3.0: ditamap -> HTML + jsMind
│   │   ├── map2mindmap-fo.xsl                XSLT 3.0: ditamap -> XSL-FO + SVG
│   │   └── mindmap2jsmind.xsl                XSLT 3.0: custom <mindmap> -> JSON
│   └── resources/
│       ├── mindmap.css                       HTML page styling + print styles
│       └── jsmind/                           jsMind v0.9.1 (built from source)
│           ├── jsmind.js                     Core library (50 KB)
│           ├── jsmind.draggable-node.js      Drag & drop plugin (9.6 KB)
│           ├── jsmind.screenshot.js          Screenshot export plugin (3.2 KB)
│           ├── jsmind.css                    Themes & styles (7.9 KB)
│           └── LICENSE                       BSD-3-Clause
│
├── samples/
│   ├── sample.ditamap                        Standard DITA map (main test input)
│   ├── test-edge-cases.ditamap               Edge cases: topicgroup, topichead, filters
│   ├── test-wide-map.ditamap                 Wide map: 12 siblings, auto-collapse test
│   ├── test-single-node.ditamap              Minimal: root only, no topicrefs
│   ├── test-colors.ditamap                   Custom node colors via topicmeta/data
│   ├── sample-mindmap.xml                    Custom <mindmap> XML (standalone use)
│   └── topics/                               7 sample .dita topic files
│       ├── introduction.dita
│       ├── objectives.dita
│       ├── target-audience.dita
│       ├── installation.dita
│       ├── prerequisites.dita
│       ├── install-steps.dita
│       └── faq.dita
│
├── docs/                                     Specifications
│   ├── SPEC_MINDMAP_PLUGIN.md                This document
│   └── ...                                   Earlier design specs
│
└── index.html                                Standalone jsMind demo (static)
```

---

## 4. Input Format

### 4.1 Primary Input: Standard DITA Map

The plugin accepts any standard `.ditamap` file. DITA-OT preprocessing resolves
conrefs, keys, and navtitles before the XSLT transformation runs.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE map PUBLIC "-//OASIS//DTD DITA Map//EN" "map.dtd">
<map>
  <title>Documentation Produit X</title>

  <topicref href="topics/introduction.dita" navtitle="Introduction">
    <topicref href="topics/objectives.dita" navtitle="Objectifs"/>
    <topicref href="topics/target-audience.dita" navtitle="Public cible"/>
  </topicref>

  <topicref href="topics/installation.dita" navtitle="Installation">
    <topicref href="topics/prerequisites.dita" navtitle="Prerequis"/>
    <topicref href="topics/install-steps.dita" navtitle="Etapes d installation"/>
  </topicref>

  <topicref href="topics/faq.dita" navtitle="FAQ"/>
</map>
```

**Mapping rules:**

| DITA element | Mindmap concept |
|-------------|-----------------|
| `<map><title>` | Root node label |
| `<topicref>` | Child node |
| Nested `<topicref>` | Grandchild nodes (unlimited depth) |
| `<topicmeta>/<navtitle>` | Node label (priority 1) |
| `@navtitle` | Node label (priority 2) |
| `@href` filename (stripped of path/extension) | Node label (priority 3, fallback) |
| `@id` or `generate-id()` | Node identifier |

**Special DITA elements handling:**

| Element / Attribute | Behavior |
|---------------------|----------|
| `<topicgroup>` | Transparent container: its children are promoted to the parent level. The `<topicgroup>` itself does not create a mindmap node. |
| `<topichead>` | Creates a node using its `<navtitle>` as label. Has no `@href`. |
| `@processing-role="resource-only"` | Excluded from the mindmap. These topicrefs are resources (keydefs, etc.) and should not appear as visual nodes. |
| `@toc="no"` | Excluded from the mindmap. Not intended for navigation views. |
| `<mapref>` | Resolved by DITA-OT preprocess. The referenced sub-map's topicrefs appear in the resolved map and are rendered normally. |
| `<keydef>` | Excluded (inherits `@processing-role="resource-only"`). |
| `@scope="external"` | Creates a node. Label falls back to `@href` URL if no navtitle. |
| `@scope="peer"` | Creates a node. Label falls back to `@href` if no navtitle. |
| `@format` (non-dita values) | Creates a node normally. The `@format` attribute is ignored for mindmap rendering. |

### 4.2 Secondary Input: Custom `<mindmap>` XML (Standalone)

A specialized XML format for standalone use outside DITA-OT. Transformed by
`mindmap2jsmind.xsl` directly via any XSLT 3.0 processor (e.g. Saxon HE).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mindmap PUBLIC "-//OASIS//DTD DITA Mindmap//EN" "mindmap.dtd">
<mindmap xmlns:dita="http://dita.oasis-open.org/architecture/2005/">
  <node id="root" title="Documentation Produit X" color="#1f77b4"
        icon="root" expanded="true">
    <node id="introduction" title="Introduction" color="#ff7f0e"
          icon="info" expanded="true">
      <node id="objectifs" title="Objectifs" color="#2ca02c"
            icon="target" expanded="false" url="objectifs.dita"/>
      <node id="public" title="Public cible" color="#d62728"
            icon="users" expanded="false" url="public.dita"/>
    </node>
    <node id="installation" title="Installation" color="#9467bd"
          icon="gear" expanded="true">
      <node id="prerequis" title="Prérequis" color="#8c564b"
            icon="check" expanded="false" url="prerequis.dita"/>
      <node id="etapes" title="Etapes d'installation" color="#e377c2"
            icon="list" expanded="false" url="etapes.dita"/>
    </node>
    <node id="faq" title="FAQ" color="#7f7f7f"
          icon="question" expanded="false"/>
  </node>
</mindmap>
```

**`<node>` attributes:**

| Attribute | Required | Type | jsMind mapping |
|-----------|----------|------|----------------|
| `id` | Yes | string | `id` |
| `title` | Yes | string | `topic` |
| `color` | No | hex color (`#RRGGBB`) | `data.background-color` |
| `icon` | No | string | `icon` |
| `expanded` | No | `true` / `false` (default: `false`) | `expanded` (boolean) |
| `url` | No | URI | `url` |

---

## 5. Output Formats

### 5.1 Transtype `mindmap-html`

Generates a **self-contained HTML5 page** with an interactive jsMind mindmap.
All JavaScript and CSS are bundled locally (no CDN dependency). The output works
offline once generated.

**Pipeline:**

```
sample.ditamap
    |  DITA-OT preprocess (resolve conrefs, keys, navtitles)
    v
resolved map (dita.temp.dir)
    |  map2mindmap-html.xsl (Saxon HE, XSLT 3.0)
    v
sample.html
    + mindmap.css           (copied from plugin resources)
    + jsmind/               (copied from plugin resources)
        jsmind.js
        jsmind.draggable-node.js
        jsmind.screenshot.js
        jsmind.css
```

**Parameters:**

| Parameter | Type | Default | Values | Description |
|-----------|------|---------|--------|-------------|
| `jsmind.theme` | enum | `primary` | `primary`, `warning`, `danger`, `success`, `info`, `greensea`, `nephritis`, `belizehole`, `wisteria`, `asphalt` | jsMind CSS color theme |
| `jsmind.editable` | enum | `false` | `true`, `false` | Allow user to edit node labels at runtime |
| `jsmind.mode` | enum | `full` | `full`, `side` | Layout: `full` = both sides of root, `side` = right only |
| `mindmap.lang` | string | `en` | BCP 47 tag | HTML `lang` attribute (e.g. `en`, `fr`, `de`) |

**Output directory contents:**

```
build/output/mindmap-html/
├── sample.html                 Standalone HTML page
├── mindmap.css                 Page styling
└── jsmind/
    ├── jsmind.js               Core library
    ├── jsmind.draggable-node.js
    ├── jsmind.screenshot.js
    └── jsmind.css              Themes
```

**HTML features:**
- Interactive: expand/collapse nodes by click, drag to reposition (via draggable-node plugin)
- Controls: "Expand All", "Collapse All", "Screenshot", "Print / PDF" buttons in header bar
- Screenshot export: Downloads mindmap as PNG image (via `jsmind.screenshot.js` plugin)
- Responsive: full viewport height (`calc(100vh - 46px)`)
- Print-optimized: `@media print` CSS hides controls, adjusts container height
- Auto-collapse: nodes with more than 6 children start collapsed for readability
- Custom node colors: `<data name="mindmap-color" value="#RRGGBB"/>` in `<topicmeta>` sets `background-color`
- `<noscript>` fallback: informative message when JavaScript is disabled
- Layout modes: `full` (both sides of root) or `side` (right only), via `jsmind.mode` parameter
- Configurable language: `<html lang>` attribute set via `mindmap.lang` parameter
- Encoding: UTF-8 throughout (HTML meta, XSLT output, JSON strings)
- XSS-safe: JSON values escaped for safe `<script>` embedding (prevents `</script>` injection)

**jsMind JSON format (`node_tree`):**

```json
{
  "meta": {"name": "Documentation Produit X"},
  "format": "node_tree",
  "data": {
    "id": "root",
    "topic": "Documentation Produit X",
    "expanded": true,
    "children": [
      {
        "id": "<topicref @id or generate-id()>",
        "topic": "<navtitle or @navtitle or filename>",
        "expanded": true,
        "children": [...]
      }
    ]
  }
}
```

### 5.2 Transtype `mindmap-pdf`

Generates a **PDF document** containing an SVG tree diagram of the mindmap.
Uses XSL-FO with inline SVG, rendered by Apache FOP (bundled with DITA-OT
via `org.dita.pdf2`).

**Pipeline:**

```
sample.ditamap
    |  DITA-OT preprocess
    v
resolved map (dita.temp.dir)
    |  map2mindmap-fo.xsl (Saxon HE, XSLT 3.0)
    v
sample.fo (XSL-FO with inline SVG in fo:instream-foreign-object)
    |  Apache FOP 2.9 (org.apache.fop.cli.Main)
    v
sample.pdf
```

**Parameters:**

| Parameter | Type | Default | Values | Description |
|-----------|------|---------|--------|-------------|
| `mindmap.page.size` | enum | `A4-landscape` | `A4-landscape` (297x210mm), `A3-landscape` (420x297mm), `letter-landscape` (279x216mm) | Page dimensions and orientation |
| `mindmap.max.chars` | string | `20` | integer as string | Maximum characters per node label before truncation with `...` |

**SVG tree layout algorithm:**

1. **Measure**: Recursively count leaf nodes (`count-leaves`) and max depth (`compute-max-depth`)
2. **Canvas sizing**:
   - `width = (depth + 1) * (node_w + h_gap) + 2 * margin`
   - `height = max(leaves, 3) * (node_h + v_gap) + 2 * margin`
3. **Root placement**: Left-center of canvas (`x = margin`, `y = height / 2`)
4. **Child positioning**: Vertical space distributed proportionally to each subtree's leaf count
5. **Rendering**: Rounded rectangles, centered text labels, cubic Bezier curve connectors
6. **Scaling**: `fo:instream-foreign-object` with `content-width="scale-to-fit"` and `scaling="uniform"` to fit within page

**SVG layout constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `node-w` | 150 | Node rectangle width (px) |
| `node-h` | 32 | Node rectangle height (px) |
| `h-gap` | 50 | Horizontal spacing between depth levels (px) |
| `v-gap` | 12 | Vertical spacing between sibling nodes (px) |
| `margin` | 30 | Canvas edge margin (px) |
| `max-chars` | 20 | Max label characters before truncation with "..." |

**Color palette** (10 colors, cycles by depth level via `depth mod 10 + 1`):

| Index | Hex | Color name |
|-------|-----|------------|
| 1 (root) | `#1f77b4` | Blue |
| 2 | `#ff7f0e` | Orange |
| 3 | `#2ca02c` | Green |
| 4 | `#d62728` | Red |
| 5 | `#9467bd` | Purple |
| 6 | `#8c564b` | Brown |
| 7 | `#e377c2` | Pink |
| 8 | `#7f7f7f` | Gray |
| 9 | `#17becf` | Cyan |
| 10 | `#bcbd22` | Olive |

**PDF page layout:**

| Region | Content |
|--------|---------|
| Header (`xsl-region-before`, 16mm) | Map title: 14pt bold Helvetica, centered, blue bottom border |
| Body (`xsl-region-body`) | SVG mindmap diagram, centered, scaled to fit |
| Footer (`xsl-region-after`, 8mm) | "Generated by DITA-OT Mindmap Plugin": 7pt gray |
| Margins | 12mm all sides |

---

## 6. Plugin Descriptor (`plugin.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-model href="https://www.dita-ot.org/rng/plugin.rnc"
            type="application/relax-ng-compact-syntax"?>
<plugin id="com.github.jyjeanne.mindmap">

  <!-- Dependencies -->
  <require plugin="org.dita.base"/>
  <require plugin="org.dita.pdf2"/>
  <require plugin="org.dita.pdf2.fop"/>

  <!-- Transtype: mindmap-html -->
  <transtype name="mindmap-html"
             desc="Interactive HTML mindmap using jsMind">
    <param name="jsmind.theme" type="enum"
           desc="jsMind color theme for the mindmap visualization">
      <val default="true">primary</val>
      <val>warning</val>
      <val>danger</val>
      <val>success</val>
      <val>info</val>
      <val>greensea</val>
      <val>nephritis</val>
      <val>belizehole</val>
      <val>wisteria</val>
      <val>asphalt</val>
    </param>
    <param name="jsmind.editable" type="enum"
           desc="Whether the mindmap nodes are editable by the user">
      <val default="true">false</val>
      <val>true</val>
    </param>
  </transtype>

  <!-- Transtype: mindmap-pdf -->
  <transtype name="mindmap-pdf"
             desc="PDF document with SVG mindmap tree diagram">
    <param name="mindmap.page.size" type="enum"
           desc="Page size and orientation for the PDF output">
      <val default="true">A4-landscape</val>
      <val>A3-landscape</val>
      <val>letter-landscape</val>
    </param>
  </transtype>

  <!-- Register Ant build file -->
  <feature extension="ant.import" file="build.xml"/>

</plugin>
```

**Design decisions:**

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Plugin ID | `com.github.jyjeanne.mindmap` | Follows reverse-domain convention matching the Gradle plugin namespace |
| Extension point | `ant.import` | Modern DITA-OT 3.x/4.x pattern. Replaces deprecated `dita.conductor.target.relative` |
| `org.dita.base` dependency | Required | Provides the preprocessing pipeline (`build-init`, `preprocess`) |
| `org.dita.pdf2` dependency | Required | Provides PDF infrastructure. Ships with DITA-OT 4.4 by default |
| `org.dita.pdf2.fop` dependency | Required | Provides Apache FOP 2.11 JARs for XSL-FO to PDF rendering |
| Parameters as enums | All params use `<val>` | Enables DITA-OT parameter validation at invocation time |

---

## 7. Ant Build Targets (`build.xml`)

### 7.1 `dita2mindmap-html`

```
dita2mindmap-html
  ├── dita2mindmap-html.init              Set plugin dir, default params
  ├── build-init                          DITA-OT initialization
  ├── preprocess                          Resolve conrefs, keys, navtitles
  ├── dita2mindmap-html.transform         XSLT 3.0 via Saxon HE
  └── dita2mindmap-html.copy-resources    Copy CSS + jsMind/ to output
```

### 7.2 `dita2mindmap-pdf`

```
dita2mindmap-pdf
  ├── dita2mindmap-pdf.init               Set plugin dir, page size, locate pdf2
  ├── build-init                          DITA-OT initialization
  ├── preprocess                          Resolve conrefs, keys, navtitles
  ├── dita2mindmap-pdf.generate-fo        XSLT 3.0 -> XSL-FO with inline SVG
  └── dita2mindmap-pdf.render-pdf         FOP -> PDF
```

### 7.3 Ant Property Reference

| Property | Set by | Default | Description |
|----------|--------|---------|-------------|
| `mindmap.plugin.dir` | `.init` target | (resolved from DITA-OT) | Absolute path to the installed plugin directory |
| `jsmind.theme` | `plugin.xml` param | `primary` | Passed to XSLT as `jsmind-theme` |
| `jsmind.editable` | `plugin.xml` param | `false` | Passed to XSLT as `jsmind-editable` |
| `mindmap.page.size` | `plugin.xml` param | `A4-landscape` | Passed to XSLT as `page-size` |
| `fop.plugin.dir` | `.init` target | (resolved from DITA-OT) | Path to `org.dita.pdf2.fop` (for FOP 2.11 JARs) |
| `dita.temp.dir` | DITA-OT | (automatic) | Temporary directory with resolved map |
| `dita.output.dir` | DITA-OT | (automatic) | Final output directory |
| `user.input.file` | DITA-OT | (automatic) | Resolved input map filename |
| `dita.dir` | DITA-OT | (automatic) | DITA-OT installation root |

### 7.4 XSLT Invocation Details

| Setting | Value |
|---------|-------|
| Factory | `net.sf.saxon.TransformerFactoryImpl` (forces Saxon HE for XSLT 3.0) |
| Classpath | `dost.class.path` (DITA-OT bundled JARs including Saxon HE 12.x) |
| Input base | `${dita.temp.dir}` |
| Input filter | `${user.input.file}` |
| Force | `true` (always re-run, no caching) |

### 7.5 FOP Invocation Details

| Setting | Value |
|---------|-------|
| Class | `org.apache.fop.cli.Main` |
| Classpath | `${fop.plugin.dir}/lib/*.jar` + `${dita.dir}/lib/*.jar` |
| Fork | `true` (separate JVM for FOP) |
| Arguments | `-fo <input.fo> -pdf <output.pdf>` |

---

## 8. XSLT 3.0 Stylesheets

### 8.1 `map2mindmap-html.xsl`

Transforms a resolved DITA map into a standalone HTML5 page.

**Approach:**
- Matches `*[contains(@class, ' map/map ')]` (standard DITA class-based matching, handles specializations)
- Builds jsMind `node_tree` JSON via recursive named template `node-to-json`
- Embeds JSON in a `<script>` block within the generated HTML
- References local jsMind files: `jsmind/jsmind.js`, `jsmind/jsmind.draggable-node.js`, `jsmind/jsmind.css`

**XSLT 3.0 features used:**
- Typed parameters: `as="xs:string"`, `as="xs:boolean"`, `as="element()*"`
- Arrow operator: `=> replace(...)`
- Sequence first-item selector: `(...)[1]`
- Conditional expressions: `if (...) then ... else ...`
- `html-version="5"` output serialization

**Node label resolution** (priority order):
1. `*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]` (set by DITA-OT preprocess when topic is resolved)
2. `@navtitle` attribute on the `<topicref>`
3. `@href` with path and extension stripped via `replace(replace(@href, '^.*/', ''), '\.[^.]+$', '')`
4. `'Untitled'` (hard fallback)

**JSON string escaping** (via `mm:escape-json()` function):
- Backslashes: `\` -> `\\`
- Double quotes: `"` -> `\"`
- Newlines: LF -> `\n`, CR -> `\r`
- Tabs: TAB -> `\t`

**XSLT 3.0 helper functions** (namespace `urn:mindmap:local`):

| Function | Signature | Description |
|----------|-----------|-------------|
| `mm:escape-json()` | `(xs:string) -> xs:string` | Escapes for JSON inside `<script>` blocks (backslash, quotes, newlines, `/`, `<`) |
| `mm:escape-js-single()` | `(xs:string) -> xs:string` | Escapes for JS single-quoted strings (backslash, `'`, `<`) |
| `mm:is-visible-topicref()` | `(element) -> xs:boolean` | Returns false for `@processing-role="resource-only"` or `@toc="no"` |
| `mm:effective-children()` | `(element) -> element()*` | Returns visible children, flattening `<topicgroup>` elements |
| `mm:node-bg-color()` | `(element) -> xs:string` | Extracts `<data name="mindmap-color" value="..."/>` from topicmeta |

**XSLT Parameters:**

| Parameter name | XSD type | Default | Passed from Ant property |
|----------------|----------|---------|--------------------------|
| `jsmind-theme` | `xs:string` | `'primary'` | `${jsmind.theme}` |
| `jsmind-editable` | `xs:string` | `'false'` | `${jsmind.editable}` |
| `jsmind-mode` | `xs:string` | `'full'` | `${jsmind.mode}` |
| `mindmap-lang` | `xs:string` | `'en'` | `${mindmap.lang}` |

### 8.2 `map2mindmap-fo.xsl`

Transforms a resolved DITA map into XSL-FO with inline SVG tree diagram.

**XSLT 3.0 helper functions** (namespace `urn:mindmap:local`):

| Function | Signature | Description |
|----------|-----------|-------------|
| `mm:is-visible-topicref()` | `(element) -> xs:boolean` | Filters `@processing-role="resource-only"` and `@toc="no"` |
| `mm:effective-children()` | `(element) -> element()*` | Returns visible children, flattening `<topicgroup>` |
| `mm:count-leaves-fn()` | `(element) -> xs:integer` | Counts leaf nodes using effective children |
| `mm:max-depth-fn()` | `(element*, xs:integer) -> xs:integer` | Computes max depth using effective children |
| `mm:node-label()` | `(element) -> xs:string` | Extracts display label (navtitle > @navtitle > @href > 'Untitled') |
| `mm:node-bg-color()` | `(element) -> xs:string` | Extracts `<data name="mindmap-color" value="..."/>` from topicmeta |

**Named templates:**

| Template | Parameters | Returns | Purpose |
|----------|-----------|---------|---------|
| `render-children` | `children`, `parent-right-x`, `parent-cy`, `alloc-top`, `alloc-bottom`, `depth`, `total-child-leaves` | SVG elements | Recursive: distributes vertical space proportionally, draws connector + rect + text for each child, recurses into grandchildren |

**SVG rendering per node (in order):**
1. **Connector**: Cubic Bezier `<svg:path>` from parent's right edge to child's left edge (`M ... C ...`), stroke `#aaa`, 1.5px
2. **Rectangle**: `<svg:rect>` with rounded corners (`rx="6"`), depth-based fill color, width 150, height 32
3. **Label**: `<svg:text>` centered in rectangle (`text-anchor="middle"`, `dominant-baseline="central"`), white, Helvetica 10px, truncated at 20 chars

**XSLT Parameters:**

| Parameter name | XSD type | Default | Passed from Ant property |
|----------------|----------|---------|--------------------------|
| `page-size` | `xs:string` | `'A4-landscape'` | `${mindmap.page.size}` |
| `max-chars` | `xs:integer` | `20` | `${mindmap.max.chars}` |

### 8.3 `mindmap2jsmind.xsl` (Standalone)

Transforms custom `<mindmap>` XML to jsMind JSON. **Not used by the DITA-OT pipeline.**

```bash
# Standalone usage with Saxon HE:
java -jar saxon-he.jar -s:sample-mindmap.xml -xsl:mindmap2jsmind.xsl -o:output.json
```

**Mapping:**

| XML attribute | JSON property | Notes |
|---------------|---------------|-------|
| `@id` | `"id"` | Required, unique identifier |
| `@title` | `"topic"` | Displayed label, escaped for JSON |
| `@color` | `"data": {"background-color": "..."}` | Uses jsMind `data` sub-object convention |
| `@expanded` | `"expanded": true/false` | Converted from string to JSON boolean |
| `@url` | `"url"` | Clickable link on the node |
| Child `<node>` elements | `"children": [...]` | Recursive array |

---

## 9. jsMind Library

**Version:** 0.9.1
**Source:** https://github.com/hizzgdev/jsmind (tag `v0.9.1`, released 2025-12-15)
**License:** BSD-3-Clause
**Bundling method:** Cloned from GitHub, built from source via `npm install && npm run build` (Rollup), ES6 output copied to `resources/jsmind/`

**Bundled files:**

| File | Size | Purpose |
|------|------|---------|
| `jsmind.js` | 50 KB | Core mindmap engine (layout, rendering, data model) |
| `jsmind.draggable-node.js` | 9.6 KB | Drag & drop node repositioning |
| `jsmind.screenshot.js` | 3.2 KB | Screenshot/canvas export capability |
| `jsmind.css` | 7.9 KB | Default styling + 15 theme variants |
| `LICENSE` | 3 KB | BSD-3-Clause license text |

**Available themes (from jsmind.css):**
`primary`, `warning`, `danger`, `success`, `info`, `greensea`, `nephritis`,
`belizehole`, `wisteria`, `asphalt`, `orange`, `pumpkin`, `pomegranate`,
`clouds`, `asbestos`

**jsMind runtime configuration (embedded in generated HTML):**

```javascript
var options = {
  container: 'jsmind_container',
  theme: '<jsmind.theme parameter>',   // from plugin param
  editable: <jsmind.editable parameter>, // from plugin param
  mode: 'full',                         // display mode
  layout: {
    hspace: 80,   // horizontal node spacing (px)
    vspace: 25,   // vertical node spacing (px)
    pspace: 13    // padding space (px)
  }
};
```

### 9.1 Rebuilding jsMind from Source

If a newer version of jsMind is released:

```bash
# 1. Clone or download the release
git clone --branch v0.9.1 https://github.com/hizzgdev/jsmind.git /tmp/jsmind

# 2. Build
cd /tmp/jsmind
npm install
npm run build    # Rollup generates es6/jsmind.js, es6/jsmind.draggable-node.js, es6/jsmind.screenshot.js

# 3. Copy to plugin resources
cp es6/jsmind.js es6/jsmind.draggable-node.js es6/jsmind.screenshot.js \
   style/jsmind.css LICENSE \
   dita-ot-mindmap-plugin/resources/jsmind/

# 4. Test: ./gradlew generateMindmapHtml and verify in browser
```

---

## 10. Gradle Build

**Build tool:** Gradle 8.5 (via wrapper, no global install needed)
**DSL:** Kotlin (`build.gradle.kts`)
**Plugin:** `io.github.jyjeanne.dita-ot-gradle` version 2.8.5

### 10.1 Task Definitions

| Task | Type | Depends On | Description |
|------|------|-----------|-------------|
| `downloadDitaOt` | `DitaOtDownloadTask` | - | Downloads DITA-OT 4.4 to `build/dita-ot/dita-ot-4.4/` |
| `packageMindmapPlugin` | `Zip` | - | Zips `dita-ot-mindmap-plugin/` to `build/plugin-zip/` (required by `dita install`) |
| `installMindmapPlugin` | `DitaOtInstallPluginTask` | `downloadDitaOt`, `packageMindmapPlugin` | Installs plugin ZIP into DITA-OT (`force = true` for dev iteration) |
| `generateMindmapHtml` | `DitaOtTask` | `installMindmapPlugin` | Runs `mindmap-html` transtype on `samples/sample.ditamap` |
| `generateMindmapPdf` | `DitaOtTask` | `installMindmapPlugin` | Runs `mindmap-pdf` transtype on `samples/sample.ditamap` |
| `generateAll` | (lifecycle) | `generateMindmapHtml`, `generateMindmapPdf` | Convenience: runs both outputs |

### 10.2 Task Dependency Chain

```
downloadDitaOt        packageMindmapPlugin (Zip)
    |                       |
    +-----------+-----------+
                |
                v
    installMindmapPlugin (force = true)
                |
    +-----------+-----------+
    |                       |
    v                       v
generateMindmapHtml     generateMindmapPdf
    |                       |
    v                       v
build/output/           build/output/
  mindmap-html/           mindmap-pdf/
```

### 10.3 Usage

```bash
# Full pipeline (download + install + generate both)
./gradlew generateAll

# Individual steps
./gradlew downloadDitaOt          # Download DITA-OT 4.4
./gradlew installMindmapPlugin    # Deploy plugin into DITA-OT
./gradlew generateMindmapHtml     # HTML mindmap only
./gradlew generateMindmapPdf      # PDF mindmap only
```

### 10.4 Gradle Plugin API Reference

**`DitaOtDownloadTask`** properties:

| Property | Type | Description |
|----------|------|-------------|
| `version` | `Property<String>` | DITA-OT version to download (e.g. `"4.4"`) |
| `destinationDir` | `DirectoryProperty` | Output directory (convention: `build/dita-ot/`) |
| `retries` | `Property<Int>` | Download retry count (default: 3) |

**`DitaOtInstallPluginTask`** properties:

| Property | Type | Description |
|----------|------|-------------|
| `ditaOtDir` | `DirectoryProperty` | DITA-OT installation directory |
| `plugins` | `ListProperty<String>` | List of plugin paths to install |
| `force` | `Property<Boolean>` | Force reinstall (default: false) |

**`DitaOtTask`** methods:

| Method | Signature | Description |
|--------|-----------|-------------|
| `ditaOt()` | `fun ditaOt(d: Any?)` | Set DITA-OT dir (accepts File, Directory, Provider, String) |
| `input()` | `fun input(i: Any)` | Set input file(s) |
| `output()` | `fun output(o: String)` | Set output directory (**String path only**, not Provider) |
| `transtype()` | `fun transtype(vararg t: String)` | Set transtype(s) |
| `properties {}` | `fun properties(block: PropertyBuilder.() -> Unit)` | Set DITA-OT properties (Kotlin DSL) |

### 10.5 Resolved `build.gradle.kts` Issues (Phase 1)

Three issues were fixed during Phase 1:

1. **`output()` type mismatch** — `DitaOtTask.output()` accepts `String` only, not `Provider<Directory>`.
   **Fix:** `output(layout.buildDirectory.dir("...").get().asFile.absolutePath)`

2. **`ditaOtDir` shadowing** — `DitaOtInstallPluginTask.ditaOtDir` shadows the local variable.
   **Fix:** Renamed local variable to `val ditaOtPath`.

3. **Plugin packaging** — `dita install` expects a ZIP file, not a directory path.
   **Fix:** Added `packageMindmapPlugin` Zip task before `installMindmapPlugin`.

4. **FOP classpath** — FOP JARs are in `org.dita.pdf2.fop`, not `org.dita.pdf2`.
   **Fix:** Updated `build.xml` to use `${dita.plugin.org.dita.pdf2.fop.dir}`.

---

## 11. Data Structure Decision

Four approaches were evaluated for representing mindmaps in DITA:

| Option | Approach | Hierarchy | Reusable | Mindmap Properties | Complexity |
|--------|----------|-----------|----------|--------------------|------------|
| 1 | `<map>` + `<topicref>` | Unlimited | Excellent | Limited (via topicmeta) | Low |
| 2 | `<topic>` + `<section>` | Unlimited | Poor | Limited | Low |
| 3 | Specialized `<mindmap>` | Unlimited | Medium | Excellent | Medium |
| 4 | `<map>` + `<topicmeta>` keywords | Unlimited | Good | Medium | Medium |

**Selected approach for DITA-OT pipeline:** Option 1 (`<map>` + `<topicref>`).
- Leverages standard DITA infrastructure
- Works with any existing DITA content without modification
- Benefits from DITA-OT preprocessing (conref resolution, key handling, navtitle extraction)
- No custom DTD or specialization required

**Complementary approach:** Option 3 (specialized `<mindmap>`) via standalone `mindmap2jsmind.xsl`
for direct XML-to-JSON transformation with richer node attributes (color, icon, url).
This is outside the DITA-OT pipeline.

---

## 12. JSON Output Format

### 12.1 DITA-OT Pipeline Output

jsMind `node_tree` JSON generated from standard DITA maps:

```json
{
  "meta": {
    "name": "Documentation Produit X"
  },
  "format": "node_tree",
  "data": {
    "id": "root",
    "topic": "Documentation Produit X",
    "expanded": true,
    "children": [
      {
        "id": "introduction",
        "topic": "Introduction",
        "expanded": true,
        "children": [
          {"id": "objectifs", "topic": "Objectifs", "expanded": false},
          {"id": "public", "topic": "Public cible", "expanded": false}
        ]
      },
      {
        "id": "installation",
        "topic": "Installation",
        "expanded": true,
        "children": [
          {"id": "prerequis", "topic": "Prerequis", "expanded": false},
          {"id": "etapes", "topic": "Etapes d installation", "expanded": false}
        ]
      },
      {"id": "faq", "topic": "FAQ", "expanded": false}
    ]
  }
}
```

### 12.2 Standalone `<mindmap>` Output

Adds extra properties per node:

```json
{
  "id": "objectifs",
  "topic": "Objectifs",
  "data": {"background-color": "#2ca02c"},
  "expanded": false,
  "url": "objectifs.dita"
}
```

---

## 13. Error Handling and Edge Cases

### 13.1 Input Edge Cases

| Scenario | Expected behavior |
|----------|-------------------|
| Empty map (no topicrefs) | HTML: renders root node only with map title. PDF: renders single root rectangle. |
| Map with no `<title>` and no `@title` | Falls back to `"Mindmap"` as root label. |
| Single topicref (no hierarchy) | Renders root + one child. PDF SVG adjusts canvas height to minimum 3 leaf slots. |
| Very deep nesting (10+ levels) | Works but PDF may become very wide. Scaling-to-fit compresses horizontally. |
| Topicref with no `@navtitle`, no `@href`, no `<topicmeta>` | Label defaults to `"Untitled"`. |
| Special characters in navtitle (`"`, `\`, `<`, `>`, `&`) | `"` and `\` are escaped in JSON. `<`, `>`, `&` are handled by XML serialization in HTML output. |
| Non-ASCII characters (accents, CJK, emoji) | Preserved via UTF-8 encoding throughout. Font availability in PDF depends on FOP configuration. |
| Duplicate `@id` values across topicrefs | `generate-id()` fallback produces unique IDs. Duplicates would cause jsMind issues. |

### 13.2 Runtime Error Scenarios

| Scenario | Behavior |
|----------|----------|
| DITA-OT preprocessing failure | Ant build fails at `preprocess` target. Error logged by DITA-OT. |
| Saxon XSLT error | Ant build fails at `.transform` target. Saxon reports line number. |
| FOP rendering failure | Ant build fails at `.render-pdf` target. Common cause: unsupported SVG features. |
| `org.dita.pdf2` not installed | Plugin installation fails (`<require>` dependency check). |
| Referenced topic file missing | DITA-OT preprocess logs a warning but continues. Topicref still appears as a node. |

---

## 14. Known Limitations

| Limitation | Impact | Workaround | Phase to address |
|------------|--------|------------|------------------|
| ~~`build.gradle.kts` type mismatch (`output()` requires String, not Provider)~~ | ~~Build script does not compile~~ | ~~Use `.get().asFile.absolutePath`~~ | ~~Phase 1~~ **RESOLVED** |
| ~~No node colors from DITA map input~~ | ~~Depth-based colors only~~ | ~~Use `<data name="mindmap-color">`~~ | ~~Phase 3~~ **RESOLVED** |
| ~~PDF text truncation at 20 characters~~ | ~~Long labels cut off~~ | ~~Use `mindmap.max.chars` parameter~~ | ~~Phase 3~~ **RESOLVED** |
| Single-page PDF only | Large maps (50+ leaves) get very small when scaled to fit | Use A3 page size | Phase 3 |
| ~~No `<topicgroup>` transparency~~ | ~~Creates a node~~ | ~~Add class-based exclusion~~ | ~~Phase 2~~ **RESOLVED** |
| ~~No `@processing-role="resource-only"` filtering~~ | ~~Keydefs may appear~~ | ~~Add attribute-based exclusion~~ | ~~Phase 2~~ **RESOLVED** |
| ~~No `@toc="no"` filtering~~ | ~~Hidden topicrefs still appear~~ | ~~Add attribute-based exclusion~~ | ~~Phase 2~~ **RESOLVED** |
| PDF font embedding | Non-Latin characters may render as boxes | Configure FOP fonts (fop.xconf) | Phase 3 |
| ~~No jsMind orientation control~~ | ~~Always `full` mode~~ | ~~Use `jsmind.mode` parameter~~ | ~~Phase 3~~ **RESOLVED** |
| ~~JSON control character escaping~~ | ~~Newlines/tabs not escaped~~ | ~~Add `mm:escape-json()` function~~ | ~~Phase 2~~ **RESOLVED** |

---

## 15. Accessibility

### 15.1 HTML Output

| Feature | Status | Notes |
|---------|--------|-------|
| Page language (`<html lang="en">`) | Implemented | Defaults to `en`. Should be parameterizable. |
| Page title (`<title>`) | Implemented | Uses map title. |
| Keyboard navigation | Partial | jsMind supports some keyboard shortcuts natively. |
| Screen reader support | Limited | jsMind renders to `<canvas>` which is not accessible. A text-based node list fallback should be considered. |
| Color contrast | Theme-dependent | `primary` theme has white text on blue, which passes WCAG AA. Other themes vary. |
| Print styles | Implemented | `@media print` CSS hides interactive controls. |

### 15.2 PDF Output

| Feature | Status | Notes |
|---------|--------|-------|
| Tagged PDF | Not implemented | FOP can generate tagged PDF with proper XSL-FO markup. Future improvement. |
| Text in SVG | Not selectable | SVG text inside FOP PDF is rendered as graphics. |
| Color contrast | Good | White text on colored backgrounds, minimum contrast varies by depth color. |

### 15.3 Planned Improvements (Phase 3+)

- Add `lang` parameter to set `<html lang>` attribute
- Add a `<noscript>` fallback with a text-based node list
- Investigate jsMind SVG rendering mode for better accessibility
- Add PDF bookmarks via `fo:bookmark-tree`

---

## 16. Performance

### 16.1 Expected Benchmarks

| Map size | Nodes | HTML generation | PDF generation |
|----------|-------|-----------------|----------------|
| Small | 5-20 | < 2s | < 5s |
| Medium | 20-100 | < 5s | < 15s |
| Large | 100-500 | < 10s | < 30s |
| Very large | 500+ | Untested | Untested |

*Times include DITA-OT preprocessing. Measured on modern hardware (8+ cores, SSD).*

### 16.2 Scaling Considerations

| Concern | Threshold | Mitigation |
|---------|-----------|------------|
| jsMind rendering | ~500 nodes | Browser may slow. Consider `jsmind.screenshot.js` for static view. |
| SVG canvas size | ~200 leaves | Canvas becomes very tall. FOP scaling reduces readability. |
| XSLT recursion | ~100 depth levels | Saxon stack depth. Unlikely in practice. |
| FOP memory | ~1000 SVG elements | Increase JVM heap (`-Xmx512m`) in FOP invocation. |
| JSON size | ~500 nodes | ~50 KB JSON embedded in HTML. No concern. |

---

## 17. Testing Strategy

### 17.1 Manual Test Cases

| ID | Test case | Input | Expected output | Phase |
|----|-----------|-------|-----------------|-------|
| T01 | Basic HTML generation | `sample.ditamap` (7 topicrefs) | HTML with jsMind rendering all nodes | Phase 1 |
| T02 | Basic PDF generation | `sample.ditamap` (7 topicrefs) | PDF with SVG tree, 7 nodes visible | Phase 1 |
| T03 | Empty map | Map with `<title>` only, no topicrefs | HTML/PDF with root node only | Phase 2 |
| T04 | Deep nesting | Map with 6 levels of nested topicrefs | All levels rendered, PDF scales | Phase 2 |
| T05 | Wide map | Map with 20 top-level topicrefs | Auto-collapse in HTML; PDF fits page | Phase 2 |
| T06 | Special characters | Navtitles with `"`, `&`, `<`, accents | Proper escaping in JSON and SVG | Phase 2 |
| T07 | Theme parameter | `jsmind.theme=danger` | HTML uses red theme | Phase 1 |
| T08 | Editable parameter | `jsmind.editable=true` | HTML allows node editing | Phase 1 |
| T09 | Page size parameter | `mindmap.page.size=A3-landscape` | PDF on A3 landscape | Phase 1 |
| T10 | Missing topic files | Topicrefs with broken `@href` | Builds with warnings, nodes still appear | Phase 2 |
| T11 | Conref resolution | Map with conrefs | Resolved content appears in mindmap | Phase 2 |
| T12 | Key-based navtitle | Map using `@keyref` with key definitions | Key-resolved titles appear as labels | Phase 2 |
| T13 | Offline HTML | Open generated HTML without internet | jsMind loads from local files | Phase 1 |
| T14 | `<topicgroup>` handling | Map with `<topicgroup>` container | Children promoted, no empty node | Phase 2 |
| T15 | `@processing-role="resource-only"` | Map with keydefs | Keydefs excluded from mindmap | Phase 2 |
| T16 | Cross-platform | Run on Linux/macOS | Same output as Windows | Phase 2 |

### 17.2 Automated Testing (Phase 3+)

- XSLT unit tests via XSpec (Saxon HE compatible)
- JSON schema validation for generated jsMind data
- SVG geometry assertions (node count, canvas dimensions)
- Gradle integration test: `./gradlew generateAll` exit code 0
- HTML validation: W3C HTML5 validator on output
- PDF validation: Apache PDFBox for structural checks

---

## 18. Troubleshooting

### 18.1 Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| `./gradlew` fails with "JAVA_HOME not set" | Java not in PATH | Install JDK 17+ and set `JAVA_HOME` |
| `downloadDitaOt` hangs | Network/proxy issue | Set `retries.set(5)` or configure proxy in `gradle.properties` |
| `installMindmapPlugin` fails with "plugin not found" | Wrong path | Verify `file("dita-ot-mindmap-plugin")` exists relative to project root |
| HTML output blank (no mindmap) | jsMind JS not loaded | Check browser console; verify `jsmind/jsmind.js` exists in output dir |
| PDF contains empty page | FOP SVG rendering error | Check Ant output for FOP warnings; simplify SVG if needed |
| Non-Latin characters as boxes in PDF | Missing fonts in FOP | Add font configuration to `fop.xconf` in pdf2 plugin |
| `build.gradle.kts` compilation error | Type mismatch on `output()` | Use `output(layout.buildDirectory.dir("...").get().asFile.absolutePath)` |
| Saxon error "XSLT 3.0 not supported" | Wrong XSLT factory | Verify `net.sf.saxon.TransformerFactoryImpl` in build.xml |
| "Cannot find class org.apache.fop.cli.Main" | FOP JARs not on classpath | Verify `<require plugin="org.dita.pdf2.fop"/>` in plugin.xml; use `${dita.plugin.org.dita.pdf2.fop.dir}/lib` in build.xml classpath |
| Gradle daemon memory error | Large project | Add `org.gradle.jvmargs=-Xmx1g` to `gradle.properties` |

### 18.2 Debug Commands

```bash
# Verify DITA-OT installation
./gradlew downloadDitaOt && ls build/dita-ot/dita-ot-4.4/bin/dita

# List installed plugins
build/dita-ot/dita-ot-4.4/bin/dita install --list

# Run with verbose DITA-OT logging
./gradlew generateMindmapHtml --info

# Check generated intermediate files
ls build/dita-ot/dita-ot-4.4/temp/   # Preprocessed map
ls build/output/mindmap-html/         # HTML output
ls build/output/mindmap-pdf/          # PDF output
```

---

## 19. Development Phases

### Phase 1: Core Foundation (MVP)

**Goal:** Working `mindmap-html` transtype + Gradle build pipeline.

| Task | Description | Status |
|------|-------------|--------|
| P1.1 | Fix `build.gradle.kts` type issues (`output()` String, `ditaOtDir` shadowing) | **Done** |
| P1.2 | Validate `./gradlew downloadDitaOt` downloads DITA-OT 4.4 | **Done** |
| P1.3 | Validate `./gradlew installMindmapPlugin` deploys plugin successfully (via Zip packaging) | **Done** |
| P1.4 | Validate `./gradlew generateMindmapHtml` produces working HTML | **Done** |
| P1.5 | Verify jsMind renders interactively in browser (Chrome, Firefox, Edge) | Manual |
| P1.6 | Verify offline mode (no CDN, all local files) | **Done** (local jsMind bundled) |
| P1.7 | Test `jsmind.theme` and `jsmind.editable` parameters | Manual |
| P1.8 | Verify Gradle wrapper works on clean machine (no pre-installed Gradle) | Manual |

**Exit criteria:** `./gradlew generateMindmapHtml` produces a working interactive HTML mindmap from `samples/sample.ditamap` with bundled jsMind assets.

### Phase 2: PDF Output + Robustness

**Goal:** Working `mindmap-pdf` transtype + handle DITA edge cases.

| Task | Description | Status |
|------|-------------|--------|
| P2.1 | Validate `./gradlew generateMindmapPdf` produces readable PDF | **Done** |
| P2.2 | Test all `mindmap.page.size` values (A4, A3, letter landscape) | Pending |
| P2.3 | Verify FOP classpath resolution from `org.dita.pdf2.fop` plugin | **Done** |
| P2.4 | Add `@processing-role="resource-only"` exclusion in both XSLTs | **Done** |
| P2.5 | Add `@toc="no"` exclusion in both XSLTs | **Done** |
| P2.6 | Handle `<topicgroup>` transparency (promote children, skip group node) | **Done** |
| P2.7 | Handle `<topichead>` (render as label-only node) | **Done** |
| P2.8 | Add JSON control character escaping (`\n`, `\t`, `\r`) via `mm:escape-json()` function | **Done** |
| P2.9 | Test with single-node map, deep nesting (4 levels), wide map (12 siblings) | **Done** |
| P2.10 | Test with conrefs and key-based navtitles | Pending |
| P2.11 | Test special characters in navtitles (quotes, ampersands, accents, CJK) | **Done** (via test-edge-cases.ditamap) |
| P2.12 | Add sample DITA maps for edge-case testing (`samples/test-*.ditamap`) | **Done** (3 test maps) |
| P2.13 | Verify cross-platform (Windows + at least one Unix) | Pending |

**Exit criteria:** `./gradlew generateAll` produces both HTML and PDF. Edge cases handled gracefully. All T01-T16 manual tests pass.

### Phase 3: Enhancements

**Goal:** Richer mindmap features, better PDF quality, accessibility.

| Task | Description | Priority |
|------|-------------|----------|
| P3.1 | Add `jsmind.mode` parameter (`full`, `side`) for orientation control | **Done** |
| P3.2 | Add `mindmap.lang` parameter for `<html lang>` attribute | **Done** |
| P3.3 | Support `<topicmeta>/<data name="mindmap-color">` for node colors in HTML and PDF | **Done** |
| P3.4 | `mindmap.max.chars` parameter for PDF label truncation (default: 20) | **Done** |
| P3.5 | Add `<noscript>` text fallback in HTML for accessibility | **Done** |
| P3.6 | Add PDF bookmarks via `fo:bookmark-tree` | **Done** |
| P3.7 | Screenshot export button in HTML (via `jsmind.screenshot.js`) | **Done** |
| P3.8 | FOP font configuration for non-Latin characters | Medium |
| P3.9 | Tagged PDF for accessibility | Low |
| P3.10 | Add more jsMind themes to `jsmind.theme` enum (orange, pumpkin, etc.) | Low |

### Phase 4: Scale and Automation

**Goal:** Handle large maps, automated testing, CI/CD.

| Task | Description | Priority |
|------|-------------|----------|
| P4.1 | Multi-page PDF for large maps (> 30 leaves): overview page + detail pages per branch | **Done** |
| P4.2 | XSpec unit tests for all 3 XSLT stylesheets | High |
| P4.3 | Gradle integration test task (`./gradlew integrationTest`) — 5 maps × 2 transtypes = 10 tests | **Done** |
| P4.4 | JSON schema validation in test pipeline | Medium |
| P4.5 | GitHub Actions CI workflow (`.github/workflows/ci.yml`) | **Done** |
| P4.6 | Performance benchmarks with 100/500/1000 node maps | Medium |
| P4.7 | SVG standalone output transtype (`mindmap-svg`) | Low |
| P4.8 | Plugin distribution packaging (ZIP for DITA-OT registry) | Low |
| P4.9 | Publish plugin to DITA-OT plugin registry | Low |
| P4.10 | Sample large DITA map generator script | Low |

### Phase Summary

| Phase | Focus | Key Deliverable |
|-------|-------|-----------------|
| **Phase 1** | Core Foundation | Working HTML mindmap from `./gradlew generateMindmapHtml` |
| **Phase 2** | PDF + Robustness | Working PDF + edge case handling for all DITA map structures |
| **Phase 3** | Enhancements | Richer styling, accessibility, orientation control |
| **Phase 4** | Scale + CI | Automated tests, large map support, CI/CD, distribution |
