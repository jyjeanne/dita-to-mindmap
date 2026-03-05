import com.github.jyjeanne.DitaOtDownloadTask
import com.github.jyjeanne.DitaOtInstallPluginTask
import com.github.jyjeanne.DitaOtTask

plugins {
    id("io.github.jyjeanne.dita-ot-gradle") version "2.8.5"
}

val pluginVersion = project.findProperty("pluginVersion") as String? ?: "1.0.0"
val ditaOtVersion = "4.4"
val ditaOtPath = layout.buildDirectory.dir("dita-ot/dita-ot-$ditaOtVersion")

// ================================================================
// Download DITA-OT 4.4
// ================================================================
tasks.register<DitaOtDownloadTask>("downloadDitaOt") {
    version.set(ditaOtVersion)
}

// ================================================================
// Package the mindmap plugin as a ZIP (required by dita install)
// ================================================================
tasks.register<Zip>("packageMindmapPlugin") {
    from("dita-ot-mindmap-plugin")
    archiveFileName.set("com.github.jyjeanne.mindmap.zip")
    destinationDirectory.set(layout.buildDirectory.dir("plugin-zip"))
}

// ================================================================
// Install the mindmap plugin into DITA-OT
// ================================================================
tasks.register<DitaOtInstallPluginTask>("installMindmapPlugin") {
    dependsOn("downloadDitaOt", "packageMindmapPlugin")
    ditaOtDir.set(ditaOtPath)
    plugins.set(listOf(layout.buildDirectory.file("plugin-zip/com.github.jyjeanne.mindmap.zip").get().asFile.absolutePath))
    force.set(true)
}

// ================================================================
// Generate interactive HTML mindmap from sample DITA map
// ================================================================
tasks.register<DitaOtTask>("generateMindmapHtml") {
    dependsOn("installMindmapPlugin")
    ditaOt(ditaOtPath)
    input(file("samples/sample.ditamap"))
    output(layout.buildDirectory.dir("output/mindmap-html").get().asFile.absolutePath)
    transtype("mindmap-html")

    properties {
        property(name = "jsmind.theme", value = "primary")
        property(name = "jsmind.editable", value = "false")
        property(name = "jsmind.mode", value = "full")
        property(name = "mindmap.lang", value = "en")
    }
}

// ================================================================
// Generate PDF with mindmap diagram from sample DITA map
// ================================================================
tasks.register<DitaOtTask>("generateMindmapPdf") {
    dependsOn("installMindmapPlugin")
    ditaOt(ditaOtPath)
    input(file("samples/sample.ditamap"))
    output(layout.buildDirectory.dir("output/mindmap-pdf").get().asFile.absolutePath)
    transtype("mindmap-pdf")

    properties {
        property(name = "mindmap.page.size", value = "A4-landscape")
    }
}

// ================================================================
// Generate standalone SVG mindmap from sample DITA map
// ================================================================
tasks.register<DitaOtTask>("generateMindmapSvg") {
    dependsOn("installMindmapPlugin")
    ditaOt(ditaOtPath)
    input(file("samples/sample.ditamap"))
    output(layout.buildDirectory.dir("output/mindmap-svg").get().asFile.absolutePath)
    transtype("mindmap-svg")
}

// ================================================================
// Convenience: generate all outputs
// ================================================================
tasks.register("generateAll") {
    dependsOn("generateMindmapHtml", "generateMindmapPdf", "generateMindmapSvg")
    group = "DITA"
    description = "Generate HTML, PDF, and SVG mindmap outputs"
}

// ================================================================
// Integration tests: run all test-*.ditamap through both transtypes
// and validate the outputs.
// ================================================================
val testMaps = listOf("sample", "test-edge-cases", "test-wide-map", "test-single-node", "test-colors", "test-large-map", "test-30-nodes", "test-bilateral")

