#!/usr/bin/env python3
"""AWS CloudFormation Diagrams main script."""

import argparse
import datetime
import importlib
import json
import os
from pathlib import Path
import pygraphviz
import re
import subprocess
import sys
import yaml
import diagrams
import diagrams.custom
from diagrams import Edge, Cluster
from diagrams.aws.enablement import ManagedServices

#
# Absolute paths to be replaced by urls
#

DIAGRAMS_PATH = str(Path(os.path.abspath(os.path.dirname(diagrams.__file__))).parent)
DIAGRAMS_URL = \
    "https://raw.githubusercontent.com/mingrammer/diagrams/refs/heads/master"
CFD_PATH = str(Path(os.path.abspath(os.path.dirname(__file__))).parent)
CFD_URL = \
    "https://raw.githubusercontent.com/philippemerle/AWS CloudFormation Diagrams/refs/heads/main"

#
# Trace message management
#

def debug(message: str) -> None:
    """
        Print a debug message.
        
        :param message: Debug message to print
        :type message: str
    """
    print(f"\33[34m[Debug] {message}.\33[0m")

def info(message: str, end: str = ".") -> None:
    """
        Print an info message.
        
        :param message: Info message to print
        :type message: str
    """
    print(f"[Info] {message}{end}")

def warning(message: str) -> None:
    """
        Print a warning message.
        
        :param message: Warning message to print
        :type message: str
    """
    print(f"\33[33m[Warning] {message}!\33[0m")

def error(message: str) -> None:
    """
        Print an error message.

        :param message: Error message to print
        :type message: str
    """
    print(f"\33[31m[Error] {message}!\33[0m")

#
# Conversion of dot files to D2 files
#

def convert_dot_attributes_to_d2(name: str, attributes: dict, attr: str, ident: int, stream):
    mappings = []
    if attr is not None:
        mappings.append(attr)
    for ak, av in attributes.items():
        if ak == "bgcolor":
            mappings.append(f"fill: \"{av}\"")
#        elif ak == "color":
#            mappings.append(f"color:{av}")
        elif ak == "fontcolor":
            mappings.append(f"font-color: \"{av}\"")
# Commented as currently d2 supports only one font.
#        elif ak == "fontname":
#            mappings.append(f"font: \"{av.lower()}\"")
        elif ak == "fontsize":
            mappings.append(f"font-size: {av}")
#        elif ak == "shape":
#            mappings.append(f"stroke: \"{av}\"")
    if len(mappings) > 0:
        print("  "*ident, "style : {", sep="", file=stream)
        for mapping in mappings:
            print("  "*(ident+1), mapping, sep="", file=stream)
        print("  "*ident, "}", sep="", file=stream)

def convert_dot_subgraph_to_d2(graph: pygraphviz.AGraph, already_created_nodes: dict, node_id_prefix: str, ident: int, stream):
    for subgraph in graph.subgraphs():
        print("  "*ident, subgraph.name, ": ", subgraph.graph_attr["tooltip"].split(":")[0], " {", sep="", file=stream)
        convert_dot_attributes_to_d2(subgraph.name, subgraph.graph_attr, None, ident+1, stream)
        print("  "*(ident+1), "tooltip: |`yaml", sep="", file=stream)
        print(subgraph.graph_attr["tooltip"], file=stream)
        print("`|", file=stream)
        convert_dot_subgraph_to_d2(subgraph, already_created_nodes, f"{node_id_prefix}{subgraph.name}.", ident+1, stream)
        print("  "*ident, "}", sep="", file=stream)
    for nid in graph.nodes():
        if nid not in already_created_nodes:
            already_created_nodes[nid] = f"{node_id_prefix}{nid}"
            node = graph.get_node(nid)
            label = node.attr["label"].replace("\n", "")
            print("  "*ident, node.name, ": ", label, " {", sep="", file=stream)
            print("  "*(ident+1), "shape: image", sep="", file=stream)
            url = node.attr["image"].replace(DIAGRAMS_PATH, DIAGRAMS_URL)
            print("  "*(ident+1), "icon: ", url, sep="", file=stream)
            print("  "*(ident+1), "tooltip: |`yaml", sep="", file=stream)
            print(node.attr["tooltip"], file=stream)
            print("`|", file=stream)
            convert_dot_attributes_to_d2(node.name, node.attr, None, ident+1, stream)
            print("  "*ident, "}", sep="", file=stream)

def convert_dot_to_d2(dot_filename, d2_filename):
    graph = pygraphviz.AGraph()
    graph.read(dot_filename)
    with open(d2_filename, "wt") as stream:
        node_ids = {}
        convert_dot_subgraph_to_d2(graph, node_ids, "", 0, stream)
        for eid, edge in enumerate(graph.edges()):
            edge_dir = {
                "forward": "->",
                "both": "<->",
            }[edge.attr["dir"]]
            print(node_ids[edge[0]], edge_dir, node_ids[edge[1]], "{", file=stream)
            edge_color = edge.attr.get("color") or graph.edge_attr["color"]
            convert_dot_attributes_to_d2(eid, edge.attr, f"stroke: \"{edge_color}\"", 1, stream)
            print("  ", "tooltip: |`yaml", sep="", file=stream)
            print(edge.attr["tooltip"], file=stream)
            print("`|", file=stream)
            print("}", file=stream)

#
# Conversion of dot files to Mermaid files
#

def convert_attributes(command: str, name: str, attributes: dict, attr: str, ident: int, stream):
    mappings = []
    if attr is not None:
        mappings.append(attr)
    for ak, av in attributes.items():
        if ak == "bgcolor":
            mappings.append(f"fill:{av}")
#        elif ak == "color":
#            mappings.append(f"color:{av}")
        elif ak == "fontcolor":
            mappings.append(f"color:{av}")
        elif ak == "fontname":
            mappings.append(f"font:{av.lower()}")
        elif ak == "fontsize":
            mappings.append(f"font-size:{av}pt")
        elif ak == "shape":
            mappings.append(f"stroke:{av}")
    if len(mappings) > 0:
        print("  "*ident, command, " ", name, " ", ",".join(mappings), sep="", file=stream)

def convert_subgraph(graph: pygraphviz.AGraph, already_created_nodes: set, ident: int, stream):
    for subgraph in graph.subgraphs():
        print("  "*ident, "subgraph ", subgraph.name, " [", subgraph.graph_attr["label"], "]", sep="", file=stream)
        print("  "*(ident+1), "direction TB", sep="", file=stream)
        convert_attributes("style", subgraph.name, subgraph.graph_attr, None, ident+1, stream)
        convert_subgraph(subgraph, already_created_nodes, ident+1, stream)
        print("  "*ident, "end", sep="", file=stream)
    for nid in graph.nodes():
        if nid not in already_created_nodes:
            already_created_nodes.add(nid)
            node = graph.get_node(nid)
            url = node.attr["image"].replace(DIAGRAMS_PATH, DIAGRAMS_URL)
            url = url.replace(CFD_PATH, CFD_URL)
            label = node.attr["label"].replace("\n", "")
            print("  "*ident, node.name, "@{ img: \"", url, "\", label: \"", label, "\", h: 120, constraint: \"on\" }", sep="", file=stream)
            convert_attributes("style", node.name, node.attr, "fill:none", ident, stream)

def convert_dot_to_mermaid(dot_filename, mermaid_filename):
    graph = pygraphviz.AGraph()
    graph.read(dot_filename)
    with open(mermaid_filename, "wt") as stream:
        print("flowchart TB", file=stream)
        convert_subgraph(graph, set(), 1, stream)
        for eid, edge in enumerate(graph.edges()):
            edge_dir = {
                "forward": "-->",
                "both": "<-->",
            }[edge.attr["dir"]]
            print(" ", edge[0], edge_dir, edge[1], file=stream)
            edge_color = edge.attr.get("color") or graph.edge_attr["color"]
            convert_attributes("linkStyle", eid, edge.attr, f"stroke:{edge_color}", 1, stream)

#
# PyYAML constructors for AWS CloudFormation functions
#

def node_constructor(
        node: object,
        constructor: yaml.constructor.BaseConstructor
    ):
    """
        Generic node constructor.
    
        :param node: PyYAML node
        :type node: object
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
    """
    if isinstance(node, yaml.ScalarNode):
        return constructor.construct_scalar(node)
    if isinstance(node, yaml.MappingNode):
        return constructor.construct_mapping(node)
    if isinstance(node, yaml.SequenceNode):
        return constructor.construct_sequence(node)
    return node

def and_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !And AWS CloudFormation Function.

        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::And": constructor.construct_sequence(node) }
yaml.add_constructor("!And", and_constructor)

def base64_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Base64 AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Base64": node_constructor(node, constructor) }
yaml.add_constructor("!Base64", base64_constructor)

def condition_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Condition AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Condition": constructor.construct_scalar(node) }
yaml.add_constructor("!Condition", condition_constructor)

def equals_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Equals AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Equals": constructor.construct_sequence(node) }
yaml.add_constructor("!Equals", equals_constructor)

