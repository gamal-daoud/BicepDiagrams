import os
import json
from utils import slugify

class TemplateLoader:
    """Loads Jinja2 templates for Azure resource types.

    The loader expects a directory structure like:
        templates/<provider>/<type>.j2
    It builds a mapping of fully qualified RP type -> compiled Jinja template.
    """
    def __init__(self, templates_dir=None):
        import jinja2
        self.env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(templates_dir or os.path.join(os.path.dirname(__file__), '..', 'templates')),
            autoescape=False,
            trim_blocks=False,
            lstrip_blocks=False,
        )
        def to_bicep(val):
            if isinstance(val, str):
                escaped = val.replace("'", "''")
                return f"'{escaped}'"
            if isinstance(val, bool):
                return str(val).lower()
            if isinstance(val, (int, float)):
                return str(val)
            if isinstance(val, list):
                items = [to_bicep(i) for i in val]
                return f"[{', '.join(items)}]"
            if isinstance(val, dict):
                items = [f"{k}: {to_bicep(v)}" for k, v in val.items()]
                return f"{{ {', '.join(items)} }}"
            return str(val)

        self.env.filters['to_bicep'] = to_bicep
        self.env.filters['tojson'] = to_bicep
        self._cache = {}

    def get_template(self, resource_type: str):
        """Return a compiled Jinja2 template for the given Azure resource type.
        If the template does not exist, fall back to a generic "resource" template.
        """
        if resource_type in self._cache:
            return self._cache[resource_type]
        # Transform RP type into path:
        # Microsoft.Sql/servers/databases -> Microsoft.Sql/servers_databases.j2
        parts = resource_type.split('/')
        if len(parts) > 1:
            provider = parts[0]
            rest = "_".join(parts[1:])
            path = f"{provider}/{rest}.j2"
        else:
            path = f"{resource_type}.j2"
            
        try:
            tmpl = self.env.get_template(path)
        except Exception:
            generic = "resource {{ name }} '{{ type }}@{{ api_version|default('2021-01-01') }}' = {\n  name: '{{ name }}'\n  location: {{ location|default('eastus')|to_bicep }}\n}\n"
            tmpl = self.env.from_string(generic)
        self._cache[resource_type] = tmpl
        return tmpl
