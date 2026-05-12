# Documentation de l'Outil Bicep Diagrams

Cet outil permet de générer automatiquement des diagrammes d'infrastructure Azure à partir de templates Bicep. Il utilise la bibliothèque Python `diagrams` et s'appuie sur le compilateur Bicep pour extraire les ressources et leurs dépendances.

## Prérequis

Avant d'utiliser l'outil, assurez-vous d'avoir installé les éléments suivants :

- **Azure CLI** avec l'extension Bicep :
  ```bash
  az bicep version
  ```
- **Graphviz** (requis par la bibliothèque `diagrams`) :
  ```bash
  sudo apt install graphviz
  ```
- **Python 3.8+**

## Installation

1. Clonez ce dépôt.
2. Créez et activez un environnement virtuel :
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Installez les dépendances :
   ```bash
   pip install diagrams PyYAML
   ```

## Utilisation

L'outil se lance via le script `bicep-diagrams.py`.

### Commande de base
```bash
python3 bicep-diagrams.py mon_fichier.bicep
```
Cela générera un fichier `mon_fichier.png`.

### Options disponibles
- `-o`, `--output` : Spécifier le nom du fichier de sortie (sans extension).
- `-f`, `--format` : Spécifier le format de sortie (`png`, `svg`, `pdf`). Par défaut : `png`.
- `--dpi` : Spécifier la résolution du rendu PNG/PDF. Par défaut : `192`; utilisez `300` pour une image plus nette.

### Exemple
```bash
python3 bicep-diagrams.py infrastructure.bicep -o architecture_v1 -f svg
```

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

##  Architecture du Projet

Le projet est divisé en deux composants principaux :

1.  **`parser_engine.py`** : 
    - Compile le fichier Bicep en JSON ARM via `az bicep build`.
    - Analyse le JSON pour extraire les nœuds et les arêtes (dépendances).
    - Gère la hiérarchie (par exemple, les sous-réseaux à l'intérieur d'un réseau virtuel).

2.  **`bicep-diagrams.py`** :
    - Point d'entrée principal.
    - Charge la configuration YAML.
    - Utilise la hiérarchie extraite pour créer des `Clusters` et des `Nodes` via la bibliothèque `diagrams`.

##  Fichiers du Projet

- `bicep-diagrams.py` : Script principal.
- `parser_engine.py` : Moteur d'extraction et de compilation.
- `bicep-diagrams.yaml` : Fichier de mapping des ressources.
- `requirements.txt` : Liste des dépendances Python.
- `README.md` : Description académique du projet.
- `DOCUMENTATION.md` : Ce fichier.

---
*Projet développé par Gamal Daoud Youssouf.*
