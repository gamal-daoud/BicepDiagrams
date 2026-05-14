
import json
import re
import subprocess
from pathlib import Path

NAME_SUFFIX_RE = re.compile(r"(?:Name|Names)$")

def clean_label(raw_name):
    """Nettoie les noms de ressources ARM (expressions, paramètres, etc.)"""
    if not isinstance(raw_name, str):
        raw_name = str(raw_name)
    
    # Extraire le contenu de format() ou parameters()
    # Ex: [format('{0}/{1}', parameters('sa'), 'default')] -> sa/default
    # Ex: [parameters('storageAccountName')] -> storageAccountName
    
    # 1. Enlever les crochets extérieurs []
    if raw_name.startswith('[') and raw_name.endswith(']'):
        raw_name = raw_name[1:-1]
        
    # 2. Gérer parameters('...')
    raw_name = re.sub(r"parameters\('([^']+)'\)", r"\1", raw_name)
    raw_name = re.sub(r"variables\('([^']+)'\)", r"\1", raw_name)
    
    # 3. Gérer format('...', ...) - Approche simplifiée
    if raw_name.startswith('format('):
        variable_refs = re.findall(r"variables\('([^']+)'\)", raw_name)
        if variable_refs:
            return infer_symbolic_name(variable_refs[0])

        literal_parts = re.findall(r"'([^']*)'", raw_name)
        literals = [part for part in literal_parts if part and "{" not in part]
        if literals:
            return "/".join(literals).strip("/")
        return "resource"
            
    # 4. Prendre le dernier segment après /
    clean = raw_name.split('/')[-1].replace("'", "").replace("(", "").replace(")", "")
    return clean

def infer_symbolic_name(name):
    """Convertit virtualNetworkName -> virtualNetwork pour se rapprocher des noms Bicep."""
    cleaned = clean_label(name)
    return NAME_SUFFIX_RE.sub("", cleaned) or cleaned

def resource_label(res):
    """Nom stable: copy.name pour les boucles, sinon nom ARM nettoyé."""
    copy_name = res.get("copy", {}).get("name")
    if copy_name:
        return copy_name
    return infer_symbolic_name(res.get("name", "unknown"))

def first_resource_id_type(value):
    match = re.search(r"resourceId\('([^']+)'", value)
    return match.group(1) if match else None

def extract_nodes_and_edges(arm_json_content):
    """Extrait les ressources et leurs dépendances du template ARM"""
    nodes = []
    edges = []
    resources_by_id = {}
    resources_by_type = {}
    
    def process_resources(resources, parent_id=None):
        for res in resources:
            res_name = res.get('name', 'unknown')
            res_type = res.get('type', 'unknown')
            
            # Skip deployment resources but process their nested resources
            if res_type == "Microsoft.Resources/deployments":
                # For modules, the "id" for hierarchy should be the deployment name
                inner_resources = res.get('properties', {}).get('template', {}).get('resources', [])
                process_resources(inner_resources, parent_id=res_name if not parent_id else f"{parent_id}/{res_name}")
                continue

            # Identify parent from name if not already set
            effective_parent = parent_id
            # Clean the name first to find parent in format expressions like "myVnet/subnetA"
            cleaned_res_name = clean_label(res_name)
            if not effective_parent and '/' in cleaned_res_name:
                parts = cleaned_res_name.split('/')
                if len(parts) > 1:
                    effective_parent = '/'.join(parts[:-1])

            full_id = resource_label(res)
            if parent_id:
                full_id = f"{parent_id}/{full_id}"

            nodes.append({
                "id": full_id,
                "type": res_type,
                "label": full_id.split("/")[-1],
                "parent": effective_parent
            })
            resources_by_id[full_id] = nodes[-1]
            resources_by_type.setdefault(res_type, []).append(full_id)

            # Explicit dependencies
            for dep in res.get('dependsOn', []):
                edges.append((full_id, dep))

            # Implicit dependencies
            props_str = json.dumps(res.get('properties', {}))
            
            # Smart Clustering: If resource is linked to an NSG, make it a child of that NSG cluster
            nsg_ref = re.search(r"resourceId\('Microsoft\.Network/networkSecurityGroups',\s*'([^']+)'\)", props_str)
            if nsg_ref:
                effective_parent = nsg_ref.group(1)
                # Update node parent
                nodes[-1]["parent"] = effective_parent

            refs = re.findall(r'([a-zA-Z_][a-zA-Z0-9_]*)\.id', props_str)
            for ref in refs:
                if ref != res_name:
                    edges.append((full_id, ref))
            
            refs = re.findall(r"resourceId\('([^']+)'[^]]*\)", props_str)
            for ref_type in refs:
                edges.append((full_id, ref_type))

            # Recursive for inline resources (not deployments)
            if 'resources' in res:
                process_resources(res['resources'], parent_id=full_id)

    process_resources(arm_json_content.get('resources', []))

    def resolve_ref(ref):
        if ref in resources_by_id:
            return ref

        ref_type = first_resource_id_type(ref) or ref
        if ref_type in resources_by_type:
            return resources_by_type[ref_type][0]

        clean_ref = infer_symbolic_name(ref)
        if clean_ref in resources_by_id:
            return clean_ref

        if "/" in clean_ref:
            tail = clean_ref.split("/")[-1]
            if tail in resources_by_id:
                return tail

        for node_id in resources_by_id:
            if node_id.endswith(f"/{clean_ref}"):
                return node_id
        return clean_ref
    
    resolved_edges = []
    for source, target in edges:
        source_id = resolve_ref(source)
        target_id = resolve_ref(target)
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
