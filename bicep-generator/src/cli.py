import argparse
import json
import os
import sys

from generator import Generator

def main():
    parser = argparse.ArgumentParser(description='Generate Azure Bicep from JSON/YAML description')
    parser.add_argument('-i', '--input', required=True, help='Path to input JSON or YAML file')
    parser.add_argument('-o', '--output', required=True, help='Path for the generated .bicep file')
    parser.add_argument('--params', help='Optional path for generated .bicepparam file')
    args = parser.parse_args()


    try:
        with open(args.input, 'r', encoding='utf-8') as f:
            description = json.load(f)
    except Exception as e:
        print(f"[Error] Failed to load input file: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        bicep_content, param_content = Generator.generate(description)
    except Exception as e:
        print(f"[Error] Generation failed: {e}", file=sys.stderr)
        sys.exit(1)

    # Write Bicep file
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(bicep_content)
    print(f"[OK] Bicep file written to {args.output}")

    # Write params if requested
    if args.params:
        with open(args.params, 'w', encoding='utf-8') as f:
            f.write(param_content)
        print(f"[OK] Parameter file written to {args.params}")

if __name__ == '__main__':
    main()