testMaps.forEach { mapName ->
    tasks.register<DitaOtTask>("test-${mapName}-html") {
        dependsOn("installMindmapPlugin")
        ditaOt(ditaOtPath)
        input(file("samples/${mapName}.ditamap"))
        output(layout.buildDirectory.dir("test-output/${mapName}-html").get().asFile.absolutePath)
        transtype("mindmap-html")
    }
    tasks.register<DitaOtTask>("test-${mapName}-pdf") {
        dependsOn("installMindmapPlugin")
        ditaOt(ditaOtPath)
        input(file("samples/${mapName}.ditamap"))
        output(layout.buildDirectory.dir("test-output/${mapName}-pdf").get().asFile.absolutePath)
        transtype("mindmap-pdf")
    }
    tasks.register<DitaOtTask>("test-${mapName}-svg") {
        dependsOn("installMindmapPlugin")
        ditaOt(ditaOtPath)
        input(file("samples/${mapName}.ditamap"))
        output(layout.buildDirectory.dir("test-output/${mapName}-svg").get().asFile.absolutePath)
        transtype("mindmap-svg")
    }
}

// ================================================================
// Large format tests: 30-node map on A3 and A2 paper sizes
// ================================================================
tasks.register<DitaOtTask>("test-30-nodes-A3") {
    dependsOn("installMindmapPlugin")
    ditaOt(ditaOtPath)
    input(file("samples/test-30-nodes.ditamap"))
    output(layout.buildDirectory.dir("test-output/test-30-nodes-A3").get().asFile.absolutePath)
    transtype("mindmap-pdf")
    properties {
        property(name = "mindmap.page.size", value = "A3-landscape")
    }
}

tasks.register<DitaOtTask>("test-30-nodes-A2") {
    dependsOn("installMindmapPlugin")
    ditaOt(ditaOtPath)
    input(file("samples/test-30-nodes.ditamap"))
    output(layout.buildDirectory.dir("test-output/test-30-nodes-A2").get().asFile.absolutePath)
    transtype("mindmap-pdf")
    properties {
        property(name = "mindmap.page.size", value = "A2-landscape")
    }
}

// ================================================================
// XSLT unit tests: run Saxon-based tests for all 3 stylesheets
// ================================================================
val saxonClasspath = fileTree(ditaOtPath.map { it.dir("lib") }) {
    include("Saxon-HE-*.jar", "xmlresolver-*.jar")
}

listOf("mindmap2jsmind", "map2mindmap-html", "map2mindmap-fo").forEach { name ->
    tasks.register<JavaExec>("xsltTest-$name") {
        dependsOn("downloadDitaOt")
        group = "Verification"
        description = "Run XSLT unit tests for $name"
        classpath = saxonClasspath
        mainClass.set("net.sf.saxon.Transform")
        args("-xsl:${file("xspec/test-$name.xsl")}", "-it:run-tests")
    }
}

tasks.register("xsltUnitTest") {
    dependsOn("xsltTest-mindmap2jsmind", "xsltTest-map2mindmap-html", "xsltTest-map2mindmap-fo")
    group = "Verification"
    description = "Run all XSLT unit tests"
}

