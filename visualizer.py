import subprocess
import json
from diagrams import Diagram, Cluster
from diagrams.azure.compute import VM
from diagrams.azure.storage import StorageAccounts
from diagrams.azure.network import VirtualNetworks
from parser_engine import extract_nodes_and_edges 

# Mapping technique
AZURE_MAP = {
    "Microsoft.Storage/storageAccounts": StorageAccounts,
    "Microsoft.Compute/virtualMachines": VM,
    "Microsoft.Network/virtualNetworks": VirtualNetworks
}

def run_visualization(bicep_path):
    # 1. Compilation Bicep -> JSON
    print(f"Compilation de {bicep_path}...")
    proc = subprocess.run(['az', 'bicep', 'build', '--file', bicep_path, '--stdout'],capture_output=True, text=True)
    arm_data = json.loads(proc.stdout)

    # 2. Extraction via notre fichier indépendant
    nodes_data, edges_data = extract_nodes_and_edges(arm_data)

    # 3. Rendu du diagramme
    with Diagram("Azure Infrastructure from Bicep", show=False, direction="BT"):
        drawn_nodes = {}

        with Cluster("Resource Group"):
            for n in nodes_data:
                if n['type'] in AZURE_MAP:
                    drawn_nodes[n['id']] = AZURE_MAP[n['type']](n['label'])

        # Création des arêtes (relations)
        for parent, child in edges_data:
            if parent in drawn_nodes and child in drawn_nodes:
                drawn_nodes[parent] >> drawn_nodes[child]

if __name__ == "__main__":
    run_visualization("main.bicep")
    print("Succès : Diagramme généré.")