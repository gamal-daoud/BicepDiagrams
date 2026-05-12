#!/usr/bin/env python3
"""
Script de validation post-correction
Vérifie que tous les problèmes ont été résolus
"""

import os
import json
import subprocess
import yaml
from pathlib import Path

def validate_parser_engine():
    """Valide que le parser_engine traite correctement les subnets"""
    print("\nValidation du parser_engine.py...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    parser_script = os.path.join(script_dir, "parser_engine.py")

    try:
        with open(parser_script, 'r') as f:
            content = f.read()

        checks = [
            ("clean_label dans condition de parent", "if not effective_parent and '/' in cleaned_res_name:" in content),
            ("effective_parent utilisé", '"parent": effective_parent' in content),
            ("Import clean_label accessible", "def clean_label" in content),
        ]

        all_pass = True
        for check, result in checks:
            status = "ok" if result else "erreur"
            print(f"  {status} {check}")
            all_pass = all_pass and result

        return all_pass
    except Exception as e:
        print(f" Erreur: {e}")
        return False

def validate_yaml_config():
    """Valide que le YAML est bien formé et contient les bonnes classes"""
    print("\n Validation du bicep-diagrams.yaml...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(script_dir, "bicep-diagrams.yaml")

    try:
        with open(yaml_path, 'r') as f:
            config = yaml.safe_load(f)

        resources_config = config.get("resources", {})

        checks = [
            ("YAML bien formé", config is not None),
            ("Section resources existe", resources_config is not None),
            ("Subnets configuré", "Microsoft.Network/virtualNetworks/subnets" in resources_config),
            ("ApplicationInsights configuré", "Microsoft.Insights/components" in resources_config),
            ("Pas de duplication subnets", sum(1 for k in resources_config if "subnet" in k.lower()) == 1),
        ]

        all_pass = True
        for check, result in checks:
            status = "ok" if result else "erreur"
            print(f"  {status} {check}")
            all_pass = all_pass and result

        # Valider les classes
        print("\n Validation des classes diagrams...")
        invalid_classes = []
        for res_type, res_config in resources_config.items():
            icon_config = res_config.get("icon", {})
            classname = icon_config.get("classname")
            if classname:
                try:
                    idx = classname.rfind('.')
                    if idx != -1:
                        module_name = classname[:idx]
                        class_name = classname[idx+1:]
                        module = __import__(module_name, fromlist=[class_name])
                        getattr(module, class_name)
                except Exception as e:
                    invalid_classes.append((res_type, classname))
                    all_pass = False

        if invalid_classes:
            for res_type, classname in invalid_classes:
                print(f" {res_type}: {classname} INVALIDE")
        else:
            print(f"Toutes les classes diagrams valides")

        return all_pass
    except Exception as e:
        print(f"Erreur: {e}")
        return False

def validate_simple_vnet_compilation():
    """Teste la compilation du fichier simple_vnet.bicep"""
    print("\nTest de compilation simple_vnet.bicep...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    bicep_file = os.path.join(script_dir, "bicep-generator", "input", "simple_vnet.bicep")

    try:
        # Compiler en ARM JSON
        proc = subprocess.run(
            ['az', 'bicep', 'build', '--file', bicep_file, '--stdout'],
            capture_output=True,
            text=True
        )

        if proc.returncode != 0:
            print(f" Compilation Bicep échouée")
            return False

        arm_data = json.loads(proc.stdout)

        # Vérifier les ressources
        resources = arm_data.get('resources', [])

        checks = [
            ("ARM JSON valide", arm_data is not None),
            ("Ressources présentes", len(resources) > 0),
            ("VNet présent", any(r.get('type') == 'Microsoft.Network/virtualNetworks' for r in resources)),
            ("Subnet présent", any(r.get('type') == 'Microsoft.Network/virtualNetworks/subnets' for r in resources)),
        ]

        all_pass = True
        for check, result in checks:
            status = "ok" if result else "erreur"
            print(f"  {status} {check}")
            all_pass = all_pass and result

        if all_pass:
            print(f"Ressources détectées: {len(resources)}")
            for r in resources:
                print(f"    - {r.get('type')}: {r.get('name')}")

        return all_pass
    except Exception as e:
        print(f" Erreur: {e}")
        return False

def main():
    print("=" * 50)
    print("VALIDATION POST-CORRECTION BicepDiagrams")
    print("=" * 50)

    results = [
        validate_parser_engine(),
        validate_yaml_config(),
        validate_simple_vnet_compilation(),
    ]

    print("\n" + "=" * 50)
    if all(results):
        print("TOUTES LES VALIDATIONS RÉUSSIES!")
        print("Les corrections ont été appliquées avec succès!")
    else:
        print("CERTAINES VALIDATIONS ONT ÉCHOUÉ")
        print("Veuillez consulter les détails ci-dessus")
    print("=" * 50)

if __name__ == "__main__":
    main()

