#!/usr/bin/env python3
"""
Merge 13 n8n sub-workflow JSON files into a single combined workflow JSON.

Strategy:
- Prefix colliding node names with the workflow number (e.g., "01-")
- Shift each workflow's nodes vertically by 800px per workflow index
- Merge all nodes and connections into one top-level object
- Do NOT modify any node parameters, types, or logic
"""

import json
import copy
import os

WORKFLOWS_DIR = "/home/andrew/workflow/eluxr-v2/workflows"
OUTPUT_PATH = "/mnt/c/Users/Andrew/OneDrive/Desktop/eluxr v1/v3 version dev/eluxr-social-media-action-v3.json"

INPUT_FILES = [
    "01-icp-analyzer.json",
    "02-theme-generator.json",
    "03-themes-list.json",
    "04-content-studio.json",
    "05-content-submit.json",
    "06-approval-list.json",
    "07-approval-action.json",
    "08-clear-pending.json",
    "09-calendar-sync.json",
    "10-chat.json",
    "11-image-generator.json",
    "12-video-script-builder.json",
    "13-video-creator.json",
]

# Vertical spacing between each workflow's group of nodes (in n8n canvas units)
Y_SPACING = 800


def load_workflow(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def find_all_name_collisions(workflows):
    """Return a set of node names that appear in more than one workflow."""
    name_count = {}
    for _prefix, wf in workflows:
        for node in wf.get("nodes", []):
            name = node["name"]
            name_count[name] = name_count.get(name, 0) + 1
    return {name for name, count in name_count.items() if count > 1}


def build_name_map(prefix, nodes, colliding_names):
    """
    Build a mapping from original node name -> new node name.
    Only colliding names get the prefix applied.
    """
    mapping = {}
    for node in nodes:
        orig = node["name"]
        if orig in colliding_names:
            mapping[orig] = f"{prefix}{orig}"
        else:
            mapping[orig] = orig
    return mapping


def rename_connections(connections, name_map):
    """
    Rewrite a connections dict applying name_map to both source keys and
    target node references inside the connection entries.
    """
    new_connections = {}
    for src_name, outputs in connections.items():
        new_src = name_map.get(src_name, src_name)
        new_outputs = {}
        for output_type, output_list in outputs.items():
            new_output_list = []
            for targets in output_list:
                new_targets = []
                for target in targets:
                    new_target = dict(target)
                    new_target["node"] = name_map.get(target["node"], target["node"])
                    new_targets.append(new_target)
                new_output_list.append(new_targets)
            new_outputs[output_type] = new_output_list
        new_connections[new_src] = new_outputs
    return new_connections


def shift_nodes_y(nodes, y_offset):
    """Return a deep copy of nodes with y positions shifted by y_offset."""
    shifted = []
    for node in nodes:
        n = copy.deepcopy(node)
        x, y = n["position"]
        n["position"] = [x, y + y_offset]
        shifted.append(n)
    return shifted


def merge_workflows(workflows_dir, input_files, output_path, y_spacing=800):
    # Load all workflows with their numeric prefix (e.g., "01-")
    loaded = []
    for filename in input_files:
        prefix = filename[:3]  # e.g., "01-"
        filepath = os.path.join(workflows_dir, filename)
        wf = load_workflow(filepath)
        loaded.append((prefix, wf, filename))
        print(f"  Loaded {filename}: {len(wf.get('nodes', []))} nodes, "
              f"{len(wf.get('connections', {}))} connection sources")

    # Find all node names that collide across workflows
    colliding_names = find_all_name_collisions(
        [(prefix, wf) for prefix, wf, _ in loaded]
    )
    print(f"\nColliding node names that will be prefixed ({len(colliding_names)}):")
    for name in sorted(colliding_names):
        print(f"  \"{name}\"")

    # Merge
    combined_nodes = []
    combined_connections = {}

    for i, (prefix, wf, filename) in enumerate(loaded):
        y_offset = i * y_spacing
        nodes = wf.get("nodes", [])
        connections = wf.get("connections", {})

        # Build rename map for this workflow
        name_map = build_name_map(prefix, nodes, colliding_names)

        # Apply renames and y shift to nodes
        renamed_nodes = []
        for node in nodes:
            n = copy.deepcopy(node)
            n["name"] = name_map[n["name"]]
            renamed_nodes.append(n)

        shifted_nodes = shift_nodes_y(renamed_nodes, y_offset)
        combined_nodes.extend(shifted_nodes)

        # Apply renames to connections
        renamed_connections = rename_connections(connections, name_map)
        # Merge into combined (keys should now be unique after prefixing)
        for src, targets in renamed_connections.items():
            if src in combined_connections:
                print(f"  WARNING: connection source '{src}' already exists — skipping duplicate from {filename}")
            else:
                combined_connections[src] = targets

        print(f"  Workflow {prefix.rstrip('-'):>2} → y_offset={y_offset:>6}px  "
              f"({len(shifted_nodes)} nodes, {len(renamed_connections)} connection sources)")

    # Build final combined workflow object
    combined_workflow = {
        "name": "ELUXR Social Media Action v3",
        "nodes": combined_nodes,
        "connections": combined_connections,
        "settings": {
            "executionOrder": "v1"
        },
        "active": False,
    }

    # Write output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(combined_workflow, f, indent=2, ensure_ascii=False)

    print(f"\nCombined workflow written to:\n  {output_path}")
    print(f"  Total nodes:              {len(combined_nodes)}")
    print(f"  Total connection sources: {len(combined_connections)}")
    return combined_workflow


if __name__ == "__main__":
    print("Merging 13 n8n sub-workflows...\n")
    result = merge_workflows(WORKFLOWS_DIR, INPUT_FILES, OUTPUT_PATH, Y_SPACING)
    print("\nDone.")