def if_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !If AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::If": constructor.construct_sequence(node) }
yaml.add_constructor("!If", if_constructor)

def importvalue_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !ImportValue AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::ImportValue": node_constructor(node, constructor) }
yaml.add_constructor("!ImportValue", importvalue_constructor)

def findinmap_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !FindInMap AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::FindInMap": constructor.construct_sequence(node) }
yaml.add_constructor("!FindInMap", findinmap_constructor)

def getatt_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !GetAtt AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    if isinstance(node, yaml.ScalarNode):
        value = constructor.construct_scalar(node)
        return { "Fn::GetAtt": value.split(".") }
    else:
        return { "Fn::GetAtt": node_constructor(node, constructor) }
yaml.add_constructor("!GetAtt", getatt_constructor)

def getazs_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !GetAZs AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::GetAZs": node_constructor(node, constructor) }
yaml.add_constructor("!GetAZs", getazs_constructor)

def join_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Join AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Join": constructor.construct_sequence(node) }
yaml.add_constructor("!Join", join_constructor)

def not_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Not AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Not": constructor.construct_sequence(node) }
yaml.add_constructor("!Not", not_constructor)

def or_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Or AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Or": constructor.construct_sequence(node) }
yaml.add_constructor("!Or", or_constructor)

def rain_embed_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Rain::Embed AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Rain::Embed": constructor.construct_scalar(node) }
yaml.add_constructor("!Rain::Embed", rain_embed_constructor)

def rain_module_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Rain::Module AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Rain::Module": constructor.construct_scalar(node) }
yaml.add_constructor("!Rain::Module", rain_module_constructor)

def rain_s3_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Rain::S3 AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Rain::S3": constructor.construct_mapping(node) }
yaml.add_constructor("!Rain::S3", rain_s3_constructor)

def ref_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Ref AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Ref": constructor.construct_scalar(node) }
yaml.add_constructor("!Ref", ref_constructor)

def select_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Select AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Select": constructor.construct_sequence(node) }
yaml.add_constructor("!Select", select_constructor)

def sub_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Sub AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Sub": node_constructor(node, constructor) }
yaml.add_constructor("!Sub", sub_constructor)

def split_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !Split AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::Split": node_constructor(node, constructor) }
yaml.add_constructor("!Split", split_constructor)

def valueof_constructor(
        constructor: yaml.constructor.BaseConstructor,
        node: object
    ):
    """
        Constructor for !ValueOf AWS CloudFormation Function.
    
        :param constructor: PyYAML constructor
        :type constructor: yaml.constructor.BaseConstructor
        :param node: PyYAML node
        :type node: object
    """
    return { "Fn::ValueOf": constructor.construct_sequence(node) }
yaml.add_constructor("!ValueOf", valueof_constructor)

#
# Extensions to the Diagrams library.
#

# All dot output formats are listed in https://graphviz.org/docs/outputs/
# If you need a format not listed below, just add it below.
SUPPORTED_OUTPUT_FORMATS = (
    "d2", "dot", "dot_json", "drawio", "gif", "jp2", "jpe", "jpeg", "jpg",
    "mermaid", "pdf", "png", "svg", "tif", "tiff",
)
class Diagram(diagrams.Diagram):
    """ Enhanced Diagram class with new output formats. """
    # pylint: disable-next=unused-private-member
    __outformats = SUPPORTED_OUTPUT_FORMATS

# Inspired from https://github.com/mingrammer/diagrams/pull/853
def get_icon_path(diagrams_node_class: object):
    """
    Get the icon path of a Diagrams node class.

    :param diagrams_node_class: Diagrams node class, like VPC or Docker
    :returns: The path to the icon
    """
    # pylint: disable-next=too-few-public-methods
    class Node(diagrams_node_class):
        """Overloading Node class."""
        def __init__(self):
            """Initialisation."""
            # pass # do nothing!

    # pylint: disable-next=protected-access
    return Node()._load_icon()

def label_with_icon(icon_path: str, label: str, size=64):
    """
    :param icon_path: An icon path
    :param label: Label text, like "subnet-a"
    :param size: Icon size in px.
    :returns: "Label prefixed with a specified icon"
    """
    return '<<table border="0" width="100%"><tr><td fixedsize="true" width="' \
            + str(size) + '" height="' + str(size) \
            + '"><img src="' + icon_path + '" /></td><td>' \
            + label + '</td></tr></table>>'

#
# Create diagram nodes
#

# Maximum length for diagram node labels
MAX_NODE_LABEL_LENGTH = 14

# Separators in node labels
NODE_LABEL_SEPARATORS = [" ", ":", "-", "."]

def split_node_label(node_label):
    """Split node labels into multi-lines."""
    result = ""
    last_pos = 0
    max_pos = len(node_label) - MAX_NODE_LABEL_LENGTH
    while last_pos < max_pos:
        part = node_label[last_pos:last_pos+MAX_NODE_LABEL_LENGTH]
        idx = MAX_NODE_LABEL_LENGTH - 1
        while idx > 0:
            if part[idx] in NODE_LABEL_SEPARATORS:
                part = part[:idx]
                break
            idx -= 1
        result += part
        result += "\n"
        last_pos += len(part)
    result += node_label[last_pos:]
    return result

GLOBALS = {
    "Engine": None,
    "MapPublicIpOnLaunch": True,
    "SourceDBInstanceIdentifier": None,
    "Type": None,
}

def get_diagram_class(resource):
    """
        Get a diagram class from an AWS CloudFormation resource.
    """
    # Search diagram node class
    diagram_node_classname = None
    configuration = get_config(resource)
    cicon = configuration.get("icon", {})
    if "classname" in cicon:
        classname = cicon["classname"]
        if isinstance(classname, str):
            diagram_node_classname = classname
        elif isinstance(classname, list):
            for item in classname:
                when = item.get("when", True)
                properties = resource.get("Properties", {})
                # pylint: disable-next=eval-used
                if when is True or eval(when, GLOBALS, properties):
                    diagram_node_classname = item["then"]
                    break
    diagram_node_class = ManagedServices
    if diagram_node_classname is not None:
        # Import Diagrams node class module
        idx = diagram_node_classname.rfind('.')
        if idx != -1:
            module = importlib.import_module(diagram_node_classname[:idx])
            # Get diagram node class
            diagram_node_class = getattr(module, diagram_node_classname[idx+1:])
    return diagram_node_class

def dump_resource(rname, rdata):
    result = yaml.dump(
                {rname: rdata},
                default_flow_style=False,
                sort_keys=False
             )[:-1].replace("\n\n", "\n")
    if len(result) > 16384: # dot parsing limit!
        result = result[:16380] + "\n..."
    return result

def create_diagram_node(name, resource):
    """
        Create a diagram node from an AWS CloudFormation resource.
    """
    tooltip = dump_resource(name, resource)
    configuration = get_config(resource)
    if "icon" in configuration and "filename" in configuration["icon"]:
        filename = configuration["icon"]["filename"]
        if filename is not None: # filename defined
            return diagrams.custom.Custom(
                label=split_node_label(name),
                icon_path=DIRNAME + "/" + filename, #.replace("$KD", DIRNAME)),
                nodeid=f"resource_{name}",
                tooltip=tooltip,
                **compute_style(configuration.get("style", {}))
            )
    return get_diagram_class(resource)(
        label=split_node_label(name),
        nodeid=f"resource_{name}",
        tooltip=tooltip,
        **compute_style(configuration.get("style", {}))
    )

def compute_style(style):
    """
        Compute style.

        
    """
    if isinstance(style, str):
        return config["styles"].get(style, {})
    if isinstance(style, dict):
        return style
    return None

def get_type(resource: dict) -> str:
    """
        Get the type of an AWS resource.
        
        :param resource: An AWS resource 
    """
    resource_type = resource["Type"]
    if isinstance(resource_type, dict):
        if len(resource_type) == 1 and list(resource_type.keys()) == ["Rain::Module"]:
            resource_type = "Rain::Module"
        else:
            resource_type = "DICT_TYPE"
    return resource_type

def get_property(resource_ref: dict, property_name: str):
    """
        Get a property of a referenced resource.

        :param resource_ref: The reference to the resource
        :param property_name: The name of the property
    """
    if resource_ref is not None and "Ref" in resource_ref:
        return cloud_formation_data["Resources"] \
               [resource_ref["Ref"]]["Properties"] \
               .get(property_name)
    return None

GLOBALS["property"] = get_property

def get_config(resource: dict, default_config: bool = True) -> dict:
    """
        Get configuration associated to an AWS resource.
        
        :param resource: An AWS resource
        :param default_config: default configuration
    """
    resource_type = get_type(resource)
    if resource_type.startswith("Custom::"):
        return {
            **config.get("resources", {}).get("Custom"),
            "edges": list(resource["Properties"].keys())
        }
    return config.get("resources", {}) \
                .get(resource_type, UNSUPPORTED_RESOURCE_TYPE_CONFIG if default_config else None)

