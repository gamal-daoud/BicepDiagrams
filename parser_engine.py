import json
import re

def clean_label(raw_name):
    """Nettoie les fonctions ARM pour ne garder que le nom lisible."""
    # Si le nom contient une fonction format(...)
    if "format('" in raw_name:
        # On extrait ce qui est entre les premiers guillemets simples
        match = re.search(r"'([^']*)'", raw_name)
        if match:
            return f"{match.group(1)}..."
    
    # Nettoyage standard (enlève les crochets et prend la fin du chemin)
    clean = raw_name.split('/')[-1].replace("'", "").replace("]", "")
    return clean

def extract_nodes_and_edges(arm_json_content):
    resources = arm_json_content.get('resources', [])
    nodes = []
    edges = []

    for res in resources:
        res_name = res['name']
        res_type = res['type']
        # On utilise clean_label pour le texte qui s'affichera sous l'icône
        display_label = clean_label(res_name)
        
        nodes.append({
            "id": res_name,
            "type": res_type,
            "label": display_label 
        })

        dependencies = res.get('dependsOn', [])
        for dep in dependencies:
            parent_id = dep.split("'")[-2] if "'" in dep else dep.split("/")[-1]
            edges.append((parent_id, res_name))

    return nodes, edges