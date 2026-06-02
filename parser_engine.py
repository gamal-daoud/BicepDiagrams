import json
import re
import subprocess
from pathlib import Path

NAME_SUFFIX_RE = re.compile(r"(?:Name|Names)$")

# 🔹 NETTOYAGE DES NOMS DE RESSOURCES
# Cette fonction traite les noms très complexes produits par Bicep/ARM
# où les noms peuvent contenir:
#   - Expressions ARM: [format(...), parameters(...), variables(...)]
#   - Chemins imbriqués: "parent/child/grandchild"
#   - Références dynamiques: resourceId(), resource names
def clean_label(raw_name):
    """Nettoie les noms de ressources ARM (expressions, paramètres, etc.)"""
    if not isinstance(raw_name, str):
        raw_name = str(raw_name)
    
    # Extraire le contenu de format() ou parameters()
    # Ex: [format('{0}/{1}', parameters('sa'), 'default')] -> sa/default
    # Ex: [parameters('storageAccountName')] -> storageAccountName
    
    # 1. Enlever les crochets extérieurs []
    # Les templates ARM enferment les expressions dans [...]
    if raw_name.startswith('[') and raw_name.endswith(']'):
        raw_name = raw_name[1:-1]
        
    # 2. Gérer parameters('...') et variables('...')
    # Remplacer les appels de fonction par leurs noms
    # Ex: parameters('vnetName') → vnetName
    raw_name = re.sub(r"parameters\('([^']+)'\)", r"\1", raw_name)
    raw_name = re.sub(r"variables\('([^']+)'\)", r"\1", raw_name)
    
    # 3. Gérer format('...', ...) - Approche simplifiée
    # format() concatène des chaînes: format('{0}/{1}', param1, param2)
    # On essaie d'extraire les littéraux
    if raw_name.startswith('format('):
        # Chercher d'abord des références variables
        variable_refs = re.findall(r"variables\('([^']+)'\)", raw_name)
        if variable_refs:
            return infer_symbolic_name(variable_refs[0])

        # Extraire tous les littéraux (chaînes entre guillemets)
        literal_parts = re.findall(r"'([^']*)'", raw_name)
        # Filtrer les littéraux vides ou contenant des placeholders {0}
        literals = [part for part in literal_parts if part and "{" not in part]
        if literals:
            return "/".join(literals).strip("/")
        return "resource"
            
    # 4. Prendre le dernier segment après /
    # Pour les noms hiérarchiques: "parent/child/resource" → "resource"
    clean = raw_name.split('/')[-1].replace("'", "").replace("(", "").replace(")", "")
    return clean

# 🔹 INFÉRENCE DE NOM SYMBOLIQUE
# Convertir les noms verbeux ARM en noms symboliques courts
# Ex: "virtualNetworkName" → "virtualNetwork" (enlever "Name")
def infer_symbolic_name(name):
    """Convertit virtualNetworkName -> virtualNetwork pour se rapprocher des noms Bicep."""
    cleaned = clean_label(name)
    # Enlever les suffixes courants "Name" ou "Names"
    return NAME_SUFFIX_RE.sub("", cleaned) or cleaned

# 🔹 ÉTIQUETTE DE RESSOURCE STABLE
# Obtenir un label stable pour une ressource
# Pour les boucles (copy), utiliser le nom de la copie
# Sinon, inférer le nom symbolique
def resource_label(res):
    """Nom stable: copy.name pour les boucles, sinon nom ARM nettoyé."""
    copy_name = res.get("copy", {}).get("name")
    # Les boucles ARM créent des copies avec un numéro
    # Ex: copy.name = "nicCopy" pour boucle sur NICs
    if copy_name:
        return copy_name
    return infer_symbolic_name(res.get("name", "unknown"))

# 🔹 EXTRACTION DU TYPE DE RESSOURCE DEPUIS resourceId()
# Fonction helper pour parser les appels resourceId()
def first_resource_id_type(value):
    # resourceId('Microsoft.Network/virtualNetworks', 'vnetName')
    # → récupère 'Microsoft.Network/virtualNetworks'
    match = re.search(r"resourceId\('([^']+)'", value)
    return match.group(1) if match else None