def parse_aws_cloud_formation_template(template_filename):
    with open(template_filename, encoding="utf-8") as stream:
        file_format = template_filename[template_filename.rfind(".")+1:]
        LOADER_FUNCTIONS = {
            "yml": yaml.full_load,
            "yaml": yaml.full_load,
            "json": json.load
        }
        try:
            data = LOADER_FUNCTIONS[file_format](stream)
        except KeyError:
            error(f"{template_filename} - Format {file_format} unsupported")
            return { "Resources": {} }
    for rname, resource in dict(data["Resources"]).items():
        if not isinstance(resource, dict):
            warning(f"Resources:{rname} - Type undefined")
            del data["Resources"][rname]
            if rname.startswith("Fn::ForEach::"):
                variable = resource[0]
                values = resource[1]
                resources = resource[2]
                for value in values:
                    for rid, rdata in resources.items():
                        rid = rid.replace("${" + variable +"}", value)
                        info(f"Resources:{rname} - Resources:{rid} added")
                        data["Resources"][rid] = rdata
    return data

# Directory where this script is.
DIRNAME = os.path.dirname(__file__)

# Load configuration.
config = {}
with open(DIRNAME + "/aws-cfn-diagrams.yaml", encoding="utf-8") as stream:
    config = yaml.safe_load(stream) # load YAML config file
    UNSUPPORTED_RESOURCE_TYPE_CONFIG = config["resources"]["Unsupported Resource Type"]

# Parse arguments
parser = argparse.ArgumentParser(
    prog="aws-cfn-diagrams",
    description="Generate AWS infrastructure diagrams from AWS CloudFormation templates")
parser.add_argument("filename",
    help="the AWS CloudFormation template to process")
parser.add_argument("-o", "--output", type=str,
    help="output diagram filename")
parser.add_argument("-f", "--format", type=str,
    help="output format, allowed formats are " \
        + ", ".join(SUPPORTED_OUTPUT_FORMATS) \
        + ", set to png by default",
    default="png")
parser.add_argument("--embed-all-icons",
    help="embed all icons into svg or dot_json output diagrams",
    action="store_true", default=False)
#TODO
#parser.add_argument("-v", "--version",
#    help="print the version",
#    action="store_true", default=False)
args = parser.parse_args()

# Process arguments.
if args.output is None:
    args.output = args.filename[:args.filename.rfind('.')]
else:
    dot_idx = args.output.rfind('.')
    if dot_idx != -1:
        args.format = args.output[dot_idx+1:]
        args.output = args.output[:dot_idx]

if args.format not in SUPPORTED_OUTPUT_FORMATS:
    SOF = "' or '".join(SUPPORTED_OUTPUT_FORMATS)
    print(f"Error: '{args.format}' output format unsupported,"
            f" use '{SOF}' instead!", file=sys.stderr)
    sys.exit(1)

is_d2_format = args.format == "d2"
if is_d2_format:
    d2_filename = args.output
    args.output = "/tmp/d2"
    args.format = "dot"

is_drawio_format = args.format == "drawio"
if is_drawio_format:
    drawio_filename = args.output
    args.output = "/tmp/drawio"
    args.format = "dot"

is_mermaid_format = args.format == "mermaid"
if is_mermaid_format:
    mermaid_filename = args.output
    args.output = "/tmp/mermaid"
    args.format = "dot"

aws_cloud_formation_filename = args.filename

# Open AWS CloudFormation file.
cloud_formation_data = parse_aws_cloud_formation_template(aws_cloud_formation_filename)

if "Parameters" not in cloud_formation_data:
    cloud_formation_data["Parameters"] = {}

#print("Parameters:")

for pname, pdata in cloud_formation_data["Parameters"].items():
    ptype = pdata["Type"]
    if ptype.startswith("List<") and ptype.endswith(">"):
        ptype = ptype[len("List<"):-1]
    elif ptype.startswith("AWS::SSM::Parameter::Value<") and ptype.endswith(">"):
        ptype = ptype[len("AWS::SSM::Parameter::Value<"):-1]
    if ptype.endswith("::Id"):
        rtype = ptype[:-4]
        if pname not in cloud_formation_data["Resources"]:
            info(f"Parameters:{pname} - Resource {pname}(Type: {rtype}) added")
            cloud_formation_data["Resources"][pname] = {
                "Type": rtype,
                "Properties": {}
            }
        else:
            info(f"Parameters:{pname} - Resource {pname} already defined")

#print("Resources:")
for rname, rdata in cloud_formation_data["Resources"].items():
    rtype = get_type(rdata)
#    print("-", rname, "Type", rtype)
    rconfig = get_config(rdata, None)
    if rconfig is None:
        warning(f"Resources:{rname} - Type '{rtype}' undefined in aws-cf-diagrams.yaml")

#
# Generate diagram
#

CNF_RESOURCE_ATTRIBUTE_PATTERN = re.compile(r"\$\{([A-Za-z][A-Za-z0-9]*)\.([A-Za-z0-9_.-]+)\}")

def generate_diagram(cloud_formation_data, aws_cloud_formation_filename):
    nodes = {}
    def generate_node(name, data) -> None:
        """
            Generate a node.
        """
        nodes[name] = create_diagram_node(name, data)

    def compute_edges(pname, pdata, the_nodes, property_path=None) -> None:
        """
            Compute edges.
        """
        if isinstance(pdata, (int, float, datetime.date)):
            pass # nothing to do
        elif isinstance(pdata, str):
            if pname == "Roles": # TODO: avoid specific cases
                for k, v in cloud_formation_data["Resources"].items():
                    if get_type(v) == "AWS::IAM::Role" \
                            and v["Properties"].get("RoleName") == pdata:
                        the_nodes.append([k, property_path])
                        return
#TBR            debug(f"{pname}: {pdata}")
            for match in CNF_RESOURCE_ATTRIBUTE_PATTERN.finditer(pdata):
                node = match.group(1)
                if node in cloud_formation_data["Resources"] or node in nodes:
                    the_nodes.append([node, property_path])
        elif isinstance(pdata, list):
            for data in pdata:
                compute_edges(pname, data, the_nodes, property_path)
        elif isinstance(pdata, dict):
            if pname == "Bucket": # TODO: avoid specific cases
                for k, v in cloud_formation_data["Resources"].items():
                    if get_type(v) == "AWS::S3::Bucket" \
                            and (v.get("Properties") or {}).get("BucketName") == pdata:
                        the_nodes.append([k, property_path])
                        return
            if len(pdata) == 1:
                if "Ref" in pdata:
                    node = pdata["Ref"]
                    if node in cloud_formation_data["Resources"] or node in nodes:
                        the_nodes.append([node, property_path])
                    return
                elif "Fn::GetAtt" in pdata:
                    node = pdata["Fn::GetAtt"][0]
                    if node in cloud_formation_data["Resources"] or node in nodes:
                        the_nodes.append([node, property_path])
                    return
                for k, v in pdata.items():
                    compute_edges(pname, v, the_nodes, f"{property_path}.{k}" if property_path is not None else k)
            else:
                for k, v in pdata.items():
                    compute_edges(pname, v, the_nodes, f"{property_path}.{k}" if property_path is not None else k)
        else:
            warning(f"[TODO] Resources:{rname}:Properties:{property_path} - {pdata} ({type(pdata)})")

    def process_edge_to(edge, pdata, nodes, property_path=None) -> None:
        """
            Process edge to.
        """
        if isinstance(edge, str):
            if isinstance(pdata, dict):
                if edge in pdata:
                    property_path = f"{property_path}.{edge}" if property_path is not None else edge
                    compute_edges(edge, pdata[edge], nodes, property_path)
            elif isinstance(pdata, list):
                for vv in pdata:
                    process_edge_to(edge, vv, nodes, property_path)