tasks.register("integrationTest") {
    group = "Verification"
    description = "Run all test maps through both transtypes and validate outputs"

    // Depend on all test generation tasks
    testMaps.forEach { mapName ->
        dependsOn("test-${mapName}-html", "test-${mapName}-pdf", "test-${mapName}-svg")
    }
    // Large format tests
    dependsOn("test-30-nodes-A3", "test-30-nodes-A2")

    doLast {
        val testOutputDir = layout.buildDirectory.dir("test-output").get().asFile
        var passed = 0
        var failed = 0
        val failures = mutableListOf<String>()

        testMaps.forEach { mapName ->
            // Validate HTML output
            val htmlDir = File(testOutputDir, "${mapName}-html")
            val htmlFile = File(htmlDir, "${mapName}.html")
            if (htmlFile.exists() && htmlFile.length() > 0) {
                val html = htmlFile.readText()
                val checks = mutableListOf<String>()

                // Check essential HTML structure
                if (!html.contains("jsmind_container")) checks.add("missing jsmind_container div")
                if (!html.contains("\"format\": \"node_tree\"")) checks.add("missing node_tree format")
                if (!html.contains("\"id\": \"root\"")) checks.add("missing root node id")
                if (!html.contains("jsMind(options)")) checks.add("missing jsMind initialization")
                if (!html.contains("jsmind/jsmind.js")) checks.add("missing jsmind.js reference")
                if (!html.contains("<noscript>")) checks.add("missing noscript fallback")
                if (!html.contains("exportScreenshot")) checks.add("missing screenshot function")

                // JSON schema validation: extract JSON from HTML and validate structure
                val jsonMatch = Regex("""var mind = (\{[\s\S]*\});\s*var options""").find(html)
                if (jsonMatch != null) {
                    val json = jsonMatch.groupValues[1]
                    // Validate required top-level properties
                    if (!json.contains("\"meta\"")) checks.add("JSON: missing meta")
                    if (!json.contains("\"format\": \"node_tree\"")) checks.add("JSON: missing format")
                    if (!json.contains("\"data\"")) checks.add("JSON: missing data")
                    // Validate root node structure
                    if (!json.contains("\"id\": \"root\"")) checks.add("JSON: missing root id")
                    if (!json.contains("\"topic\"")) checks.add("JSON: missing topic")
                    if (!json.contains("\"expanded\"")) checks.add("JSON: missing expanded")
                    // Validate no malformed JSON (unescaped control chars)
                    val rawJsonLines = json.split("\n")
                    for ((lineNum, line) in rawJsonLines.withIndex()) {
                        // Check for unescaped tabs/control chars inside string values
                        if (line.contains("\t") && !line.contains("\\t")) {
                            checks.add("JSON: unescaped tab on line $lineNum")
                            break
                        }
                    }
                } else {
                    checks.add("JSON: could not extract jsMind data from HTML")
                }

                if (checks.isEmpty()) {
                    passed++
                    println("  PASS: ${mapName} HTML + JSON")
                } else {
                    failed++
                    val msg = "${mapName} HTML: ${checks.joinToString(", ")}"
                    failures.add(msg)
                    println("  FAIL: $msg")
                }
            } else {
                failed++
                val msg = "${mapName} HTML: output file missing or empty"
                failures.add(msg)
                println("  FAIL: $msg")
            }

            // Validate PDF output
            val pdfDir = File(testOutputDir, "${mapName}-pdf")
            val pdfFile = File(pdfDir, "${mapName}.pdf")
            if (pdfFile.exists() && pdfFile.length() > 100) {
                val header = pdfFile.readBytes().take(5).toByteArray().toString(Charsets.ISO_8859_1)
                if (header.startsWith("%PDF-")) {
                    passed++
                    println("  PASS: ${mapName} PDF (${pdfFile.length()} bytes)")
                } else {
                    failed++
                    val msg = "${mapName} PDF: invalid PDF header"
                    failures.add(msg)
                    println("  FAIL: $msg")
                }
            } else {
                failed++
                val msg = "${mapName} PDF: output file missing or too small"
                failures.add(msg)
                println("  FAIL: $msg")
            }

            // Validate SVG output
            val svgDir = File(testOutputDir, "${mapName}-svg")
            val svgFile = File(svgDir, "${mapName}.svg")
            if (svgFile.exists() && svgFile.length() > 100) {
                val svg = svgFile.readText()
                val svgChecks = mutableListOf<String>()
                if (!svg.contains("<svg:svg") && !svg.contains("<svg ")) svgChecks.add("missing svg root element")
                if (!svg.contains("viewBox")) svgChecks.add("missing viewBox attribute")
                if (!svg.contains("<svg:rect") && !svg.contains("<rect")) svgChecks.add("missing rect elements")
                if (!svg.contains("<svg:text") && !svg.contains("<text")) svgChecks.add("missing text elements")

                if (svgChecks.isEmpty()) {
                    passed++
                    println("  PASS: ${mapName} SVG (${svgFile.length()} bytes)")
                } else {
                    failed++
                    val msg = "${mapName} SVG: ${svgChecks.joinToString(", ")}"
                    failures.add(msg)
                    println("  FAIL: $msg")
                }
            } else {
                failed++
                val msg = "${mapName} SVG: output file missing or too small"
                failures.add(msg)
                println("  FAIL: $msg")
            }
        }

        // Validate large format PDF outputs (A3, A2)
        listOf("A3", "A2").forEach { format ->
            val pdfDir = File(testOutputDir, "test-30-nodes-$format")
            val pdfFile = File(pdfDir, "test-30-nodes.pdf")
            if (pdfFile.exists() && pdfFile.length() > 100) {
                val header = pdfFile.readBytes().take(5).toByteArray().toString(Charsets.ISO_8859_1)
                if (header.startsWith("%PDF-")) {
                    passed++
                    println("  PASS: test-30-nodes $format (${pdfFile.length()} bytes)")
                } else {
                    failed++
                    val msg = "test-30-nodes $format: invalid PDF header"
                    failures.add(msg)
                    println("  FAIL: $msg")
                }
            } else {
                failed++
                val msg = "test-30-nodes $format: output file missing or too small"
                failures.add(msg)
                println("  FAIL: $msg")
            }
        }

        println("\n${"=".repeat(50)}")
        println("Integration Test Results: $passed passed, $failed failed")
        println("${"=".repeat(50)}")

        if (failures.isNotEmpty()) {
            throw GradleException("Integration tests failed:\n${failures.joinToString("\n") { "  - $it" }}")
        }
    }
}

