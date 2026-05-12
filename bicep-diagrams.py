#!/usr/bin/env python3

import argparse
import subprocess
import json
import importlib
import yaml
import os
import textwrap

try:
    import pygraphviz
    HAS_PYGRAPHVIZ = True
except ImportError:
    HAS_PYGRAPHVIZ = False

from diagrams import Diagram, Edge, Cluster
from parser_engine import extract_nodes_and_edges

DIRNAME = os.path.dirname(__file__)

SUPPORTED_OUTPUT_FORMATS = ("png", "svg", "pdf", "dot", "d2", "mermaid")
DEFAULT_OUTPUT_DPI = 300
DEFAULT_LABEL_WIDTH = 18

# 🔹 Charger dynamiquement une classe diagrams
def get_diagram_class(classname):
    if not classname:
        return None
    try:
        idx = classname.rfind('.')
        if idx != -1:
            module = importlib.import_module(classname[:idx])
            return getattr(module, classname[idx+1:])
            
    except Exception as e:
        print(f"[Warning] Impossible de charger {classname}: {e}")
    return None

# 🔹 Styles YAML
def compute_style(style_ref, styles_config):
    if isinstance(style_ref, str):
        return styles_config.get(style_ref, {})
    if isinstance(style_ref, dict):
        return style_ref
    return {}

def format_label(label, width=DEFAULT_LABEL_WIDTH):
    """Rend les labels longs lisibles dans les noeuds Graphviz a taille fixe."""
    if not isinstance(label, str):
        label = str(label)

    parts = label.split("/")
    wrapped_parts = []
    for idx, part in enumerate(parts):
        wrapped = textwrap.wrap(
            part,
            width=width,
            break_long_words=False,
            break_on_hyphens=True,
        )
        wrapped_parts.extend(wrapped or [part])
        if idx < len(parts) - 1:
            wrapped_parts[-1] = f"{wrapped_parts[-1]}/"

    return "\n".join(wrapped_parts)