#           else:
#                        print("TODO", edge, pdata)
        elif isinstance(edge, dict):
            if isinstance(pdata, dict):
                for k, v in edge.items():
                    property_path = f"{property_path}.{k}" if property_path is not None else k
                    if k in pdata:
                        process_edge_to(v, pdata[k], nodes, property_path)
            elif isinstance(pdata, list):
                for vv in pdata:
                    process_edge_to(edge, vv, nodes, property_path)
        elif isinstance(edge, list):
            for v in edge:
                process_edge_to(v, pdata, nodes, property_path)
        else:
            warning(f"TODO process_edge_to {edge}")

    clusters = {}
    children = []
    for rname, rdata in cloud_formation_data["Resources"].items():
        rconfig = get_config(rdata)
        rkind = rconfig.get("kind", "node")
        if rkind == "cluster":
            clusters[rname] = {
                "is_root": rname not in children,
                "nodes": [],
                "style": rconfig.get("style", {})
            }
            rconfig_children = rconfig.get("children")
            if rconfig_children is not None:
                process_edge_to(
                    rconfig_children,
                    rdata.get("Properties") or {},
                    clusters[rname]["nodes"]
                )
                children.extend(clusters[rname]["nodes"])
                for n in clusters[rname]["nodes"]:
                    if n[0] in clusters:
                        clusters[n[0]]["is_root"] = False

    for rname, rdata in cloud_formation_data["Resources"].items():
        rconfig = get_config(rdata)
        pcp = rconfig.get("parents")
        if pcp is not None:
            parents = []
            process_edge_to(pcp, rdata["Properties"], parents)
            if len(parents) == 1 and parents[0][0] in clusters:
                clusters[parents[0][0]]["nodes"].append(rname)
                if rname in clusters:
                    clusters[rname]["is_root"] = False
            else:
                if rname not in clusters:
                    generate_node(rname, rdata)
        else:
            if rname not in children and rconfig.get("kind") == "node":
                generate_node(rname, rdata)

    def generate_cluster(cname, cdata):
        """
            Generate a cluster.
        """
        rdata = cloud_formation_data["Resources"][cname]
        if len(cdata["nodes"]) == 0 and get_type(rdata) != "Rain::Module":
            generate_node(cname, rdata)
            return

        # Generate a visual cluster only when there are several nodes inside.
        cluster_label = cname
        if not is_d2_format and not is_drawio_format and not is_mermaid_format and args.format != "dot_json":
            config = get_config(rdata)
            config_icon = config.get("icon", {})
            if "filename" in config_icon:
                cluster_label = label_with_icon(DIRNAME + "/" + config_icon["filename"], cname)
            elif "classname" in config_icon:
                cluster_label = label_with_icon(
                    get_icon_path(
                        get_diagram_class(
                            rdata
                        )
                    ),
                    cname
                )
        with Cluster(
            cluster_label,
            graph_attr={
                "tooltip": f"{cname}: {get_type(rdata)}",
                **compute_style(cdata["style"])
            }
        ) as cluster:
            cluster.dot.name = f"cluster_{cname}"
            if get_type(rdata) != "Rain::Module":
                generate_node(cname, rdata)

            # Deal with Rain::Module
            if get_type(rdata) == "Rain::Module":
                module_filename = os.path.dirname(aws_cloud_formation_filename) + "/" + rdata["Type"]["Rain::Module"]
                module_data = parse_aws_cloud_formation_template(
                    module_filename
                )
                module_nodes = generate_diagram(module_data, module_filename)
                for k, v in module_nodes.items():
                    nodes[cname + k] = v

            for rname in cdata["nodes"]:
                if isinstance(rname, list):
                    rname = rname[0]
                if rname in clusters:
                    generate_cluster(rname, clusters[rname])
                else:
                    rdata = cloud_formation_data["Resources"][rname]
                    kind = get_config(rdata).get("kind", "node")
                    if kind == "node":
                        generate_node(rname, rdata)

    for cname, cdata in clusters.items():
        if cdata["is_root"]:
            generate_cluster(cname, cdata)

    for rname, rdata in cloud_formation_data["Resources"].items():
        # Deal with Rain::Module
        if get_type(rdata) == "Rain::Module":
            for ko, vo in (rdata.get("Overrides") or {}).items():
                if isinstance(vo, dict):
                    depends_on = vo.get("DependsOn")
                    if isinstance(depends_on, str):
                        _ = nodes[rname+ko] >> Edge(**compute_style("DependsOn")) >> nodes[depends_on]
                    elif isinstance(depends_on, list):
                        for d in depends_on:
                            _ = nodes[rname+ko] >> Edge(**compute_style("DependsOn")) >> nodes[d]
            continue # next resource

        rconfig = get_config(rdata)
        kind = rconfig.get("kind", "node")
        edges = []
        if kind == "edge":
            def compute_nodes(properties, edge):
                """
                    Compute nodes.
                """
                nodes = []
                if isinstance(edge, str):
                    if edge in properties:
                        compute_edges(edge, properties[edge], nodes)
                elif isinstance(edge, list):
                    for f in edge:
                        if f in properties:
                            compute_edges(f, properties[f], nodes)
                else:
                    warning(f"[TODO] {edge}")
                return nodes

            rconfig_style = rconfig.get("style", {})
            tooltip = dump_resource(rname, rdata)
            for from_node in compute_nodes(rdata["Properties"], rconfig.get("from")):
                for to_node in compute_nodes(rdata["Properties"], rconfig.get("to")):
                    edges.append([from_node[0], [to_node[0], tooltip], rconfig_style])

        elif kind in ["node", "cluster"]:
            depends_on = rdata.get("DependsOn")
            if isinstance(depends_on, str):
                edges.append([rname, [depends_on, "DependsOn"], "DependsOn"])
            elif isinstance(depends_on, list):
                for d in depends_on:
                    edges.append([rname, [d, "DependsOn"], "DependsOn"])
            config_node_edges = rconfig.get("edges", [])
            to_nodes = []
            process_edge_to(config_node_edges, rdata.get("Properties") or {}, to_nodes)
            for to_node in to_nodes:
                edges.append([rname, to_node, "Reference"])

            other_nodes = []
            compute_edges(None, rdata.get("Properties") or {}, other_nodes)
            for other_node in other_nodes:
                if other_node not in to_nodes:
                    debug(f"Resources:{rname} - Other link to resource '{other_node}'")
                    edges.append([rname, other_node, "OtherLink"])

        for edge in edges:
            from_node = edge[0]
            to_node = edge[1][0]
            estyle = edge[2]
            if from_node not in nodes:
                warning(f"Resources:{rname} - No graphical node for resource '{from_node}'")
            elif to_node not in nodes:
                warning(f"Resources:{rname} - No graphical node for resource '{to_node}'")
            else:
#                debug(f"{from_node} connected to {to_node} via {edge[1][1]}")
                de = Edge(**compute_style(estyle), tooltip=edge[1][1])
                _ = nodes[from_node] >> de >> nodes[to_node]
    return nodes

with Diagram("", filename=args.output, show=False, direction="TB", outformat=args.format):
    generate_diagram(cloud_formation_data, aws_cloud_formation_filename)

generated_filename = f"{args.output}.{args.format}"
info(f"{generated_filename} generated")

if is_d2_format:
    convert_dot_to_d2(generated_filename, f"{d2_filename}.d2")
    os.remove(generated_filename)
    info(f"{d2_filename}.d2 generated")

if is_drawio_format:
    command = ["graphviz2drawio", generated_filename, "-o", f"{drawio_filename}.drawio"]
    info(f"Execute {' '.join(command)}", end="")
    subprocess.run(command)
    os.remove(generated_filename)
    info(f"{drawio_filename}.drawio generated")

if is_mermaid_format:
    convert_dot_to_mermaid(generated_filename, f"{mermaid_filename}.mermaid")
    os.remove(generated_filename)
    info(f"{mermaid_filename}.mermaid generated")

if args.format in ("svg", "dot_json"):
    FILENAME = f"{args.output}.{args.format}"
    info("Post-process paths of icons..")
    # read all the lines of the generated file
    with open(FILENAME, "rt", encoding="utf-8") as fs:
        lines = fs.readlines()
    if args.format == "svg":
        what_to_search = [
            r'image xlink:href="([^"]+)"',
        ]
    elif args.format == "dot_json":
        DIAGRAMS_PATH = DIAGRAMS_PATH.replace("/", "\\/")
        CFD_PATH = CFD_PATH.replace("/", "\\/")
        what_to_search = [
            r'"image": "([^"]+)"',
            r'img src=\\"([^"]+)\\"',
        ]
    else:
        what_to_search = []
    # rewrite all the lines of the generated file
    with open(FILENAME, "wt", encoding="utf-8") as fs:
        for line in lines:
            for wts in what_to_search:
                import re
                img_paths = re.findall(wts, line)
                for img_path in img_paths:
                    if not args.embed_all_icons:
                        # replace absolute paths by urls
                        if DIAGRAMS_PATH in line:
                            line = line.replace(DIAGRAMS_PATH, DIAGRAMS_URL)
                            continue
                        if CFD_PATH in line:
                            line = line.replace(CFD_PATH, CFD_URL)
                            continue
                    full_img_path = Path(img_path.replace("\\/", "/"))
                    if full_img_path.exists():
                        # read the image
                        with open(full_img_path, 'rb') as img_file:
                            img_data = img_file.read()
                        # encode the image in base64
                        import base64
                        MIME_TYPE = 'image/png'
                        b64_data = base64.b64encode(img_data).decode('ascii')
                        DATA_URI = f"data:{MIME_TYPE};base64,{b64_data}"
                        # replace absolute path by image encoded in base64
                        line = line.replace(img_path, DATA_URI)
                    else:
                        warning(f"Image not found: {full_img_path}")
            # write the line
            fs.write(line)
    info(f"{FILENAME} saved")







========================================



un exemple de code pour générer des diagrammes à partir de fichiers Bicep
yaml qui génére le code mermaid et png




    #
# Graphical styles
#

