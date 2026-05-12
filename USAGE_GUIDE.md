# BicepDiagrams - Manuel Complet

> **Convertissez vos fichiers Azure Bicep en diagrammes visuels clairs et professionnels!**

## Table des Matières

1. [Qu'est-ce que c'est?](#quest-ce-que-cest)
2. [Installation](#installation)
3. [Utilisation Rapide](#utilisation-rapide)
4. [Commandes Disponibles](#commandes-disponibles)
5. [Formats de Sortie](#formats-de-sortie)
6. [Corrections Récentes](#corrections-récentes)
7. [Troubleshooting](#troubleshooting)

##  Qu'est-ce que c'est?

BicepDiagrams est un outil qui convertit automatiquement nos fichiers **Azure Bicep** en **diagrammes visuels** en PNG, SVG, ou PDF. 

### Exemple
```bicep
resource myVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'myVnet'
  location: 'eastus'
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
  }
}

resource subnetA 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'subnetA'
  parent: myVnet
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}
```

**devient** `simple_vnet.png` avec le VNet et le Subnet visuellement représentés

## Installation

### Prérequis
- Python 3.8+
- Azure CLI avec Bicep support
- `pip` ou `pip3`

### Étapes

```bash
# 1. Aller au répertoire du projet
cd /home/gamal-daoud/Documents/BicepDiagrams

# 2. (Optionnel) Créer un environnement virtuel
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate  # Windows

# 3. Installer les dépendances
pip install -r requirements.txt
```

## ⚡ Utilisation Rapide

### Une seule commande pour compiler un fichier
```bash
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f png
```

### Compiler TOUS les fichiers Bicep
```bash
python3 compile_all.py
```

### Valider que tout fonctionne
```bash
python3 validate_fixes.py
```

## Commandes Disponibles

### Compiler un fichier spécifique
```bash
# PNG (défaut, 300 DPI)
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f png

# SVG (meilleurpour l'édition)
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f svg

# PDF
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f pdf
```

### Optimiser la qualité
```bash
# Haute qualité (600 DPI)
python3 bicep-diagrams.py input.bicep -o output --dpi 600 -f png

# Très haute qualité (1200 DPI)
python3 bicep-diagrams.py input.bicep -o output --dpi 1200 -f png
```

### Mode flat (sans clusters)
```bash
# Affiche tous les nœuds sans groupement
python3 bicep-diagrams.py input.bicep -o output --flat -f png
```

### Compiler plusieurs fichiers
```bash
python3 bicep-diagrams.py file1.bicep file2.bicep file3.bicep -o output
```

## Formats de Sortie

| Format | Extension | Usage | Avantages |
|--------|-----------|-------|-----------|
| **PNG** | `.png` | Visualisation rapide |Universel, visualisation directe |
| **SVG** | `.svg` | Édition / Web | Vecteur, scalable, éditable |
| **PDF** | `.pdf` | Impression / Documentation | Professionnel, imprimable |
| **DOT** | `.dot` | Graphviz natif |  Contrôle avancé |
| **D2** | `.d2` | Diagrams-as-code | Moderne, composable |
| **Mermaid** | `.mermaid` | GitHub/GitLab native | Intégration native |

## Corrections Récentes (v2.0)

###  Bugs Résolus
 **Subnets manquants** - Maintenant affichés correctement dans les VNets  
**YAML malformé** - Configuration valide et testée  
**Classes invalides** - Toutes les classes diagrams validées  

### Résultats
- 20/21 fichiers compilés avec succès (95.2%)
- Tous les nœuds affichés correctement
- Validation automatique des configurations

### Fichiers Modifiés
- `parser_engine.py` - Extraction correcte des parents subnet
- `bicep-diagrams.yaml` - Configuration validée et corrigée
- `compile_all.py` - Compilation en masse
- `validate_fixes.py` - Script de validation

## Exemples de Fichiers Disponibles

```bash
# Simples
sur cette racine :/Documents/BicepDiagrams
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f png

# Intermédiaires
python3 bicep-diagrams.py bicep-generator/input/storage.bicep -o storage -f png
python3 bicep-diagrams.py bicep-generator/input/db.bicep -o db -f png

# Complexes
python3 bicep-diagrams.py bicep-generator/input/wordpress_proper.bicep -o wordpress -f png
python3 bicep-diagrams.py bicep-generator/input/aws-to-azure.bicep -o aws-to-azure -f png


# Très complexes
python3 bicep-diagrams.py bicep-generator/input/network_custom.bicep -o network_custom -f png
python3 bicep-diagrams.py bicep-generator/input/test4.bicep -o test4 -f png


## Troubleshooting

# CORRECT
python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output -f png
```

## Erreur de compilation Bicep
```bash
# Vérifier que le fichier est syntaxiquement correct
az bicep build --file bicep-generator/input/simple_vnet.bicep --stdout
```

### Missing module 'diagrams'
```bash
# Réinstaller les dépendances
pip install diagrams pyyaml
```

### Graphviz non disponible
```bash
# Linux
sudo apt-get install graphviz

# macOS
brew install graphviz

# Windows
# Télécharger depuis: https://graphviz.org/download/
```

## Résultats Typiques

### Simple VNet
```
simple_vnet.png
    - 1 VNet
    - 1 Subnet
    - Cluster contenant le Subnet
```

### WordPress Full Stack
```
wordpress_proper.png
    - 1 VNet (cluster)
    - 2 NSG (clusters)
    - 1 VM
    - 1 MySQL
    - Dépendances entre ressources
```

##  Cas d'Usage

- **Documentation** - Générer automatiquement des diagrammes d'architecture
- **Reviews** - Visualiser rapidement l'impact des changements Bicep
- **Training** - Montrer à des collègues la structure d'une infrastructure
- **Audit** - Identifier les ressources et leurs dépendances
- **CI/CD** - Générer des diagrammes automatiquement à chaque commit

## Options Avancées

### Variables d'Environnement
```bash
# Définir un répertoire de sortie personnalisé
export BICEP_DIAGRAMS_OUTPUT=/custom/output/dir
python3 compile_all.py
```

### Styles Personnalisés
Éditer `bicep-diagrams.yaml` pour:
- Changer les couleurs des clusters
- Ajouter des icônes personnalisées
- Modifier les étyles des arêtes (edges)

### Configuration YAML
```yaml
styles:
  Network:
    bgcolor: "#f2e6ff"  # Couleur de fond
    color: "#000000"    # Couleur du texte
    label: "VNet"       # Label du cluster

resources:
  Microsoft.Network/virtualNetworks:
    kind: cluster       # Or: node
    style: Network      # Reference au style
    icon:
      classname: diagrams.azure.networking.VirtualNetworks
```

## Support

### Valider les corrections
```bash
python3 validate_fixes.py
```

### Voir les fichiers disponibles
```bash
bash USAGE.sh
```

## Statistiques

- **Fichiers disponibles**: 21
- **Taux de succès**: 95.2% (20/21)
- **Formats supportés**: 6 (PNG, SVG, PDF, DOT, D2, Mermaid)
- **Classes Azure**: 16+ mappées
- **DPI configurable**: 100-1200

## 🎓 Ressources

- [Documentation Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Diagrams.dev](https://diagrams.mingrammer.com/)
- [Graphviz](https://graphviz.org/)

## Licence

MIT
