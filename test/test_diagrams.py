import os
import sys
import unittest
import json
import shutil
import subprocess

# Add parent directory to path so we can import parser_engine and bicep_diagrams
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from parser_engine import clean_label, infer_symbolic_name, extract_nodes_and_edges

class TestParserEngine(unittest.TestCase):
    def test_clean_label_simple(self):
        self.assertEqual(clean_label("myVnet/subnetA"), "subnetA")
        self.assertEqual(clean_label("simpleName"), "simpleName")

    def test_clean_label_parameters(self):
        self.assertEqual(clean_label("[parameters('storageAccountName')]"), "storageAccountName")
        self.assertEqual(clean_label("[variables('myVar')]"), "myVar")

    def test_infer_symbolic_name(self):
        self.assertEqual(infer_symbolic_name("virtualNetworkName"), "virtualNetwork")
        self.assertEqual(infer_symbolic_name("[parameters('storageAccountNames')]"), "storageAccount")

    def test_extract_nodes_and_edges(self):
        # A simple ARM template structure
        arm_template = {
            "resources": [
                {
                    "type": "Microsoft.Network/virtualNetworks",
                    "name": "myVnet",
                    "properties": {}
                },
                {
                    "type": "Microsoft.Network/virtualNetworks/subnets",
                    "name": "myVnet/subnetA",
                    "properties": {}
                }
            ]
        }
        nodes, edges = extract_nodes_and_edges(arm_template)
        
        # We expect two nodes
        self.assertEqual(len(nodes), 2)
        node_types = [n["type"] for n in nodes]
        self.assertIn("Microsoft.Network/virtualNetworks", node_types)
        self.assertIn("Microsoft.Network/virtualNetworks/subnets", node_types)


class TestIntegration(unittest.TestCase):
    def setUp(self):
        self.project_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        self.test_output_dir = os.path.join(self.project_dir, 'test_output')
        os.makedirs(self.test_output_dir, exist_ok=True)

    def tearDown(self):
        if os.path.exists(self.test_output_dir):
            shutil.rmtree(self.test_output_dir)

    def test_compile_and_generate_diagram(self):
        bicep_file = os.path.join(self.project_dir, 'input', 'simple_vnet.bicep')
        output_prefix = os.path.join(self.test_output_dir, 'test_simple_vnet')
        
        # Run main visualization CLI
        cmd = [
            sys.executable,
            os.path.join(self.project_dir, 'bicep-diagrams.py'),
            bicep_file,
            '-o', output_prefix,
            '-f', 'png'
        ]
        
        proc = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, f"Command failed: {proc.stderr}")
        
        # Check that the diagram image is created
        # The script creates {output_prefix}.png
        expected_png = f"{output_prefix}.png"
        self.assertTrue(os.path.exists(expected_png), f"Expected diagram image {expected_png} was not created.")

if __name__ == '__main__':
    unittest.main()