styles:

  #
  # Cluster styles
  #

  Compute:
    bgcolor: "#fff5e6"
  Database:
    bgcolor: "#e6ecff"
  IoT:
    bgcolor: "#e6ffee"
  Management:
    bgcolor: "#ffe6f2"
  Network:
    bgcolor: "#f2e6ff"
  Security:
    bgcolor: "#ffe6e6"
  Storage:
    bgcolor: "#e6ffe6"

  #
  # Edge styles
  #

  Association:
    color: black
    #dir: both
    forward: true
    reverse: true
  DependsOn:
    color: "#7B8894"
  Reference:
    color: black
  OtherLink:
    color: brown

#
# AWS resources
#

resources:

  #
  # AWS::ApiGateway resource types.
  #

  AWS::ApiGateway::Authorizer:
    kind: node
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - ProviderARNs
      - RestApiId
    parents: RestApiId

  AWS::ApiGateway::Deployment:
    kind: node
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - RestApiId
    parents: RestApiId

  AWS::ApiGateway::Method:
    kind: node
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - AuthorizerId
      - Integration:
          - Uri
      - RequestModels:
        - application/json
      - ResourceId
      - RestApiId
    parents: ResourceId

  AWS::ApiGateway::Model:
    kind: node
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - RestApiId
    parents: RestApiId

  AWS::ApiGateway::Resource:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - ParentId # ???
      - RestApiId
    parents: RestApiId

  AWS::ApiGateway::RestApi:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.APIGateway

  AWS::ApiGateway::Stage:
    kind: node
    icon:
      classname: diagrams.aws.network.APIGateway
    edges:
      - DeploymentId
      - RestApiId
    parents: RestApiId

  #
  # AWS::AppConfig resource types.
  #

  AWS::AppConfig::Application:
    kind: cluster
    style: Management
    icon:
      classname: diagrams.aws.management.SystemsManagerAppConfig

  AWS::AppConfig::ConfigurationProfile:
    kind: node
    icon:
      classname: diagrams.aws.management.SystemsManagerAppConfig
    edges:
      - ApplicationId
    parents:
      - ApplicationId

  AWS::AppConfig::DeploymentStrategy:
    kind: node
    icon:
      classname: diagrams.aws.management.SystemsManagerAppConfig

  AWS::AppConfig::Environment:
    kind: node
    icon:
      classname: diagrams.aws.management.SystemsManagerAppConfig
    edges:
      - ApplicationId
    parents:
      - ApplicationId

  #
  # AWS::ApplicationAutoScaling resource types.
  #

  AWS::ApplicationAutoScaling::ScalableTarget:
    kind: node
    icon:
      classname: diagrams.aws.compute.ApplicationAutoScaling
    edges:
      - ResourceId
      - RoleARN

  AWS::ApplicationAutoScaling::ScalingPolicy:
    kind: node
    icon:
      classname: diagrams.aws.compute.ApplicationAutoScaling
    edges:
      - ScalingTargetId

  #
  # AWS::AppRunner resource types.
  #

  AWS::AppRunner::Service:
    kind: node
    icon:
      classname: diagrams.aws.compute.AppRunner
    edges:
      - SourceConfiguration:
        - AuthenticationConfiguration:
          - AccessRoleArn

  #
  # AWS::AutoScaling resource types.
  #

  AWS::AutoScaling::AutoScalingGroup:
    kind: cluster
    style: Management
    icon:
      classname: diagrams.aws.management.AutoScaling
    edges:
      - LaunchConfigurationName
      - LaunchTemplate:
        - LaunchTemplateId
        - Version
      - LoadBalancerNames
      - NotificationConfigurations:
        - TopicARN
      - TargetGroupARNs
      - VPCZoneIdentifier

  AWS::AutoScaling::LaunchConfiguration:
    kind: node
    icon:
      classname: diagrams.aws.management.AutoScaling
    edges:
      - ImageId
      - IamInstanceProfile
      - SecurityGroups
    parents: SecurityGroups

  AWS::AutoScaling::ScalingPolicy:
    kind: node
    icon:
      classname: diagrams.aws.management.AutoScaling
    edges:
      - AutoScalingGroupName
    parents: AutoScalingGroupName

  AWS::AutoScaling::ScheduledAction:
    kind: node
    icon:
      classname: diagrams.aws.management.AutoScaling
    edges:
      - AutoScalingGroupName
    parents: AutoScalingGroupName

  #
  # AWS::CDK resource types.
  #

  AWS::CDK::Metadata:
    kind: node
    icon:
      classname: diagrams.aws.devtools.CloudDevelopmentKit

  #
  # AWS::CloudFormation resource types.
  #
  AWS::CloudFormation::Macro:
    kind: node
    icon:
      classname: diagrams.aws.management.Cloudformation
    edges:
      - FunctionName

  AWS::CloudFormation::Stack:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudformationStack
    edges:
      - Parameters

  AWS::CloudFormation::StackSet:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudformationStack
    edges:
      - Parameters:
        - ParameterValue

  AWS::CloudFormation::WaitConditionHandle:
    kind: node
    icon:
      classname: diagrams.aws.management.Cloudformation

  AWS::CloudFormation::WaitCondition:
    kind: node
    icon:
      classname: diagrams.aws.management.Cloudformation
    edges:
      - Handle

  #
  # AWS::CloudFront resource types.
  #

  AWS::CloudFront::CachePolicy:
    kind: node
    icon:
      classname: diagrams.aws.network.CloudFront
        
  AWS::CloudFront::Distribution:
    kind: node
    icon:
      classname: diagrams.aws.network.CloudFrontDownloadDistribution
    edges:
      - DistributionConfig:
        - CacheBehaviors:
          - CachePolicyId
          - OriginRequestPolicyId
          - TargetOriginId
        - DefaultCacheBehavior:
          - CachePolicyId
          - LambdaFunctionAssociations:
              - LambdaFunctionARN
          - OriginRequestPolicyId
          - TargetOriginId
        - Logging:
          - Bucket
        - Origins:
          - DomainName
          - Id
          - OriginAccessControlId
        - WebACLId

  AWS::CloudFront::OriginAccessControl:
    kind: node
    icon:
      classname: diagrams.aws.network.CloudFront

  #
  # AWS::CloudWatch resource types.
  #

  AWS::CloudWatch::Alarm:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudwatchAlarm
    edges:
      - AlarmActions
      - Dimensions:
        - Value
      - InsufficientDataActions
    parents:
      Dimensions:
        - Value

  AWS::CloudWatch::Dashboard:
    kind: node
    icon:
      classname: diagrams.aws.management.Cloudwatch

  #
  # AWS::CertificateManager resource types.
  #

  AWS::CertificateManager::Certificate:
    kind: node
    icon:
      classname: diagrams.aws.security.CertificateManager
    edges:
      - DomainValidationOptions:
        - HostedZoneId

  #
  # AWS::CodeBuild resource types.
  #

  AWS::CodeBuild::Project:
    kind: node
    icon:
      classname: diagrams.aws.devtools.Codebuild
    edges:
      - ServiceRole

  #
  # AWS::CodeCommit resource types.
  #

  AWS::CodeCommit::Repository:
    kind: node
    icon:
      classname: diagrams.aws.devtools.Codecommit

  #
  # AWS::CodePipeline resource types.
  #

  AWS::CodePipeline::Pipeline:
    kind: node
    icon:
      classname: diagrams.aws.devtools.Codepipeline
    edges:
      - RoleArn

  #
  # AWS::Cognito resource types.
  #

  AWS::Cognito::UserPool:
    kind: cluster
    style: Security
    icon:
      classname: diagrams.aws.security.Cognito

  AWS::Cognito::UserPoolDomain:
    kind: node
    icon:
      classname: diagrams.aws.security.Cognito
    edges:
      - UserPoolId
    parents: UserPoolId

  AWS::Cognito::UserPoolClient:
    kind: node
    icon:
      classname: diagrams.aws.security.Cognito
    edges:
      - CallbackURLs
      - UserPoolId
    parents: UserPoolId

  #
  # AWS::Config resource types.
  #

  AWS::Config::ConfigRule:
    kind: node
    icon:
      classname: diagrams.aws.management.Config
    edges:
      - Scope:
        - ComplianceResourceId
      - Source:
        - SourceIdentifier

  AWS::Config::ConfigurationRecorder:
    kind: node
    icon:
      classname: diagrams.aws.management.Config
    edges:
      - RoleARN

  AWS::Config::DeliveryChannel:
    kind: node
    icon:
      classname: diagrams.aws.management.Config
    edges:
      - S3BucketName
      - SnsTopicARN

  #
  # AWS::DataPipeline resource types.
  #

  AWS::DataPipeline::Pipeline:
    kind: node
    icon:
      classname: diagrams.aws.analytics.DataPipeline

  #
  # AWS::DirectoryService resource types.
  #

  AWS::DirectoryService::MicrosoftAD:
    kind: node
    icon:
      classname: diagrams.aws.security.DirectoryService
    edges:
      - VpcSettings:
        - SubnetIds
        - VpcId

  AWS::DirectoryService::SimpleAD:
    kind: node
    icon:
      classname: diagrams.aws.security.DirectoryService
    edges:
      - VpcSettings:
        - SubnetIds
        - VpcId

  #
  # AWS::DMS resource types.
  #

  AWS::DMS::Endpoint:
    kind: node
    icon:
      classname: diagrams.aws.database.DatabaseMigrationService
    edges:
      - S3Settings:
        - BucketName
        - ServiceAccessRoleArn
      - ServerName

  AWS::DMS::ReplicationInstance:
    kind: cluster
    style: Database
    icon:
      classname: diagrams.aws.database.DatabaseMigrationService
    edges:
      - AvailabilityZone
      - ReplicationSubnetGroupIdentifier
      - VpcSecurityGroupIds
    children:
      - ReplicationSubnetGroupIdentifier

  AWS::DMS::ReplicationSubnetGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.DatabaseMigrationService
    edges:
      - SubnetIds

  AWS::DMS::ReplicationTask:
    kind: cluster
    style: Database
    icon:
      classname: diagrams.aws.database.DatabaseMigrationService
    edges:
      - ReplicationInstanceArn
      - SourceEndpointArn
      - TargetEndpointArn
    children:
      - ReplicationInstanceArn
      - SourceEndpointArn
      - TargetEndpointArn

  #
  # AWS::DynamoDB resource types.
  #

  AWS::DynamoDB::Table:
    kind: node
    icon:
      classname: diagrams.aws.database.DynamodbTable

  #
  # AWS::EC2 resource types.
  #

  AWS::EC2::DHCPOptions:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2
    edges:
      - DomainNameServers

  AWS::EC2::EIP:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2ElasticIpAddress

  AWS::EC2::EIPAssociation:
    kind: edge
    style: Association
    from: AllocationId
    to:
      - InstanceId
      - NetworkInterfaceId

  AWS::EC2::EgressOnlyInternetGateway:
    kind: node
    icon:
      classname: diagrams.aws.network.InternetGateway
    edges:
      - VpcId
    parents: VpcId

  AWS::EC2::FlowLog:
    kind: node
    icon:
      classname: diagrams.aws.network.VPCFlowLogs
    edges:
      - DeliverLogsPermissionArn
      - LogDestination
      - LogGroupName
      - ResourceId
    parents: ResourceId

  AWS::EC2::Image:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2Ami

  AWS::EC2::Instance:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2Instance
    edges:
      - IamInstanceProfile
      - ImageId
      - NetworkInterfaces:
          - NetworkInterfaceId
          - SubnetId
      - SecurityGroupIds
      - SsmAssociations:
        - DocumentName
      - SubnetId
      - UserData
    parents:
      - SecurityGroupIds
      - SubnetId

  AWS::EC2::InternetGateway:
    kind: node
    icon:
      classname: diagrams.aws.general.InternetGateway

  AWS::EC2::LaunchTemplate:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2
    edges:
      - LaunchTemplateData:
          - ImageId
          - SecurityGroups
          - SecurityGroupIds
          - IamInstanceProfile:
            - Arn
            - Name
    parents:
      - LaunchTemplateData:
        - SecurityGroups
        - SecurityGroupIds

  AWS::EC2::NatGateway:
    kind: node
    icon:
      classname: diagrams.aws.network.NATGateway
    edges:
      - AllocationId
      - SubnetId
    parents: SubnetId

  AWS::EC2::NetworkAcl:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.Nacl
    edges:
      - VpcId
    parents: VpcId

  AWS::EC2::NetworkAclEntry:
    kind: node
    icon:
      classname: diagrams.aws.network.Nacl
    edges:
      - NetworkAclId
    parents: NetworkAclId

  AWS::EC2::NetworkInterface:
    kind: node
    icon:
      classname: diagrams.aws.network.VPCElasticNetworkInterface
    edges:
      - GroupSet
      - SubnetId
    parents:
      - GroupSet
      - SubnetId

  AWS::EC2::Route:
    kind: edge
    style: Association
    from:
      - NatGatewayId
      - GatewayId
    to: RouteTableId

  AWS::EC2::RouteTable:
    kind: node
    icon:
      classname: diagrams.aws.network.RouteTable
    edges:
      - VpcId
    parents: VpcId

  AWS::EC2::SecurityGroup:
    kind: cluster
    style: Compute
    icon:
      classname: diagrams.aws.compute.EC2
    edges:
      - GroupId
      - SourceSecurityGroupId
      - SecurityGroupIngress:
        - SourceSecurityGroupId
        - SourceSecurityGroupName
        - SourceSecurityGroupOwnerId
      - VpcId
    parents:
      - GroupId
      - SourceSecurityGroupId
