import json
import os
import sys
from pathlib import Path

# Add the project root to sys.path
sys.path.append("/home/gamal-daoud/Documents/BicepDiagrams")

from parser_engine import extract_nodes_and_edges

bicep_file = "/home/gamal-daoud/Documents/BicepDiagrams/bicep-generator/output/test.bicep"

# Compile to ARM
import subprocess
proc = subprocess.run(['az', 'bicep', 'build', '--file', bicep_file, '--stdout'], capture_output=True, text=True)
arm_data = json.loads(proc.stdout)

nodes, edges = extract_nodes_and_edges(arm_data)

print(f"Nodes found: {len(nodes)}")
for n in nodes:
    print(f" - {n['id']} ({n['type']}) -> Parent: {n['parent']}")

print(f"Edges found: {len(edges)}")
for e in edges:
    print(f" - {e}")
