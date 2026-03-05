Parfait ! Je vais te fournir une **spécification complète au format Markdown** qui inclut **le XSLT “production-ready”** pour transformer un `<mindmap>` spécialisé DITA en JSON compatible jsMind. Le XSLT gère :

* Transformation **récursive** des `<node>` enfants
* Conversion `expanded="true|false"` en booléen JSON
* Intégration des attributs `color`, `icon`, `url`

Je vais structurer le Markdown comme un **document technique complet** prêt pour une équipe.

---

# Spécification Technique : Plugin DITA-OT pour Mindmaps Spécialisées avec jsMind

**Auteur** : [Votre Nom]
**Date** : 26/02/2026
**Version** : 1.2
**Statut** : Draft

---

## 1. Contexte et Objectif

Ce document décrit la conception et l’implémentation d’un plugin DITA-OT permettant de générer des **mindmaps interactives** à partir d’une structure DITA spécialisée `<mindmap>`. La sortie est **JSON compatible avec jsMind** (`node_tree` format).

**Objectifs :**

* Transformer `<mindmap>` → JSON jsMind
* Supporter attributs **color, icon, url, expanded**
* Gestion récursive des nœuds enfants
* Intégration dans un workflow DITA-OT standard

---

## 2. Structure de données `<mindmap>` spécialisée

Exemple de mindmap “production-ready” :

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

**Règles de mapping vers JSON jsMind :**

| Attribut DITA   | JSON jsMind        |
| --------------- | ------------------ |
| id              | id                 |
| title           | topic              |
| color           | color              |
| icon            | icon               |
| expanded        | expanded (booléen) |
| url             | url                |
| `<node>` enfant | children[]         |

---

## 3. XSLT de transformation `<mindmap>` → JSON jsMind

```xml id="xslt-mindmap-jsmind"
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8" indent="no"/>

  <!-- Template principal -->
  <xsl:template match="/mindmap">
{
  "meta": {"name": "<xsl:value-of select='node/@title'/>"},
  "format": "node_tree",
  "data": <xsl:apply-templates select="node"/>
}
  </xsl:template>

  <!-- Template pour chaque node -->
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

### ✅ Points clés du XSLT

1. **Récursivité** : chaque `<node>` applique le template sur ses enfants pour générer `children[]`.
2. **Conversion expanded** : `"true"` → `true`, tout autre valeur → `false`.
3. **Attributs jsMind inclus** : color, icon, url.
4. **Gestion des virgules** : via `position()!=last()` pour JSON valide.

---

## 4. Exemple JSON généré

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

## 5. Intégration dans DITA-OT

**Structure du plugin :**

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

---

## 6. Workflow

1. Entrée : fichier `<mindmap>` spécialisé.
2. Transformation XSLT → JSON jsMind.
3. Génération HTML avec jsMind intégré.
4. Sortie : mindmap interactive et autonome.

---

## 7. Prochaines étapes / Améliorations possibles

* Ajouter attributs supplémentaires : `shape`, `font-size`, `link-target`
* Supporter **plusieurs thèmes jsMind** paramétrables via DITA-OT
* Intégrer tests unitaires XSLT pour JSON valide
* Ajouter export PDF/PNG via jsMind

---

Si tu veux, je peux te produire **le fichier HTML complet “production-ready”** intégrant ce JSON jsMind avec jsMind draggable, couleurs et icônes prêtes à l’usage.

Veux‑tu que je fasse ça ?
