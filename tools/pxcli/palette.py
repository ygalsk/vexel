"""Codecritter type palettes — 7 types, 6 colors each."""

PALETTES = {
    "DEBUG": {
        "outline": "#0A2E2E",
        "dark":    "#1A4A4A",
        "mid":     "#2E8A8A",
        "light":   "#50C8B0",
        "bright":  "#80E8D0",
        "eye":     "#E0F8F0",
    },
    "CHAOS": {
        "outline": "#2A0A0A",
        "dark":    "#5A1A1A",
        "mid":     "#A03030",
        "light":   "#D05050",
        "bright":  "#F08070",
        "eye":     "#F0E0D0",
    },
    "PATIENCE": {
        "outline": "#0A1A30",
        "dark":    "#1A3060",
        "mid":     "#3060A0",
        "light":   "#5090D0",
        "bright":  "#80B8E8",
        "eye":     "#E0F0F8",
    },
    "WISDOM": {
        "outline": "#1A0F30",
        "dark":    "#2D1B4E",
        "mid":     "#6B3FA0",
        "light":   "#B088D0",
        "bright":  "#D4B8E8",
        "eye":     "#E0D0F0",
    },
    "SNARK": {
        "outline": "#2B3A10",
        "dark":    "#4A5F20",
        "mid":     "#7BA830",
        "light":   "#A8D440",
        "bright":  "#D4F060",
        "eye":     "#F0F0E0",
    },
    "VIBE": {
        "outline": "#0A3320",
        "dark":    "#1A5A38",
        "mid":     "#30A060",
        "light":   "#60D088",
        "bright":  "#90F0B0",
        "eye":     "#E0F8E8",
    },
    "LEGACY": {
        "outline": "#1A1008",
        "dark":    "#3A2818",
        "mid":     "#7A5A30",
        "light":   "#B08848",
        "bright":  "#D0B068",
        "eye":     "#E0D8C0",
    },
}


def get_palette(type_name):
    """Return palette dict for a type. Raises KeyError if unknown."""
    return PALETTES[type_name.upper()]


def ramp(palette):
    """Return palette colors darkest-to-lightest (for shading reference)."""
    return [palette[k] for k in ("outline", "dark", "mid", "light", "bright", "eye")]
