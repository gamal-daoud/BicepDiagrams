#!/usr/bin/env python3
"""
Script pour compiler tous les fichiers Bicep en images PNG/SVG
"""

import os
import subprocess
import glob
from pathlib import Path
import json

DIRNAME = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(DIRNAME, "input")
OUTPUT_DIR = os.path.join(DIRNAME, "output")

def compile_all_biceps(output_format="png", output_dir=None):
    """Compile tous les fichiers .bicep"""
    if output_dir is None:
        output_dir = OUTPUT_DIR

    os.makedirs(output_dir, exist_ok=True)

    bicep_files = sorted(glob.glob(os.path.join(INPUT_DIR, "*.bicep")))
    print(f"Trouvé {len(bicep_files)} fichiers Bicep\n")

    results = {
        "success": [],
        "skipped": [],
        "errors": []
    }

    for bicep_file in bicep_files:
        filename = os.path.basename(bicep_file)
        basename = os.path.splitext(filename)[0]
        output_path = os.path.join(output_dir, basename)

        # Vérifier d'abord si le fichier Bicep est valide
        check_proc = subprocess.run(
            ['/usr/bin/env', 'az', 'bicep', 'build', '--file', bicep_file, '--stdout'],
            capture_output=True,
            text=True
        )

        if check_proc.returncode != 0:
            error_msg = check_proc.stderr.split('\n')[0] if check_proc.stderr else "Erreur de compilation"
            results["errors"].append({
                "file": filename,
                "error": error_msg
            })
            print(f"{filename}")
            continue

        # Compiler avec le script principal
        compile_proc = subprocess.run(
            ['python3', os.path.join(DIRNAME, 'bicep-diagrams.py'), bicep_file, '-o', output_path, '-f', output_format],
            capture_output=True,
            text=True
        )

        if compile_proc.returncode == 0:
            results["success"].append(filename)
            print(f"{filename}")
        else:
            error_msg = compile_proc.stderr.split('\n')[-2] if compile_proc.stderr else "Erreur inconnue"
            results["errors"].append({
                "file": filename,
                "error": error_msg
            })
            print(f"{filename}: {error_msg}")

    # Résumé
    print(f"\n{'='*50}")
    print(f"Succès:   {len(results['success'])} fichiers")
    print(f"Erreurs:  {len(results['errors'])} fichiers")
    print(f"{'='*50}\n")

    if results["errors"]:
        print("Erreurs détectées:")
        for error in results["errors"]:
            print(f"  - {error['file']}: {error['error']}")

    return results

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Compiler tous les fichiers Bicep")
    parser.add_argument("-f", "--format", default="png", choices=["png", "svg", "pdf"], help="Format de sortie")
    parser.add_argument("-o", "--output", help="Répertoire de sortie")

    args = parser.parse_args()

    compile_all_biceps(output_format=args.format, output_dir=args.output)

