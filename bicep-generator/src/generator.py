import json
import os
from template_loader import TemplateLoader
from utils import slugify

class Generator:
    """Core class that transforms a high‑level description into Bicep files."""

    @staticmethod
    def generate(description: dict):
        """Generate Bicep content and optional .bicepparam content.

        Parameters
        ----------
        description: dict
            Must contain a top‑level key ``"resources"`` – a list of resource
            definitions. Each definition needs at least ``type`` and ``name``.
        Returns
        -------
        tuple(str, str)
            (bicep_content, parameter_content)
        """
        if "resources" not in description:
            raise ValueError("Description must contain a 'resources' list")
        resources = description["resources"]
        # Resolve ordering – simple topological sort based on parent relationships
        ordered = Generator._order_resources(resources)
        bicep_blocks = []
        param_blocks = []
        loader = TemplateLoader()
        for res in ordered:
            r_type = res["type"]
            name = res["name"]
            template = loader.get_template(r_type)
            # Merge default params from config with user‑provided ones
            context = {
                "name": slugify(name),
                "type": r_type
            }
            context.update(res.get("properties", {}))
            # Parent handling – inject parent resource id if needed
            if "parent" in res:
                parent_name = res["parent"]
                context["parent_id"] = f"{slugify(parent_name)}"
            rendered = template.render(**context)
            bicep_blocks.append(rendered)
            # Collect parameters – any top‑level keys that are scalar values
            for key, val in res.get("properties", {}).items():
                if isinstance(val, (str, int, float, bool)):
                    param_blocks.append(f"param {slugify(key)} string = '{val}'")
        bicep_content = "\n\n".join(bicep_blocks)
        param_content = "\n".join(sorted(set(param_blocks)))
        return bicep_content, param_content

    @staticmethod
    def _order_resources(resources):
        """Very naive ordering – resources without a parent first, then children.
        This works for most simple examples. For complex graphs you could replace
        this with a full topological sort.
        """
        without_parent = [r for r in resources if "parent" not in r]
        with_parent = [r for r in resources if "parent" in r]
        return without_parent + with_parent
