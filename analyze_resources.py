#!/usr/bin/env python3
"""
Script pour analyser quelles ressources devraient être affichées dans chaque PNG
"""

import json
import subprocess
from pathlib import Path
import sys
# from diagrams import Diagram
# from diagrams.azure.networking import Subnet


def analyze_bicep_file(bicep_path):
    """Analyse un fichier Bicep et retourne les ressources"""
    # Compiler en ARM JSON
    proc = subprocess.run(
        ['bicep', 'build', bicep_path, '--stdout'],
        capture_output=True,
        text=True
    )

    if proc.returncode != 0:
        print(f"Erreur compilation: {bicep_path}")
        return None

    try:
        arm_data = json.loads(proc.stdout)
    except:
        return None

    resources = arm_data.get('resources', [])

    # Analyser les ressources
    resource_types = {}
    for res in resources:
        res_type = res.get('type', 'unknown')
        res_name = res.get('name', 'unknown')

        if res_type not in resource_types:
            resource_types[res_type] = []
        resource_types[res_type].append(res_name)

    return resource_types

def main():
    bicep_dir = Path("/home/gamal-daoud/Documents/BicepDiagrams/input")
    bicep_files = sorted(bicep_dir.glob("*.bicep"))

    print("ANALYSE DES RESSOURCES PAR FICHIER BICEP")
    print("=" * 80)

    for bicep_file in bicep_files:
        filename = bicep_file.name
        resources = analyze_bicep_file(str(bicep_file))

        if not resources:
            print(f"\n{filename} - ERREUR")
            continue

        print(f"\n{filename}")
        print(f"   Total de ressources: {sum(len(v) for v in resources.values())}")

        for res_type, res_names in sorted(resources.items()):
            print(f"   • {res_type} ({len(res_names)})")
            for name in res_names[:2]:  # Afficher les 2 premiers
                clean_name = name.replace('[', '').replace(']', '')
                if len(clean_name) > 60:
                    clean_name = clean_name[:57] + "..."
                print(f"     - {clean_name}")
            if len(res_names) > 2:
                print(f"... et {len(res_names)-2} autre(s)")

if __name__ == "__main__":
    main()