# 🔹 EXTRACTION DU NOM DE RESSOURCE DEPUIS resourceId()
# Fonction helper pour parser les appels resourceId()
def first_resource_id_name(value):
    """Extract literal resource name from resourceId('type', 'name') call."""
    # resourceId('Microsoft.Network/virtualNetworks', 'myVnet')
    # → récupère 'myVnet'
    match = re.search(r"resourceId\('[^']+',\s*'([^']+)'\)", value)
    return match.group(1) if match else None

def extract_nodes_and_edges(arm_json_content):
    """Extrait les ressources et leurs dépendances du template ARM"""
    nodes = []
    edges = []
    resources_by_id = {}       # Dictionnaire: resource_id → node_data
    resources_by_type = {}     # Dictionnaire: resource_type → [ids]

    def process_resources(resources, parent_id=None):
        # En Bicep (compilation avec noms symboliques), resources peut être un dictionnaire
        # au lieu d'une liste. On itère sur les valeurs.
        if isinstance(resources, dict):
            resources = list(resources.values())

        # 🔹 TRAITEMENT RÉCURSIF DES RESSOURCES
        # Parcourt toutes les ressources et crée des nœuds
        # Gère la hiérarchie: deployments imbriquées, subnets, etc.
        for res in resources:
            res_name = res.get('name', 'unknown')
            res_type = res.get('type', 'unknown')
            
            # Skip deployment resources but process their nested resources
            # Les ressources Microsoft.Resources/deployments sont des modules Bicep
            # Nous sautons le nœud deployment lui-même mais traitons ses ressources enfants
            if res_type == "Microsoft.Resources/deployments":
                # Récupérer les ressources enfants depuis le template imbriqué
                # Flux: deployment → properties.template.resources → process_resources()
                inner_resources = res.get('properties', {}).get('template', {}).get('resources', [])
                # Passer le nom du deployment comme parent_id pour la hiérarchie
                process_resources(inner_resources, parent_id=res_name if not parent_id else f"{parent_id}/{res_name}")
                continue

            # Identify parent from name if not already set
            # 🔹 EXTRACTION DE LA HIÉRARCHIE DES NOMS
            # Les ressources enfants sont nommées "parent/child" (ex: "myVnet/subnet1")
            # On analyse le nom pour identifier le parent automatiquement
            effective_parent = parent_id
            # Nettoyer le nom pour extraire les composants "/"
            # Ex: "[format('{0}/{1}', parameters('sa'), 'default')]" → "sa/default"
            cleaned_res_name = clean_label(res_name)
            if not effective_parent and '/' in cleaned_res_name:
                parts = cleaned_res_name.split('/')
                if len(parts) > 1:
                    # Récupérer tous les segments sauf le dernier
                    # Ex: "sa/fileServices/shares" → parent="sa/fileServices"
                    effective_parent = '/'.join(parts[:-1])

            # 🔹 CRÉATION DU NŒUD
            # Chaque nœud représente une ressource avec ses métadonnées
            full_id = resource_label(res)
            if parent_id:
                full_id = f"{parent_id}/{full_id}"

            nodes.append({
                "id": full_id,
                "type": res_type,                       # Ex: "Microsoft.Compute/virtualMachines"
                "label": full_id.split("/")[-1],       # Affichage: dernier segment du chemin
                "parent": effective_parent,
                "tags": res.get('tags', {})             # Tags Bicep: role, icon, status, etc.
            })
            resources_by_id[full_id] = nodes[-1]
            # Index par type pour recherche rapide
            resources_by_type.setdefault(res_type, []).append(full_id)

            # Explicit dependencies
            # 🔹 DÉPENDANCES EXPLICITES
            # Les ressources Bicep/ARM spécifient leurs dépendances via "dependsOn"
            # Chaque dépendance crée une arête du nœud vers la dépendance
            for dep in res.get('dependsOn', []):
                # Créer une arête: ce nœud → nœud dépendance
                edges.append((full_id, dep))

            # Implicit dependencies
            # 🔹 DÉPENDANCES IMPLICITES
            # Extraire les références aux autres ressources depuis les propriétés
            # Ces références créent des dépendances implicites (données, associations)
            props_str = json.dumps(res.get('properties', {}))
            
            # Smart Clustering: If resource is linked to an NSG
            # 🔹 CLUSTERING INTELLIGENT (NSGs)
            # Si une ressource référence un NSG, la placer sous le NSG (parent=NSG)
            # Cette logique est configurée dans bicep-diagrams.yaml avec "kind: cluster"
            nsg_ref = re.search(r"resourceId\('Microsoft\.Network/networkSecurityGroups',\s*'([^']+)'\)", props_str)
            if nsg_ref:
                effective_parent = nsg_ref.group(1)
                # Mettre à jour le parent du nœud pour la hiérarchie visuelle
                nodes[-1]["parent"] = effective_parent

            # 🔹 EXTRACTION DES RÉFÉRENCES À D'AUTRES RESSOURCES
            # Forme: NOM_RESSOURCE.id → référence à l'ID d'une autre ressource
            # Cette forme est traduite en flux de données (arête)
            refs = re.findall(r'([a-zA-Z_][a-zA-Z0-9_]*)\.id', props_str)
            for ref in refs:
                if ref != res_name:
                    # Créer une arête vers la ressource référencée
                    edges.append((full_id, ref))
            
            # 🔹 EXTRACTION DES RÉFÉRENCES resourceId()
            # Forme: resourceId('type', 'name', ...)
            # Type récupéré pour filtrage/résolution
            refs = re.findall(r"resourceId\('([^']+)'[^]]*\)", props_str)
            for ref_type in refs:
                # Créer une arête basée sur le type
                edges.append((full_id, ref_type))

            # Recursive for inline resources (not deployments)
            # 🔹 RESSOURCES IMBRIQUÉES (non-deployments)
            # Certaines ressources contiennent directement des enfants
            # Ex: NIC peut contenir des ipConfigurations
            if 'resources' in res:
                process_resources(res['resources'], parent_id=full_id)

    process_resources(arm_json_content.get('resources', []))

    # 🔹 RÉSOLUTION DES RÉFÉRENCES
    # Transformer les références (noms, types) en IDs de nœuds existants
    # Cela garantit que les arêtes connectent des nœuds qui existent réellement
    def resolve_ref(ref):
        # Recherche 1: ID direct
        # Si la référence est déjà un ID complet, la retourner
        if ref in resources_by_id:
            return ref

        # Name-based resolution: extract literal name from resourceId('type','name')
        # Recherche 2: Extraction du nom depuis resourceId()
        # Chercher une ressource avec ce nom
        res_name = first_resource_id_name(ref)
        if res_name:
            clean_name = infer_symbolic_name(res_name)
            # Chercher une ressource dont l'ID contient ce nom
            if clean_name in resources_by_id:
                return clean_name
            # Ou dont l'ID se termine par "/clean_name"
            for node_id in resources_by_id:
                if node_id.endswith(f"/{clean_name}"):
                    return node_id

        # Type-based fallback (less precise)
        # Recherche 3: Résolution par type
        ref_type = first_resource_id_type(ref) or ref
        # Utiliser la première ressource de ce type (moins précis)
        if ref_type in resources_by_type and ref_type != 'Microsoft.Storage/storageAccounts':
            return resources_by_type[ref_type][0]

        # Symbol inference fallback
        # Recherche 4: Nettoyage du nom et nouvelle tentative
        clean_ref = infer_symbolic_name(ref)
        if clean_ref in resources_by_id:
            return clean_ref

        # Recherche 5: Correspondance partielle
        if "/" in clean_ref:
            tail = clean_ref.split("/")[-1]
            if tail in resources_by_id:
                return tail

        # Recherche 6: Chercher un ID qui se termine par ce segment
        for node_id in resources_by_id:
            if node_id.endswith(f"/{clean_ref}"):
                return node_id
        return clean_ref
    
    resolved_edges = []
    for source, target in edges:
        # Résoudre les deux extrémités de chaque arête
        source_id = resolve_ref(source)
        target_id = resolve_ref(target)
        # Vérifier que les deux nœuds existent réellement avant de créer l'arête
        # Cela évite les arêtes "fantômes" vers des ressources qui n'existent pas
        if source_id != target_id and source_id in resources_by_id and target_id in resources_by_id:
            resolved_edges.append((source_id, target_id))
    
    return nodes, list(set(resolved_edges))

def compile_bicep(bicep_path):
    """Compile un fichier Bicep en objet ARM Python"""
    bicep_file = Path(bicep_path)
    if not bicep_file.exists():
        raise FileNotFoundError(f"Fichier non trouvé: {bicep_path}")
    
    proc = subprocess.run(
        ['bicep', 'build', str(bicep_file)],
        capture_output=True, text=True
    )
    
    if proc.returncode != 0:
        raise Exception(f"Erreur compilation: {proc.stderr}")
    
    return json.loads(proc.stdout)