#      - SecurityGroupIngress:
#        - SourceSecurityGroupId
#        - SourceSecurityGroupName
      - VpcId

  AWS::EC2::SecurityGroupEgress:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2
    edges:
      - GroupId
      - DestinationSecurityGroupId
    parents: GroupId

  AWS::EC2::SecurityGroupIngress:
    kind: node
    icon:
      classname: diagrams.aws.compute.EC2
    edges:
      - GroupId
      - SourceSecurityGroupId
    parents: GroupId

  AWS::EC2::Subnet:
    kind: cluster
    style: Network
    icon:
      classname:
        - when: MapPublicIpOnLaunch == False
          then: diagrams.aws.network.PrivateSubnet
        - then: diagrams.aws.network.PublicSubnet
    edges:
      - AvailabilityZone
      - Ipv6CidrBlock
      - VpcId
    parents: VpcId

  AWS::EC2::SubnetNetworkAclAssociation:
    kind: edge
    style: Association
    from: NetworkAclId
    to: SubnetId

  AWS::EC2::SubnetRouteTableAssociation:
    kind: edge
    style: Association
    from: SubnetId
    to: RouteTableId

  AWS::EC2::Volume:
    kind: node
    icon:
      classname: diagrams.aws.storage.ElasticBlockStoreEBSVolume

  AWS::EC2::VPC:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.VPC

  AWS::EC2::VPCDHCPOptionsAssociation:
    kind: edge
    style: Association
    from: VpcId
    to: DhcpOptionsId

  AWS::EC2::VPCCidrBlock:
    kind: node
    icon:
        classname: diagrams.aws.network.VPC
    edges:
      - VpcId
    parents: VpcId

  AWS::EC2::VPCEndpoint:
    kind: node
    icon:
        classname: diagrams.aws.network.Endpoint
    edges:
      - RouteTableIds
      - SecurityGroupIds
      - SubnetIds
      - VpcId
    parents: VpcId

  AWS::EC2::VPCEndpointService:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.VPC
    edges:
      - NetworkLoadBalancerArns
    parents: NetworkLoadBalancerArns

  AWS::EC2::VPCEndpointServicePermissions:
    kind: node
    icon:
      classname: diagrams.aws.network.VPC
    edges:
      - ServiceId
    parents: ServiceId

  AWS::EC2::VPCGatewayAttachment:
    kind: edge
    style: Association
    from: InternetGatewayId
    to: VpcId

  AWS::EC2::VPCPeeringConnection:
    kind: node
    icon:
      classname: diagrams.aws.network.VPCPeering
    edges:
      - VpcId
      - PeerVpcId
      - PeerOwnerId
      - PeerRoleArn
    parents: VpcId

  #
  # AWS::ECS resource types.
  #

  AWS::ECS::Cluster:
    kind: cluster
    style: Compute
    icon:
      classname: diagrams.aws.compute.ECS

  AWS::ECS::Service:
    kind: node
    icon:
      classname: diagrams.aws.compute.ElasticContainerServiceService
    edges:
      - Cluster
      - LoadBalancers:
        - TargetGroupArn
      - Role
      - TaskDefinition
    parents: Cluster

  AWS::ECS::TaskDefinition:
    kind: node
    icon:
      classname: diagrams.aws.compute.ECS
    edges:
      - ContainerDefinitions:
        - LogConfiguration:
          - Options:
              - awslogs-group

  #
  # AWS::EFS resource types.
  #
  
  AWS::EFS::FileSystem:
    kind: cluster
    style: Storage
    icon:
      classname: diagrams.aws.storage.ElasticFileSystemEFSFileSystem

  AWS::EFS::MountTarget:
    kind: node
    icon:
      classname: diagrams.aws.storage.EFS
    edges:
      - FileSystemId
      - SecurityGroups
      - SubnetId
    parents: FileSystemId

  AWS::EFS::AccessPoint:
    kind: node
    icon:
      classname: diagrams.aws.storage.EFS
    edges:
      - FileSystemId
    parents: FileSystemId

  #
  # AWS::EKS resource types.
  #

  AWS::EKS::Cluster:
    kind: cluster
    style: Compute
    icon:
      classname: diagrams.aws.compute.ElasticKubernetesService
    edges:
      - ResourcesVpcConfig:
          - SecurityGroupIds
          - SubnetIds
      - RoleArn
    parents:
      - ResourcesVpcConfig:
          - SecurityGroupIds
