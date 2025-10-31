#!/usr/bin/env python3
"""
Flatten nested JSON structures.
Converts nested objects like {"a": {"b": "c"}} to {"a.b": "c"}
"""

import json
import sys
from typing import Any, Dict


def flatten_json(data: Any, parent_key: str = '', separator: str = '.') -> Dict[str, Any]:
    """
    Flatten a nested JSON structure.

    Args:
        data: The JSON data to flatten (dict, list, or primitive)
        parent_key: The base key to prepend to nested keys
        separator: The separator to use between nested key levels (default: '.')

    Returns:
        A flattened dictionary
    """
    items = []

    if isinstance(data, dict):
        for key, value in data.items():
            new_key = f"{parent_key}{separator}{key}" if parent_key else key

            if isinstance(value, (dict, list)):
                items.extend(flatten_json(value, new_key, separator).items())
            else:
                items.append((new_key, value))

    elif isinstance(data, list):
        for index, value in enumerate(data):
            new_key = f"{parent_key}{separator}{index}" if parent_key else str(index)

            if isinstance(value, (dict, list)):
                items.extend(flatten_json(value, new_key, separator).items())
            else:
                items.append((new_key, value))

    else:
        items.append((parent_key, data))

    return dict(items)


def main():
    if len(sys.argv) < 2:
        print("Usage: flatten_json.py <input_file.json> [output_file.json]")
        print("\nIf output_file is not provided, results will be printed to stdout")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        # Read input JSON file
        with open(input_file, 'r') as f:
            data = json.load(f)

        # Flatten the JSON
        # If top-level is a list, flatten each item individually
        if isinstance(data, list):
            flattened = [flatten_json(item) for item in data]
        else:
            flattened = flatten_json(data)

        # Output results
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(flattened, f, indent=2)
            print(f"Flattened JSON written to {output_file}")
        else:
            print(json.dumps(flattened, indent=2))

    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{input_file}': {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
