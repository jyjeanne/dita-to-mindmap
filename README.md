# DITA-OT Mindmap Plugin

A [DITA Open Toolkit](https://www.dita-ot.org/) plugin that transforms standard DITA maps into interactive mindmap visualizations. Generates three output formats: interactive HTML (via [jsMind](https://github.com/hizzgdev/jsmind)), PDF with SVG tree diagrams, and standalone SVG files.

## Features

- **mindmap-html** -- Interactive HTML mindmap powered by jsMind v0.9.1
  - Bilateral layout (branches split left/right) or side layout (right only)
  - 15 built-in color themes
  - Toolbar: expand/collapse, zoom, depth control, screenshot export, print
  - Draggable view with curved connectors
  - Custom node styling via DITA metadata (background-color, foreground-color, font-weight, leading-line-color)

- **mindmap-pdf** -- PDF document with embedded SVG tree diagram
  - Page sizes: A4, A3, A2, Letter (landscape)
  - Bilateral layout on A3/A2 for wide maps
  - Multi-page mode: overview + detail pages for maps with 30+ leaves
  - PDF bookmarks for navigation
  - FOP font auto-detection for non-Latin characters (CJK, Cyrillic, Arabic)

- **mindmap-svg** -- Standalone SVG mindmap diagram
  - Same layout engine as PDF (bilateral/unilateral)
  - Embeddable in web pages or documents

- **DITA-aware processing**
  - Filters `@processing-role="resource-only"` and `@toc="no"` nodes
  - Topicgroup transparency (children promoted to parent level)
  - Topichead support (label-only nodes)
  - Label fallback chain: `topicmeta/navtitle` > `@navtitle` > `@href` filename

## Requirements

- Java 17+
- DITA-OT 4.4+
- Gradle 8.5+ (wrapper included)

## Quick Start

### Install from release

```bash
dita install https://github.com/jyjeanne/dita-to-mindmap/releases/download/v1.0.0/com.github.jyjeanne.mindmap-1.0.0.zip
```

### Generate outputs

```bash
# Interactive HTML mindmap
dita -i your-map.ditamap -f mindmap-html

# PDF with SVG tree diagram
dita -i your-map.ditamap -f mindmap-pdf

# Standalone SVG
dita -i your-map.ditamap -f mindmap-svg
```

### Build from source

```bash
git clone https://github.com/jyjeanne/dita-to-mindmap.git
cd dita-to-mindmap

# Download DITA-OT, install plugin, generate all outputs
./gradlew generateAll

# Outputs in build/output/mindmap-html/, mindmap-pdf/, mindmap-svg/
```

## Parameters

### mindmap-html

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `jsmind.theme` | primary, warning, danger, success, info, greensea, nephritis, belizehole, wisteria, asphalt, orange, pumpkin, pomegranate, clouds, asbestos | primary | Color theme |
| `jsmind.editable` | true, false | false | Allow node editing |
| `jsmind.mode` | full, side | full | Layout mode (bilateral or right-only) |
| `mindmap.lang` | BCP 47 tag | en | HTML lang attribute |

### mindmap-pdf / mindmap-svg

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `mindmap.page.size` | A4-landscape, A3-landscape, A2-landscape, letter-landscape | A4-landscape | Page/layout size |
| `mindmap.max.chars` | integer | 20 | Max characters per node label |

### Example with parameters

```bash
dita -i map.ditamap -f mindmap-html \
  -Djsmind.theme=greensea \
  -Djsmind.mode=full \
  -Dmindmap.lang=fr

dita -i map.ditamap -f mindmap-pdf \
  -Dmindmap.page.size=A3-landscape \
  -Dmindmap.max.chars=25
```

## Custom Node Styling

Add DITA `<data>` elements inside `<topicmeta>` to style individual nodes:

```xml
<topicref href="topic.dita">
  <topicmeta>
    <navtitle>My Node</navtitle>
    <data name="mindmap-color" value="#e74c3c"/>
    <data name="mindmap-fg-color" value="#ffffff"/>
    <data name="mindmap-font-weight" value="bold"/>
    <data name="mindmap-line-color" value="#c0392b"/>
  </topicmeta>
</topicref>
```

## Project Structure

```
dita-to-mindmap/
├── dita-ot-mindmap-plugin/        # DITA-OT plugin (distributable)
│   ├── plugin.xml                 # Plugin descriptor (3 transtypes)
│   ├── build.xml                  # Ant targets for DITA-OT pipeline
│   ├── LICENSE                    # MIT License
│   ├── cfg/fop.xconf             # FOP font configuration
│   ├── xsl/
│   │   ├── map2mindmap-html.xsl  # DITA map -> HTML + jsMind
│   │   ├── map2mindmap-fo.xsl    # DITA map -> XSL-FO + SVG -> PDF
│   │   ├── map2mindmap-svg.xsl   # DITA map -> standalone SVG
│   │   └── mindmap2jsmind.xsl    # Custom <mindmap> XML -> jsMind JSON
│   └── resources/
│       ├── mindmap.css            # HTML mindmap styling
│       └── jsmind/                # jsMind v0.9.1 library (BSD 2-Clause)
├── samples/                       # Sample DITA maps and topics
│   ├── sample.ditamap             # Basic example (6 nodes)
│   ├── sample-mindmap.xml         # Custom XML format example
│   └── topics/                    # 7 sample .dita topic files
├── xspec/                         # XSLT unit test suites
│   ├── test-mindmap2jsmind.xsl    # 25 tests
│   ├── test-map2mindmap-html.xsl  # 25 tests
│   └── test-map2mindmap-fo.xsl   # 26 tests
├── schemas/
│   └── jsmind-node-tree.schema.json  # JSON Schema for jsMind format
├── build.gradle.kts               # Gradle build (download, install, test, dist)
├── settings.gradle.kts
├── gradle.properties              # pluginVersion=1.0.0
└── .github/workflows/
    ├── ci.yml                     # CI: unit tests + integration tests
    └── release.yml                # Release: build + publish on v* tag
```

## Testing

```bash
# XSLT unit tests (76 tests across 3 stylesheets)
./gradlew xsltUnitTest

# Integration tests (8 maps x 3 formats + 2 large-format PDFs = 26 tests)
./gradlew integrationTest

# Performance benchmarks (6 map sizes x 3 formats = 18 benchmarks)
./gradlew benchmark
```

### Test maps

| Map | Nodes | Purpose |
|-----|-------|---------|
| sample | 6 | Basic structure |
| test-single-node | 0 | Minimal / empty map |
| test-colors | 4 | Custom node colors |
| test-edge-cases | 10 | Topicgroup, topichead, toc=no, resource-only |
| test-wide-map | 12 | Wide shallow tree |
| test-30-nodes | 35 | Large map, multi-page PDF |
| test-bilateral | 36 | Bilateral layout (A3/A2) |
| test-large-map | 41 | Stress test |
| bench-100-nodes | ~100 | Performance benchmark |

## Building a Release

```bash
# Build distribution ZIP
./gradlew distPlugin

# Build with specific version
./gradlew distPlugin -PpluginVersion=1.2.0

# Output: build/dist/com.github.jyjeanne.mindmap-{version}.zip
```

Or push a tag to trigger automated release via GitHub Actions:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Standalone Mindmap XML

The plugin also includes `mindmap2jsmind.xsl` for transforming a custom `<mindmap>` XML format directly to jsMind JSON, without DITA-OT:

```bash
java -jar Saxon-HE.jar -s:mindmap.xml -xsl:mindmap2jsmind.xsl -o:output.json
```

Input format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mindmap xmlns:dita="http://dita.oasis-open.org/architecture/2005/">
  <node id="root" title="Root" color="#1f77b4" icon="root" expanded="true">
    <node id="child1" title="Child" color="#ff7f0e" icon="info" expanded="true">
      <node id="leaf1" title="Leaf" url="page.html" expanded="false"/>
    </node>
  </node>
</mindmap>
```

## Technical Details

- **XSLT 3.0** with Saxon HE 12.x (bundled in DITA-OT 4.4)
- **PDF rendering** via Apache FOP (bundled via `org.dita.pdf2.fop` plugin)
- **JSON generation** using string concatenation with proper escape handling (backslash, quotes, control chars, `<`, `/`)
- **Bilateral layout** algorithm: split branches ceil(n/2) right + rest left, with proportional vertical space allocation per leaf count
- **Adaptive node sizing**: effective node height computed from available space per leaf, clamped to [16px, 32px]

## License

MIT License -- see [LICENSE](dita-ot-mindmap-plugin/LICENSE).

This plugin bundles [jsMind](https://github.com/hizzgdev/jsmind) (BSD 2-Clause License).