#          - SubnetIds

  AWS::EKS::Nodegroup:
    kind: node
    icon:
      classname: diagrams.aws.compute.ElasticKubernetesService
    edges:
      - ClusterName
      - Labels
      - LaunchTemplate:
         - Id
      - NodeRole
      - Subnets
    parents: ClusterName

  #
  # AWS::ElastiCache resource types.
  #

  AWS::ElastiCache::CacheCluster:
    kind: cluster
    style: Database
    icon:
      classname:
        - when: Engine == "redis"
          then: diagrams.aws.database.ElasticacheForRedis
        - when: Engine == "memcached"
          then: diagrams.aws.database.ElasticacheForMemcached
    edges:
      - VpcSecurityGroupIds
      - CacheSubnetGroupName
    children:
      - CacheSubnetGroupName

  AWS::ElastiCache::ParameterGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.Elasticache

  AWS::ElastiCache::ReplicationGroup:
    kind: cluster
    style: Database
    icon:
      classname: diagrams.aws.database.Elasticache
    edges:
      - CacheParameterGroupName
      - CacheSubnetGroupName
      - SecurityGroupIds
    children:
      - CacheParameterGroupName
      - CacheSubnetGroupName

  AWS::ElastiCache::SubnetGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.Elasticache
    edges:
      - SubnetIds

  #
  # AWS::ElasticLoadBalancing resource types.
  #

  AWS::ElasticLoadBalancing::LoadBalancer:
    kind: node
    icon:
      classname:
        - when: Type == "application"
          then: diagrams.aws.network.ElbApplicationLoadBalancer
        - then: diagrams.aws.network.ElasticLoadBalancing
    edges:
      - AccessLoggingPolicy:
        - S3BucketName
      - Instances
      - SecurityGroups
      - Subnets

  #
  # AWS::ElasticLoadBalancingV2 resource types.
  #

  AWS::ElasticLoadBalancingV2::Listener:
    kind: cluster
    style: Network
    icon:
      classname: diagrams.aws.network.ElasticLoadBalancing
    edges:
      - Certificates:
        - CertificateArn
      - DefaultActions:
        - TargetGroupArn
      - LoadBalancerArn
    parents: LoadBalancerArn

  AWS::ElasticLoadBalancingV2::ListenerRule:
    kind: node
    icon:
      classname: diagrams.aws.network.ElasticLoadBalancing
    edges:
      - Actions:
        - TargetGroupArn
      - ListenerArn
    parents: ListenerArn
  
  AWS::ElasticLoadBalancingV2::LoadBalancer:
    kind: cluster
    style: Network
    icon:
      classname:
        - when: Type == "network"
          then: diagrams.aws.network.ElbNetworkLoadBalancer
        - when: Type == "application"
          then: diagrams.aws.network.ElbApplicationLoadBalancer
        - then: diagrams.aws.network.ElasticLoadBalancing
    edges:
      - SecurityGroups
      - SubnetMappings:
        - AllocationId
        - SubnetId
      - Subnets

  AWS::ElasticLoadBalancingV2::TargetGroup:
    kind: node
    icon:
      classname: diagrams.aws.network.ElasticLoadBalancing
    edges:
      - Targets:
        - Id
      - VpcId
    parents: VpcId

  #
  # AWS::EMR resource types.
  #

  AWS::EMR::Cluster:
    kind: cluster
    icon:
      classname: diagrams.aws.analytics.EMRCluster
    edges:
      - Instances:
        - Ec2SubnetId
      - JobFlowRole
      - ServiceRole

  #
  # AWS::Events resource types.
  #

  AWS::Events::EventBus:
    kind: cluster
    style: Management
    icon:
      classname: diagrams.aws.integration.EventbridgeDefaultEventBusResource
    edges:
      - DeadLetterConfig:
        - Arn

  AWS::Events::EventBusPolicy:
    kind: node
    icon:
      classname: diagrams.aws.integration.Eventbridge
    edges:
      - EventBusName
    parents: EventBusName

  AWS::Events::Rule:
    kind: node
    icon:
      classname: diagrams.aws.integration.EventbridgeRule
    edges:
      - EventBusName
      - Targets:
        - Arn
        - DeadLetterConfig:
          - Arn
        - EcsParameters:
          - TaskDefinitionArn
        - RoleArn

  #
  # AWS::Greengrass resource types.
  #
        
  AWS::Greengrass::CoreDefinition:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotGreengrass

  AWS::Greengrass::CoreDefinitionVersion:
    kind: cluster
    style: IoT
    icon:
      classname: diagrams.aws.iot.IotGreengrass
    edges:
      - CoreDefinitionId
      - Cores:
        - CertificateArn
    children:
      - CoreDefinitionId

  AWS::Greengrass::FunctionDefinition:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotGreengrass
    edges:
      - InitialVersion:
        - Functions:
          - FunctionArn

  AWS::Greengrass::Group:
    kind: cluster
    style: IoT
    icon:
      classname: diagrams.aws.iot.IotGreengrass
    edges:
      - InitialVersion:
        - CoreDefinitionVersionArn
        - FunctionDefinitionVersionArn
        - SubscriptionDefinitionVersionArn
      - RoleArn
    children:
      - InitialVersion:
        - CoreDefinitionVersionArn
        - FunctionDefinitionVersionArn
        - SubscriptionDefinitionVersionArn

  AWS::Greengrass::SubscriptionDefinition:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotGreengrass
    edges:
      - InitialVersion:
        - Subscriptions

  #
  # AWS::IAM resource types.
  #

  AWS::IAM::InstanceProfile:
    kind: node
    icon:
      classname: diagrams.aws.security.IAM
    edges:
      - InstanceProfileName
      - Roles
    parents: Roles

  AWS::IAM::ManagedPolicy:
    kind: node
    icon:
      classname: diagrams.aws.security.IAM

  AWS::IAM::Role:
    kind: cluster
    style: Security
    icon:
      classname: diagrams.aws.security.IdentityAndAccessManagementIamRole
    edges:
      - ManagedPolicyArns
      - Policies:
        - PolicyDocument:
            - Statement:
              - Resource

  AWS::IAM::RolePolicy:
    kind: node
    icon:
      classname: diagrams.aws.security.IdentityAndAccessManagementIamRole
    edges:
      - PolicyDocument:
        - Statement:
          - Resource
      - RoleName
    parents: RoleName

  AWS::IAM::Policy:
    kind: node
    icon:
      classname: diagrams.aws.security.IAM
    edges:
      - Roles
    parents: Roles

  #
  # AWS::IoT resource types.
  #

  AWS::IoT::Policy:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotPolicy
    edges:
      - PolicyDocument:
        - Statement:
          - Resource

  AWS::IoT::PolicyPrincipalAttachment:
    kind: edge
    style: Association
    from: PolicyName
    to: Principal

  AWS::IoT::Thing:
    kind: node
    icon:
      classname: diagrams.aws.iot.InternetOfThings

  AWS::IoT::ThingPrincipalAttachment:
    kind: edge
    style: Association
    from: ThingName
    to: Principal

  AWS::IoT::TopicRule:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotRule
    edges:
      - TopicRulePayload:
        - Actions:
          - Lambda:
            - FunctionArn

  #
  # AWS::IoTAnalytics resource types.
  #

  AWS::IoTAnalytics::Channel:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotAnalyticsChannel

  AWS::IoTAnalytics::Dataset:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotAnalyticsDataSet

  AWS::IoTAnalytics::Datastore:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotAnalyticsDataStore

  AWS::IoTAnalytics::Pipeline:
    kind: node
    icon:
      classname: diagrams.aws.iot.IotAnalyticsPipeline

  #
  # AWS::KinesisFirehose resource types.
  #

  AWS::KinesisFirehose::DeliveryStream:
    kind: node
    icon:
      classname: diagrams.aws.analytics.KinesisDataFirehose
    edges:
      - ExtendedS3DestinationConfiguration:
        - CloudWatchLoggingOptions:
          - LogGroupName
          - LogStreamName
        - RoleARN
        # - BucketARN ?

  #
  # AWS::KMS resource types.
  #

  AWS::KMS::Alias:
    kind: node
    icon:
      classname: diagrams.aws.security.KeyManagementService
    edges:
      - TargetKeyId

  AWS::KMS::Key:
    kind: node
    icon:
      classname: diagrams.aws.security.KeyManagementService

  #
  # AWS::Lambda resource types.
  #

  AWS::Lambda::Function:
    kind: cluster
    style: Compute
    icon:
      classname: diagrams.aws.compute.LambdaFunction
    edges:
      - Role
      - VpcConfig:
          - SubnetIds
          - SecurityGroupIds
      - Environment
    parents:
      - VpcConfig:
          - SecurityGroupIds
          - SubnetIds

  AWS::Lambda::Permission:
    kind: node
    icon:
      classname: diagrams.aws.compute.Lambda
    edges:
      - FunctionName
      - SourceArn
    parents: FunctionName

  AWS::Lambda::Version:
    kind: node
    icon:
      classname: diagrams.aws.compute.Lambda
    edges:
      - FunctionName
    parents: FunctionName

  #
  # AWS::Logs resource types.
  #

  AWS::Logs::LogGroup:
    kind: cluster
    style: Management
    icon:
      classname: diagrams.aws.management.CloudwatchLogs
    edges:
      - KmsKeyId

  AWS::Logs::LogStream:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudwatchLogs
    edges:
      - LogGroupName
    parents: LogGroupName

  AWS::Logs::QueryDefinition:
    kind: node
    icon:
      classname: diagrams.aws.management.Cloudwatch

  AWS::Logs::ResourcePolicy:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudwatchLogs
    edges:
      - PolicyDocument

  AWS::Logs::SubscriptionFilter:
    kind: node
    icon:
      classname: diagrams.aws.management.CloudwatchLogs
    edges:
      - DestinationArn
      - LogGroupName
      - RoleArn

  #
  # AWS::Neptune resources.
  #

  AWS::Neptune::DBCluster:
    kind: cluster
    style: Database
    icon:
      classname: diagrams.aws.database.Neptune
    edges:
      - DBClusterParameterGroupName
      - DBSubnetGroupName
      - KmsKeyId
      - VpcSecurityGroupIds
    children:
      - DBClusterParameterGroupName
      - DBSubnetGroupName

  AWS::Neptune::DBInstance:
    kind: cluster
    style: Database
    icon:
      classname: diagrams.aws.database.Neptune
    edges:
      - DBClusterIdentifier
      - DBParameterGroupName
      - DBSubnetGroupName
    parents: DBClusterIdentifier
    children:
      - DBParameterGroupName

  AWS::Neptune::DBClusterParameterGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.Neptune

  AWS::Neptune::DBParameterGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.Neptune

  AWS::Neptune::DBSubnetGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.Neptune
    edges:
      - SubnetIds

  #
  # AWS::RDS resource types.
  #

  AWS::RDS::DBCluster:
    kind: cluster
    style: Database
    icon:
      classname:
        - when: Engine in ("aurora-mysql", "mysql")
          then: diagrams.aws.database.RDSMysqlInstance
        - when: Engine in ("aurora-postgresql", "postgres")
          then: diagrams.aws.database.RDSPostgresqlInstance
        - then: diagrams.aws.database.RDS
    edges:
      - DBSubnetGroupName
      - MasterUserPassword
      - VpcSecurityGroupIds
    children:
      - DBSubnetGroupName

  AWS::RDS::DBInstance:
    kind: cluster
    style: Database
    icon:
      classname:
        - when: (Engine or property(SourceDBInstanceIdentifier, "Engine")) == "mariadb"
          then: diagrams.aws.database.RDSMariadbInstance
        - when: (Engine or property(SourceDBInstanceIdentifier, "Engine")) in ("aurora-mysql", "mysql", "MySQL")
          then: diagrams.aws.database.RDSMysqlInstance
        - when: (Engine or property(SourceDBInstanceIdentifier, "Engine")) in ("custom-oracle-ee", "custom-oracle-ee-cdb", "oracle-ee", "oracle-ee-cdb", "oracle-se2", "oracle-se2-cdb")
          then: diagrams.aws.database.RDSOracleInstance
        - when: (Engine or property(SourceDBInstanceIdentifier, "Engine")) in ("aurora-postgresql", "postgres")
          then: diagrams.aws.database.RDSPostgresqlInstance
        - when: (Engine or property(SourceDBInstanceIdentifier, "Engine")) in ("custom-sqlserver-ee", "custom-sqlserver-se", "custom-sqlserver-web", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web")
          then: diagrams.aws.database.RDSSqlServerInstance
        - then: diagrams.aws.database.RDSInstance
    edges:
      - DBClusterIdentifier
      - DBParameterGroupName
      - DBSubnetGroupName
      - SourceDBInstanceIdentifier
      - VPCSecurityGroups
    parents:
      - SourceDBInstanceIdentifier
      - DBClusterIdentifier
      - VPCSecurityGroups
    children:
      - DBParameterGroupName

  AWS::RDS::DBParameterGroup:
    kind: node
    style: Database
    icon:
      classname: diagrams.aws.database.RDS

  AWS::RDS::DBSubnetGroup:
    kind: node
    icon:
      classname: diagrams.aws.database.RDS
    edges:
      - SubnetIds

  #
  # AWS::Route53 resource types.
  #

  AWS::Route53::HostedZone:
    kind: node
    icon:
      classname: diagrams.aws.network.Route53HostedZone

  #
  # AWS::S3 resource types.
  #

  AWS::S3::Bucket:
    kind: cluster
    style: Storage
    icon:
      classname: diagrams.aws.storage.SimpleStorageServiceS3Bucket
    edges:
      - BucketEncryption:
        - ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
            - KMSMasterKeyID
      - LoggingConfiguration:
        - DestinationBucketName
      - NotificationConfiguration:
        - LambdaConfigurations:
          - Function
      - ReplicationConfiguration:
        - Role
        - Rules:
          - Destination:
              - Bucket

  AWS::S3::BucketPolicy:
    kind: node
    icon:
      classname: diagrams.aws.storage.SimpleStorageServiceS3
    edges:
      - Bucket
      - PolicyDocument
    parents: Bucket

  AWS::S3::Object:
    kind: node
    icon:
      classname: diagrams.aws.storage.SimpleStorageServiceS3Object
    edges:
      - Source:
        - Bucket
        - Key
      - Target:
        - Bucket
    parents:
      - Target:
        - Bucket

  #
  # AWS::SecretsManager resource types.
  #

  AWS::SecretsManager::Secret:
    kind: node
    icon:
      classname: diagrams.aws.security.SecretsManager
    edges:
      - KmsKeyId

  AWS::SecretsManager::SecretTargetAttachment:
    kind: edge
    style: Association
    from: SecretId
    to: TargetId

  #
  # AWS::Serverless resource types.
  #

  AWS::Serverless::Function:
    kind: node
    icon:
      classname: diagrams.aws.compute.LambdaFunction
    edges:
      - Environment:
        - Variables

  #
  # AWS::ServiceCatalog resource types.
  #

  AWS::ServiceCatalog::CloudFormationProduct:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog

  AWS::ServiceCatalog::Portfolio:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog
    
  AWS::ServiceCatalog::PortfolioProductAssociation:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog
    edges:
      - ProductId

  AWS::ServiceCatalog::PortfolioShare:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog
    edges:
      - AccountId
      - PortfolioId

  AWS::ServiceCatalog::TagOption:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog

  AWS::ServiceCatalog::TagOptionAssociation:
    kind: node
    icon:
      classname: diagrams.aws.management.ServiceCatalog
    edges:
      - TagOptionId
      - ResourceId

  #
  # AWS::SNS resource types.
  #

  AWS::SNS::Topic:
    kind: node
    icon:
      classname: diagrams.aws.integration.SimpleNotificationServiceSnsTopic

  AWS::SNS::TopicPolicy:
    kind: node
    icon:
      classname: diagrams.aws.integration.SNS
    edges:
      - Topics

  AWS::SNS::Subscription:
    kind: node
    icon:
      classname: diagrams.aws.integration.SimpleNotificationServiceSns
    edges:
      - TopicArn

  #
  # AWS::SQS resource types.
  #

  AWS::SQS::Queue:
    kind: node
    icon:
      classname: diagrams.aws.integration.SimpleQueueServiceSqsQueue
    edges:
      - RedrivePolicy

  AWS::SQS::QueuePolicy:
    kind: node
    icon:
      classname: diagrams.aws.integration.SimpleQueueServiceSqs
    edges:
      - PolicyDocument:
        - Statement:
          - Resource
      - Queues

  #
  # AWS::SSM resource types.
  #

  AWS::SSM::Association:
    kind: node
    icon:
      classname: diagrams.aws.management.SSM
    edges:
      - Targets:
        - Values

  AWS::SSM::Document:
    kind: node
    icon:
      classname: diagrams.aws.management.SSM

  #
  # AWS::WAFv2 resource types.
  #

  AWS::WAFv2::WebACL:
    kind: node
    icon:
      classname: diagrams.aws.security.WAF

  #
  # Custom resources.
  #

  Custom:
    kind: node
    icon:
      classname: diagrams.aws.enablement.CustomerEnablement

  #
  # Rain resources.
  #

  Rain::Module:
    kind: cluster
    icon:
      filename: icons/Rain_Module.png
    style:
      bgcolor: "#F1FFE6"

  #
  # Boto3 resources.
  #
  Boto3::CodeCommit.put_file:
    kind: node
    icon:
      classname: diagrams.aws.devtools.Codecommit
    edges:
      - RepositoryName

  #
  # Unsupported resource types.
  #
  Unsupported Resource Type:
    kind: node
    icon:
      classname: diagrams.aws.general.General
    style:
      fontname: Courier New Bold
      fontcolor: orange