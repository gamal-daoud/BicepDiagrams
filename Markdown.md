# BicepDiagrams
*Projet développé par Gamal Daoud Youssouf.*


# Documentation de l'Outil Bicep Diagrams
Cet outil permet de générer automatiquement des diagrammes d'infrastructure Azure à partir de templates Bicep. Il utilise la bibliothèque Python `diagrams` et s'appuie sur le compilateur Bicep pour extraire les ressources et leurs dépendances.

##  Qu'est-ce que c'est bicep diagrams?
BicepDiagrams est un outil qui convertit automatiquement nos fichiers **Azure Bicep** en **diagrammes visuels** en PNG, SVG, ou PDF. 


## Structure du Projet

```
BicepDiagrams/
├── bicep-diagrams.py       => Script principal
├── parser_engine.py        => Parser ARM JSON
├── bicep-diagrams.yaml     => Configuration ressources
│
├── input/                  => Fichiers Bicep d'entrée
│   ├── simple_vnet.bicep
│   ├── storage.bicep
│   ├── wordpress_proper.bicep
│   └── ... (60 fichiers)
│
├── output/                 => Résultats générés
│   ├── *.png (Diagrammes)
│   └── *.json (Modèles ARM)
│
├── compile_all.py           => Compiler tous les fichiers
├── validate_fixes.py        => Valider l'installation
└── analyze_resources.py     => Analyser ressources
│
└── Configuration
    ├── requirements.txt
    └── venv/
```
## Le projet est divisé en deux composants principaux :

1.  **`parser_engine.py`** : 
    - Compile le fichier Bicep en JSON ARM via `bicep build`.
    - Analyse le JSON pour extraire les nœuds et les arêtes (dépendances).
    - Gère la hiérarchie (par exemple, les sous-réseaux à l'intérieur d'un réseau virtuel).

2.  **`bicep-diagrams.py`** :
    - Point d'entrée principal.
    - Charge la configuration YAML.
    - Utilise la hiérarchie extraite pour créer des `Clusters` et des `Nodes` via la bibliothèque `diagrams`.

##  Configuration (bicep-diagrams.yaml)
La correspondance entre les types de ressources Azure et les icônes du diagramme est définie dans le fichier `bicep-diagrams.yaml`.

### Structure d'une ressource
```yaml
Microsoft.Network/virtualNetworks:
  kind: cluster      # 'cluster' pour un groupe, 'node' pour une icône simple
  style: Network     # Style graphique défini dans la section 'styles'
  icon:
    classname: diagrams.azure.networking.VirtualNetworks
```


### Styles
Vous pouvez personnaliser les couleurs et les styles des clusters dans la section `styles` :
```yaml
styles:
  Network:
    bgcolor: "#f2e6ff"
```

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
python3 bicep-diagrams.py input/simple_vnet.bicep -o simple_vnet -f png
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
# PNG
python3 bicep-diagrams.py input/simple_vnet.bicep -o simple_vnet -f png

# SVG 
python3 bicep-diagrams.py input/simple_vnet.bicep -o simple_vnet -f svg

# PDF
python3 bicep-diagrams.py input/simple_vnet.bicep -o simple_vnet -f pdf
```

### Optimiser la qualité
```bash
python3 bicep-diagrams.py input.bicep -o output --dpi 600 -f png

# Très haute qualité
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

# Affiche un ARM json
bicep build input/network_custom.bicep --stdout > input/network_custom.json
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



## Exemples de Fichiers Disponibles

```bash
# Simples
sur cette racine :/Documents/BicepDiagrams
python3 bicep-diagrams.py input/simple_vnet.bicep -o simple_vnet -f png

# Intermédiaires
python3 bicep-diagrams.py input/storage.bicep -o storage -f png
python3 bicep-diagrams.py input/db.bicep -o db -f png

# Complexes
python3 bicep-diagrams.py input/wordpress_proper.bicep -o wordpress -f png
python3 bicep-diagrams.py input/aws-to-azure.bicep -o aws-to-azure -f png


# Très complexes
python3 bicep-diagrams.py input/network_custom.bicep -o network_custom -f png
python3 bicep-diagrams.py input/test4.bicep -o test4 -f png


## Erreur de compilation Bicep
```bash
# Vérifier que le fichier est syntaxiquement correct
bicep build input/simple_vnet.bicep --stdout
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

### Exécuter un test
```bash
python3 test_diagrams.py 
```


##  Ressources

- [Documentation Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Diagrams.dev](https://diagrams.mingrammer.com/)
- [Graphviz](https://graphviz.org/)

lien de projet
https://projets-info.univ-lille.fr/master/etu/projects/32a14b31-c537-44dc-ae4e-8156151000bb


lien de github:
 https://github.com/Azure/azure-quickstart-templates
tu trouveras de très nombreux exemples de templates Bicep et ARM JSON.


## Licence

MIT


## outil de génération de diagrammes d'architecture à partir de fichiers Bicep.
- 1 DiagramGPT / Eraser.io
il existe une version gratuite, mais limitée :

seulement quelques fichiers,
nombre limité de générations IA,
historique limité.



- 2 ARMVIZ

ARMVIZ
Gratuit
Pas besoin d’abonnement
Utilisable directement via navigateur

Fonctionne avec :
Bicep → ARM JSON → ARMVIZ

Très bien pour :

visualiser ressources Azure,
dépendances,
architecture ARM.

3. Lucidchart

    Plateforme de diagramme professionnel
    Support Azure avec formes officielles
    Collaboration en temps réel




Outils Identifiés :
1. ARMVIZ (http://armviz.io/ )

    Visualiseur web pour templates ARM JSON
    Affiche les ressources avec icônes Azure officielles
    Interface intuitive et gratuite

2. ARM Template Viewer (VS Code Extension)

    Extension officielle Microsoft pour VS Code
    Affiche aperçu graphique des templates ARM
    Icônes Azure officielles


3. ARM Template Visualizer (VS Code Extension - ytechie)

    Visualise les dépendances ARM comme un arbre
    Alternative populaire à ARMVIZ


4. Bicep Visualizer (VS Code Extension)

    Affichage graphique des ressources Bicep
    Intégré dans VS Code


6. Lucidchart

    Plateforme de diagramme professionnel
    Support Azure avec formes officielles
    Collaboration en temps réel
