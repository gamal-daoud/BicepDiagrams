#!/bin/bash
#  COMMANDES RAPIDES - Copier/Coller
# Fichier: QUICK_COMMANDS.sh

echo "COMMANDES RAPIDES À COPIER/COLLER"
echo "======================================"
echo ""

echo "DÉMARRAGE RAPIDE (choisissez une):"
echo ""
echo "1️⃣  Voir les options disponibles:"
echo "   bash USAGE.sh"
echo ""

echo "2️⃣  Valider l'installation:"
echo "   python3 validate_fixes.py"
echo ""

echo "3️⃣  Compiler un fichier simple:"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f png"
echo ""

echo "4️⃣  Compiler un fichier complexe:"
echo "   python3 bicep-diagrams.py bicep-generator/input/wordpress_proper.bicep -o wordpress -f png"
echo ""

echo "5️⃣  Compiler TOUS les fichiers:"
echo "   python3 compile_all.py"
echo ""

echo "📖 DOCUMENTATION:"
echo ""
echo "1️⃣  INDEX (navigateur):"
echo "   cat INDEX.md"
echo ""

echo "2️⃣  Résumé des corrections:"
echo "   cat RESUME_CORRECTIONS.md"
echo ""

echo "3️⃣  Guide complet:"
echo "   cat USAGE_GUIDE.md"
echo ""

echo "4️⃣  Détails techniques:"
echo "   cat CORRECTIONS.md"
echo ""

echo "FORMATS DE SORTIE:"
echo ""

echo "PNG (défaut):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output -f png"
echo ""

echo "SVG (vecteur):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output -f svg"
echo ""

echo "PDF (impression):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output -f pdf"
echo ""

echo "OPTIONS AVANCÉES:"
echo ""

echo "Haute qualité (600 DPI):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output --dpi 600"
echo ""

echo "Très haute qualité (1200 DPI):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output --dpi 1200"
echo ""

echo "Sans clusters (flat mode):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o output --flat"
echo ""

echo "LISTER LES FICHIERS DISPONIBLES:"
echo ""
echo "   ls bicep-generator/input/*.bicep"
echo ""

echo "ALTERNATIVES (autres fichiers):"
echo ""
echo "Basis de données:"
echo "   python3 bicep-diagrams.py bicep-generator/input/db.bicep -o db -f png"
echo ""

echo "Stockage:"
echo "   python3 bicep-diagrams.py bicep-generator/input/storage.bicep -o storage -f png"
echo ""

echo "AWS vers Azure:"
echo "   python3 bicep-diagrams.py bicep-generator/input/aws-to-azure.bicep -o aws-to-azure -f png"
echo ""

echo "Réseau personnalisé:"
echo "   python3 bicep-diagrams.py bicep-generator/input/network_custom.bicep -o network_custom -f png"
echo ""

echo "======================================"
echo "Copiez n'importe quelle commande ci-dessus et exécutez-la!"
echo ""