// ================================================================
// Performance benchmarks: measure transformation times
// ================================================================
val benchMaps = mapOf(
    "single-node" to "test-single-node",    // 0 topicrefs
    "small-6" to "sample",                   // 6 topicrefs
    "medium-12" to "test-wide-map",          // 12 topicrefs
    "large-35" to "test-30-nodes",           // 35 topicrefs
    "xlarge-41" to "test-large-map",         // 41 topicrefs
    "xxlarge-100" to "bench-100-nodes"       // ~100 topicrefs
)

benchMaps.forEach { (benchName, mapName) ->
    listOf("html", "pdf", "svg").forEach { format ->
        tasks.register<DitaOtTask>("bench-${benchName}-${format}") {
            dependsOn("installMindmapPlugin")
            ditaOt(ditaOtPath)
            input(file("samples/${mapName}.ditamap"))
            output(layout.buildDirectory.dir("bench-output/${benchName}-${format}").get().asFile.absolutePath)
            transtype("mindmap-${format}")
        }
    }
}

tasks.register("benchmark") {
    group = "Verification"
    description = "Run performance benchmarks across different map sizes and transtypes"

    benchMaps.keys.forEach { benchName ->
        listOf("html", "pdf", "svg").forEach { format ->
            dependsOn("bench-${benchName}-${format}")
        }
    }

    doLast {
        println("\n${"=".repeat(60)}")
        println("Performance Benchmark Results")
        println("${"=".repeat(60)}")

        val benchOutputDir = layout.buildDirectory.dir("bench-output").get().asFile
        val results = mutableListOf<String>()

        benchMaps.forEach { (benchName, _) ->
            listOf("html", "pdf", "svg").forEach { format ->
                val dir = File(benchOutputDir, "${benchName}-${format}")
                val ext = when (format) { "pdf" -> "pdf"; "svg" -> "svg"; else -> "html" }
                val outFile = dir.listFiles()?.firstOrNull { it.extension == ext }
                val size = outFile?.length() ?: 0
                val sizeKb = String.format("%.1f", size / 1024.0)
                results.add("  ${benchName.padEnd(15)} ${format.padEnd(5)} ${sizeKb.padStart(8)} KB")
            }
        }

        results.forEach { println(it) }
        println("${"=".repeat(60)}")
        println("Note: DITA-OT preprocessing dominates; XSLT transform is a fraction of total time.")
        println("Use --info flag to see per-task timing from Gradle.")
    }
}

// ================================================================
// Distribution: create release ZIP for dita install / registry
// ================================================================
tasks.register<Zip>("distPlugin") {
    group = "Distribution"
    description = "Package the mindmap plugin as a distributable ZIP for dita install"

    from("dita-ot-mindmap-plugin")
    archiveBaseName.set("com.github.jyjeanne.mindmap")
    archiveVersion.set(pluginVersion)
    destinationDirectory.set(layout.buildDirectory.dir("dist"))

    doLast {
        println("Distribution ZIP: ${archiveFile.get().asFile.absolutePath}")
        println("Install with: dita install ${archiveFile.get().asFile.absolutePath}")
    }
}
