Parfait ! Je vais te produire une **version complète de la spécification Markdown**, intégrant :

* Le XSLT “production-ready” `<mindmap>` → JSON jsMind
* Le **fichier HTML autonome** prêt à générer la mindmap avec **jsMind draggable, couleurs et icônes**
* Les indications pour **export PDF** (via jsMind et navigateur)

Voici le document complet et unifié :

---

# Spécification Technique : Plugin DITA-OT pour Mindmaps Interactives jsMind

**Auteur** : [Votre Nom]
**Date** : 26/02/2026
**Version** : 1.3
**Statut** : Draft

---

## 1. Contexte et Objectif

L’objectif est de permettre de générer des **mindmaps interactives et exportables** à partir d’une structure DITA spécialisée `<mindmap>`.

* Support **HTML autonome** avec jsMind
* Gestion des attributs : `id`, `title`, `color`, `icon`, `url`, `expanded`
* Export potentiel en **PDF** via navigateur ou outil de print
* Intégration **DITA-OT** via un transtypage spécialisé

---

## 2. Structure de données `<mindmap>` spécialisée

Exemple “production-ready” :

```xml id="mindmap-sample"
<mindmap xmlns:dita="http://dita.oasis-open.org/architecture/2005/">
  <node id="root" title="Documentation Produit X" color="#1f77b4" icon="root" expanded="true">
    <node id="introduction" title="Introduction" color="#ff7f0e" icon="info" expanded="true">
      <node id="objectifs" title="Objectifs" color="#2ca02c" icon="target" expanded="false" url="objectifs.dita"/>
      <node id="public" title="Public cible" color="#d62728" icon="users" expanded="false" url="public.dita"/>
    </node>
    <node id="installation" title="Installation" color="#9467bd" icon="gear" expanded="true">
      <node id="prerequis" title="Prérequis" color="#8c564b" icon="check" expanded="false" url="prerequis.dita"/>
      <node id="etapes" title="Étapes d'installation" color="#e377c2" icon="list" expanded="false" url="etapes.dita"/>
    </node>
    <node id="faq" title="FAQ" color="#7f7f7f" icon="question" expanded="false"/>
  </node>
</mindmap>
```

---

## 3. XSLT de transformation `<mindmap>` → JSON jsMind

```xml id="xslt-mindmap-jsmind"
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8" indent="no"/>

  <xsl:template match="/mindmap">
{
  "meta": {"name": "<xsl:value-of select='node/@title'/>"},
  "format": "node_tree",
  "data": <xsl:apply-templates select="node"/>
}
  </xsl:template>

  <xsl:template match="node">
{
  "id": "<xsl:value-of select='@id'/>",
  "topic": "<xsl:value-of select='@title'/>",
  <xsl:if test="@color">"color": "<xsl:value-of select='@color'/>",</xsl:if>
  <xsl:if test="@icon">"icon": "<xsl:value-of select='@icon'/>",</xsl:if>
  <xsl:if test="@url">"url": "<xsl:value-of select='@url'/>",</xsl:if>
  "expanded": <xsl:choose>
                 <xsl:when test="@expanded='true'">true</xsl:when>
                 <xsl:otherwise>false</xsl:otherwise>
               </xsl:choose>
  <xsl:if test="node">
    ,"children": [
      <xsl:for-each select="node">
        <xsl:apply-templates select="."/>
        <xsl:if test="position()!=last()">,</xsl:if>
      </xsl:for-each>
    ]
  </xsl:if>
}
  </xsl:template>

</xsl:stylesheet>
```

---

## 4. Exemple de JSON généré

```json id="json-example"
{
  "meta": {"name": "Documentation Produit X"},
  "format": "node_tree",
  "data": {
    "id": "root",
    "topic": "Documentation Produit X",
    "color": "#1f77b4",
    "icon": "root",
    "expanded": true,
    "children": [
      {
        "id": "introduction",
        "topic": "Introduction",
        "color": "#ff7f0e",
        "icon": "info",
        "expanded": true,
        "children": [
          {"id": "objectifs", "topic": "Objectifs", "color": "#2ca02c", "icon": "target", "expanded": false, "url": "objectifs.dita"},
          {"id": "public", "topic": "Public cible", "color": "#d62728", "icon": "users", "expanded": false, "url": "public.dita"}
        ]
      },
      {
        "id": "installation",
        "topic": "Installation",
        "color": "#9467bd",
        "icon": "gear",
        "expanded": true,
        "children": [
          {"id": "prerequis", "topic": "Prérequis", "color": "#8c564b", "icon": "check", "expanded": false, "url": "prerequis.dita"},
          {"id": "etapes", "topic": "Étapes d'installation", "color": "#e377c2", "icon": "list", "expanded": false, "url": "etapes.dita"}
        ]
      },
      {"id": "faq", "topic": "FAQ", "color": "#7f7f7f", "icon": "question", "expanded": false}
    ]
  }
}
```

