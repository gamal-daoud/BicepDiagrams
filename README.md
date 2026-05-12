# Bicep Diagrams

**Generate beautiful infrastructure diagrams from Azure Bicep templates**

---


## outil de génération de diagrammes d'architecture à partir de fichiers Bicep.
- diagram gpt
- 
-

## Overview

This project provides a **CLI tool** that compiles Azure Bicep files to ARM JSON, extracts resources and their dependencies, and renders an architecture diagram using the [diagrams](https://github.com/mingrammer/diagrams) library.

- **Dynamic clustering** – resources are automatically grouped (e.g., sub‑nets inside a virtual network).
- **Custom styling** – a YAML‑driven configuration lets you map resource types to icons, colors, and labels.
- **Multiple output formats** – PNG, SVG, PDF, D2, Mermaid, …
- **Zero‑runtime dependencies** – the tool runs in a virtual environment with a single `requirements.txt`.

---

## Installation

```bash
# Clone the repository
git clone https://github.com/your‑username/bicep-diagrams.git
cd bicep-diagrams

# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

> **Tip**: The script requires the Azure CLI (`az`) to be installed and authenticated so it can compile Bicep files.

---

## 🚀 Quick Start

```bash
# Generate a PNG diagram from a Bicep file
./bicep-diagrams.py path/to/template.bicep -o my_diagram -f png

# Generate a sharper PNG
./bicep-diagrams.py path/to/template.bicep -o my_diagram -f png --dpi 300

# Best display quality in browsers, reports, and VS Code previews
./bicep-diagrams.py path/to/template.bicep -o my_diagram -f svg

# Flat graph close to ARM Viewer / Bicep visualizer
./bicep-diagrams.py path/to/template.bicep -o my_diagram -f png --flat
```

The command compiles the Bicep file, parses the generated ARM JSON, and writes `my_diagram.png` in the current directory.
For screen display, prefer SVG because it stays sharp at every zoom level. Use PNG when you need a raster image, and keep `--dpi 300` or higher.

### Command‑line Options

| Option | Description |
|--------|-------------|
| `filename` | Path to the Bicep file (required) |
| `-o, --output` | Base name of the output file (defaults to the Bicep file name) |
| `-f, --format` | Output format – `png`, `svg`, `pdf`, `d2`, `mermaid` (default: `png`) |
| `--dpi` | PNG/PDF render resolution (default: `300`; use `600` for very large exports) |
| `--flat` | Disable clusters to get a graph closer to ARM Viewer / Bicep visualizer |
| `-h, --help` | Show help message |

---

## Configuration (`bicep-diagrams.yaml`)

The YAML file lets you map Azure resource types to diagram nodes, styles, and clusters. A minimal example:

```yaml
resources:
  Microsoft.Network/virtualNetworks:
    kind: cluster
    style:
      bgcolor: "#F0F8FF"
      label: "VNet"
    icon:
      classname: "diagrams.azure.network.VirtualNetwork"
styles:
  DependsOn:
    color: "#888"
    style: dotted
```

- **`kind: cluster`** – the resource will be rendered as a Graphviz cluster.
- **`icon.classname`** – fully‑qualified class name from the `diagrams` library.
- **`style`** – CSS‑like attributes passed to the node/cluster.

Add more entries to cover the Azure services you need.

---
---

## Testing

The repository includes a small test suite that validates the parser against a known Bicep sample.

```bash
pytest tests/
```

---

## ontributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/awesome‑feature`).
3. Run the tests (`pytest`).
4. Submit a pull request.

Please follow the existing code style (PEP 8) and include unit tests for new functionality.

---

## License

This project is licensed under the **MIT License** – see the `LICENSE` file for details.

---

## Contact

- **Author**: Gamal Daoud Youssouf
- **Supervisor**: Philippe Merle – [philippe.merle@univ-lille.fr](mailto:philippe.merle@univ-lille.fr)

/Documents/BicepDiagrams/bicep-generator$ ./venv/bin/python bicep-diagrams.py output/test2.bicep 

ou ici si fichiers exterieurs
 bicep-generator/network_custom.bicep

./venv/bin/python bicep-diagrams.py bicep-generator/network_custom.bicep

on peut Voir le résultat:
Documents/BicepDiagrams/bicep-generator$ xdg-open archi.png

ou on utilse l'outil(ARM Viewer):
Compiler Bicep en ARM JSON
exemple:
/Documents/BicepDiagrams/bicep-generator$ bicep build input/db.bicep --outfile output/db.json

Ouvrir le fichier JSON dans VS Code

Lancer ARM Viewer
Dans VS Code, une fois le fichier JSON ouvert :

  - Appuyez sur Ctrl+Shift+P
  - Tapez "ARM Viewer: Preview"
  - cliquez sur l'icône ARM Viewer dans la barre d'outils


lien de projet
https://projets-info.univ-lille.fr/master/etu/projects/32a14b31-c537-44dc-ae4e-8156151000bb


lien de github:
 https://github.com/Azure/azure-quickstart-templates
tu trouveras de très nombreux exemples de templates Bicep et ARM JSON.
