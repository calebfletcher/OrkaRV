from enum import Enum
from pathlib import Path
from typing import List, Optional

import yaml
from pydantic import BaseModel, PositiveInt

class Protocol(str, Enum):
    axi4 = 'axi4'
    axi4lite = 'axi4lite'

class Soc(BaseModel):
    name: str

class Defaults(BaseModel):
    protocol: Protocol

class Master(BaseModel):
    name: str
    protocol: Optional[Protocol] = None

class Slave(BaseModel):
    name: str
    protocol: Optional[Protocol] = None
    base: PositiveInt
    size: PositiveInt

class MemorySpec(BaseModel):
    soc: Soc
    defaults: Defaults
    masters: List[Master]
    slaves: List[Slave]

# Validate slaves to ensure none of the address ranges overlap
def validate_overlap(spec: MemorySpec):
    for (i, slave) in enumerate(spec.slaves):
        for other_slave in spec.slaves[i+1:]:
            if slave.base < other_slave.base + other_slave.size and other_slave.base < slave.base + slave.size:
                raise RuntimeError(f"address ranges for {slave.name} and {other_slave.name} overlap")

def format_size(size: int) -> str:
    """Format size in human-readable format"""
    if size >= 1024 * 1024:
        return f"{size // (1024 * 1024)}MB"
    elif size >= 1024:
        return f"{size // 1024}KB"
    else:
        return f"{size}B"

def ascii_memory_map(spec: MemorySpec) -> str:
    """Generate an ASCII diagram of the memory map"""
    # Sort slaves by base address
    sorted_slaves = sorted(spec.slaves, key=lambda s: s.base)
    
    lines = []
    lines.append(f"Memory Map for {spec.soc.name}")
    lines.append("=" * 60)
    
    prev_end = 0
    for slave in sorted_slaves:
        end_addr = slave.base + slave.size
        
        # Show gap if there is one
        if slave.base > prev_end:
            lines.append(f"0x{prev_end:08X} +{'-' * 40}+")
            lines.append(f"           |{''.center(40)}|")
        
        # Show the memory region
        lines.append(f"0x{slave.base:08X} +{'-' * 40}+")
        name_with_size = f"{slave.name} ({format_size(slave.size)})"
        lines.append(f"           |{name_with_size.center(40)}|")
        
        prev_end = end_addr
    
    # Final line
    lines.append(f"0x{prev_end:08X} +{'-' * 40}+")
    
    return "\n".join(lines)

if __name__ == "__main__":
    proj_path = Path(__file__).resolve().parent.parent.parent
    with open(proj_path / "shared/hdl/memory.yaml") as file:
        spec_yaml = yaml.full_load(file)
    spec = MemorySpec(**spec_yaml)
    print(spec)

    validate_overlap(spec)
    
    # Display ASCII memory map
    print("\n" + ascii_memory_map(spec))