# 🔹 Génération principale
def run_visualization(bicep_path, output_filename, output_format, dpi, use_clusters=True):
    print(f"[Info] Compiling {bicep_path}...")

    proc = subprocess.run(
        ['az', 'bicep', 'build', '--file', bicep_path, '--stdout'],
        capture_output=True,
        text=True
    )

    if proc.returncode != 0:
        print(f"[Error]\n{proc.stderr}")
        return

    try:
        arm_data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("[Error] Failed to parse ARM JSON output from Bicep compiler.")
        return

    nodes_data, edges_data = extract_nodes_and_edges(arm_data)

    # 🔹 YAML config
    config_path = os.path.join(DIRNAME, "bicep-diagrams.yaml")
    if not os.path.exists(config_path):
        print(f"[Error] Config file not found: {config_path}")
        return

    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    styles_config = config.get("styles", {})
    resources_config = config.get("resources", {})
    unsupported_config = resources_config.get("Unsupported Resource Type", {})

    # 🔹 Choix format réel
    if output_format in ["png", "svg", "pdf"]:
        actual_format = output_format
    else:
        actual_format = "dot"

    graph_attr = {
        "dpi": str(dpi),
        "splines": "curved",
    }

    with Diagram(
        f"Azure Infrastructure: {os.path.basename(bicep_path)}",
        filename=output_filename,
        show=False,
        direction="TB",
        outformat=actual_format,
        graph_attr=graph_attr
    ):
        drawn_nodes = {}
        
        # 🔹 Build hierarchy map
        hierarchy = {}
        for n in nodes_data:
            p = n.get('parent')
            if p not in hierarchy:
                hierarchy[p] = []
            hierarchy[p].append(n)

        # 🔹 Recursive drawing function
        def draw_recursive(parent_id):
            children = hierarchy.get(parent_id, [])
            for n in children:
                res_type = n['type']
                rconfig = resources_config.get(res_type, unsupported_config)
                
                # A resource is a cluster if YAML says so OR if it has children
                has_children = n['id'] in hierarchy
                is_cluster = use_clusters and (rconfig.get('kind') == 'cluster' or has_children)
                
                style = compute_style(rconfig.get("style", {}), styles_config)
                icon_config = rconfig.get("icon", {})
                classname = icon_config.get("classname")
                icon_path = icon_config.get("path")
                
                node_class = get_diagram_class(classname)
                
                if icon_path:
                    # Support pour les icônes personnalisées locales
                    # On résout le chemin par rapport au dossier du script/YAML
                    full_icon_path = os.path.join(DIRNAME, icon_path)
                    
                    # Si non trouvé, on cherche dans le sous-dossier bicep-generator (cas courant)
                    if not os.path.exists(full_icon_path):
                        alt_path = os.path.join(DIRNAME, "bicep-generator", icon_path)
                        if os.path.exists(alt_path):
                            full_icon_path = alt_path
                    
                    from diagrams.custom import Custom
                    def custom_node_wrapper(label, **kwargs):
                        return Custom(label, full_icon_path, **kwargs)
                    node_class = custom_node_wrapper
                elif not node_class:
                    from diagrams.generic.blank import Blank
                    if parent_id is None: # Only warn for top-level unknown resources to avoid noise
                        print(f"[Warning] Type inconnu: {res_type}")
                    node_class = Blank
                
                if is_cluster:
                    # Filter out non-Graphviz attributes for Cluster (bgcolor, color, etc are usually ok)
                    cluster_style = {k: v for k, v in style.items() if k in ['bgcolor', 'color', 'label', 'style']}
                    with Cluster(format_label(n['label'], width=24), graph_attr=cluster_style):
                        # Create the resource node itself inside the cluster
                        node_style = {k: v for k, v in style.items() if k != 'label'}
                        drawn_nodes[n['id']] = node_class(format_label(n['label']), **node_style)
                        if has_children:
                            draw_recursive(n['id'])
                else:
                    node_style = {k: v for k, v in style.items() if k != 'label'}
                    drawn_nodes[n['id']] = node_class(format_label(n['label']), **node_style)

        # 🔹 Start drawing from root
        draw_recursive(None)

        # 🔹 Draw edges
        edge_style = compute_style(styles_config.get("DependsOn", {}), styles_config)
        for parent, child in edges_data:
            # Resolve parent and child (handling full IDs or suffixes)
            parent_node = drawn_nodes.get(parent)
            if not parent_node:
                for nid in drawn_nodes:
                    if nid.endswith(f"/{parent}"):
                        parent_node = drawn_nodes[nid]
                        break
            
            child_node = drawn_nodes.get(child)
            if not child_node:
                for nid in drawn_nodes:
                    if nid.endswith(f"/{child}"):
                        child_node = drawn_nodes[nid]
                        break

            if parent_node and child_node:
                parent_node >> Edge(**edge_style) >> child_node

    generated_file = f"{output_filename}.{actual_format}"
    print(f"[OK] {generated_file} généré")

# 🔹 CLI
def main():
    parser = argparse.ArgumentParser(description="Bicep → Diagram CLI")

    parser.add_argument("filenames", nargs="+", help="Un ou plusieurs fichiers Bicep")
    parser.add_argument("-o", "--output", help="Préfixe ou nom du fichier de sortie")
    parser.add_argument("-f", "--format", default="png", help="png | svg | pdf | d2 | mermaid")
    parser.add_argument("--dpi", type=int, default=DEFAULT_OUTPUT_DPI, help="Résolution du rendu Graphviz pour PNG/PDF (défaut: 300)")
    parser.add_argument("--flat", action="store_true", help="Désactive les clusters pour un rendu proche d'ARM Viewer")

    args = parser.parse_args()

    if args.format not in SUPPORTED_OUTPUT_FORMATS:
        print(f"Format invalide. Options: {SUPPORTED_OUTPUT_FORMATS}")
        return

    if args.dpi <= 0:
        print("DPI invalide. Utilisez une valeur positive")
        return

    for filename in args.filenames:
        output_name = args.output
        if output_name is None:
            output_name = os.path.splitext(os.path.basename(filename))[0]
        elif len(args.filenames) > 1:
            # Si plusieurs fichiers et un output fourni, on suffixe
            output_name = f"{args.output}_{os.path.splitext(os.path.basename(filename))[0]}"
        
        run_visualization(filename, output_name, args.format, args.dpi, use_clusters=not args.flat)

if __name__ == "__main__":
    main()
