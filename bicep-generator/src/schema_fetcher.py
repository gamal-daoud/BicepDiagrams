import requests
import os
import json

class SchemaFetcher:
    """Fetches Azure Resource Provider schemas from official sources."""
    
    BASE_URL = "https://raw.githubusercontent.com/Azure/azure-resource-manager-schemas/main/schemas"

    @staticmethod
    def fetch_schema(provider: str, api_version: str):
        """Fetch schema for a specific provider and API version.
        Example: Microsoft.Network, 2021-02-01
        """
        url = f"{SchemaFetcher.BASE_URL}/{api_version}/{provider}.json"
        response = requests.get(url)
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"Failed to fetch schema: {response.status_code} - {url}")

    @staticmethod
    def generate_template_from_schema(schema: dict, resource_type: str):
        """Generate a basic Jinja2 template from a schema for a specific resource type."""
        definitions = schema.get("resourceDefinitions", {})
        short_type = resource_type.split('/')[-1]
        
        resource_def = definitions.get(short_type, {})
        properties = resource_def.get("properties", {}).get("properties", {})
        
        lines = []
        lines.append(f"resource {{{{ name }}}} '{resource_type}@{{{{ api_version|default('2021-01-01') }}}}' = {{")
        lines.append("  name: '{{ name }}'")
        lines.append("  {% if parent_id %}parent: {{ parent_id }}{% endif %}")
        lines.append("  location: {{ location|to_bicep if location else 'resourceGroup().location' }}")
        lines.append("  properties: {")
        
        for prop_name, prop_def in properties.items():
            if prop_name in ["name", "location", "tags"]:
                continue
            lines.append(f"    {{% if {prop_name} %}}{prop_name}: {{{{ {prop_name}|to_bicep }}}}{{% endif %}}")
            
        lines.append("  }")
        lines.append("}")
        
        return "\n".join(lines)