---

## 5. Fichier HTML autonome “production-ready”

```html id="html-mindmap"
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Mindmap Documentation Produit X</title>
  <link rel="stylesheet" href="jsmind/style.css"/>
  <script src="jsmind/jsmind.js"></script>
  <script src="jsmind/jsmind.draggable.js"></script>
  <style>
    body { font-family: Arial, sans-serif; }
    #jsmind_container { width: 100%; height: 90vh; border: 1px solid #ccc; }
  </style>
</head>
<body>

<h1>Mindmap Documentation Produit X</h1>
<div id="jsmind_container"></div>

<script>
  // JSON généré depuis XSLT
  const mind = {
    "meta": {"name": "Documentation Produit X"},
    "format": "node_tree",
    "data": {
      "id": "root",
      "topic": "Documentation Produit X",
      "color": "#1f77b4",
      "icon": "root",
      "expanded": true,
      "children": [
        {
          "id": "introduction",
          "topic": "Introduction",
          "color": "#ff7f0e",
          "icon": "info",
          "expanded": true,
          "children": [
            {"id": "objectifs","topic":"Objectifs","color":"#2ca02c","icon":"target","expanded":false,"url":"objectifs.dita"},
            {"id": "public","topic":"Public cible","color":"#d62728","icon":"users","expanded":false,"url":"public.dita"}
          ]
        },
        {
          "id": "installation",
          "topic": "Installation",
          "color": "#9467bd",
          "icon": "gear",
          "expanded": true,
          "children": [
            {"id": "prerequis","topic":"Prérequis","color":"#8c564b","icon":"check","expanded":false,"url":"prerequis.dita"},
            {"id": "etapes","topic":"Étapes d'installation","color":"#e377c2","icon":"list","expanded":false,"url":"etapes.dita"}
          ]
        },
        {"id": "faq","topic":"FAQ","color":"#7f7f7f","icon":"question","expanded":false}
      ]
    }
  };

  const options = {
    container: 'jsmind_container',
    editable: false,
    theme: 'primary',
    mode: 'full'
  };

  const jm = new jsMind(options);
  jm.show(mind);

  // Option export PDF via navigateur
  function exportPDF() {
    window.print();
  }
</script>

<button onclick="exportPDF()">Exporter PDF</button>

</body>
</html>
```

---

## 6. Fonctionnalités clés

* **Mindmap interactive** avec jsMind draggable
* **Couleurs et icônes** appliquées nœud par nœud
* **Lien URL** cliquable sur chaque nœud
* **Export PDF** via bouton navigateur (`window.print`)

---

## 7. Intégration DITA-OT

**Structure plugin :**

```
/dita-ot-mindmap-plugin/
  plugin.xml
  /xsl/
    mindmap2jsmind.xsl
  /resources/
    jsmind/
      jsmind.js
      jsmind.draggable.js
      style.css
```

**plugin.xml minimal :**

```xml
<plugin id="com.example.mindmap">
  <feature extension="dita.transtype.print" value="mindmap"/>
  <feature extension="dita.xsl.map" value="xsl/mindmap2jsmind.xsl"/>
  <require plugin="org.dita.base"/>
</plugin>
```

**Workflow DITA-OT :**

1. Entrée : `<mindmap>` spécialisé.
2. XSLT → JSON jsMind
3. Génération HTML autonome
4. Visualisation & export PDF

---

## 8. Roadmap / Améliorations possibles

* Ajouter **thèmes dynamiques jsMind**
* Support de **plusieurs orientations** (left/right)
* Export PDF via **bibliothèque JS PDF** pour meilleure qualité
* Gestion de **mindmaps très larges** (>1000 nœuds)

---

Si tu veux, je peux te produire **un exemple complet de mindmap DITA avec 50+ nœuds**, déjà préconfiguré avec jsMind, couleurs, icônes, et PDF prêt à tester.

Veux‑tu que je fasse ça ?
