#!/bin/bash
# Guide d'utilisation - BicepDiagrams
# Script d'exemples pour compiler les fichiers Bicep

echo "GUIDE D'UTILISATION - BicepDiagrams"
echo "======================================="
echo ""

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "bicep-diagrams.py" ]; then
    echo "Erreur: Veuillez exécuter ce script depuis le répertoire /home/gamal-daoud/Documents/BicepDiagrams"
    exit 1
fi

echo "Répertoire correct détecté"
echo ""

# Afficher les options disponibles
echo "EXEMPLES D'UTILISATION:"
echo ""
echo "1️Compiler un seul fichier Bicep (simple_vnet):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f png"
echo ""

echo "2️⃣ Compiler tous les fichiers Bicep en masse:"
echo "   python3 compile_all.py"
echo ""

echo "3️⃣ Compiler en SVG (meilleur pour l'édition):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet -f svg"
echo ""

echo "4️⃣ Compiler en haute qualité (600 DPI):"
echo "   python3 bicep-diagrams.py bicep-generator/input/simple_vnet.bicep -o simple_vnet_hq --dpi 600"
echo ""

echo "5️⃣ Valider que tout fonctionne correctement:"
echo "   python3 validate_fixes.py"
echo ""

echo " FICHIERS BICEP DISPONIBLES:"
echo ""
ls bicep-generator/input/*.bicep | sed 's|bicep-generator/input/||' | sed 's|.bicep||' | nl | awk '{print "   " $1". " $2}'
echo ""

echo " EXEMPLE COMPLET:"
echo "   cd /home/gamal-daoud/Documents/BicepDiagrams"
echo "   python3 bicep-diagrams.py bicep-generator/input/wordpress_proper.bicep -o wordpress -f png"
echo ""

echo "FICHIERS DE SORTIE:"
echo "   Les images générées seront nommées:"
echo "   - wordpress.png (pour l'exemple ci-dessus)"
echo "   - wordpress.svg"
echo "   - wordpress.pdf"
echo ""

echo "======================================="
echo " Pour commencer, exécutez l'une des commandes ci-dessus!"
echo ""

