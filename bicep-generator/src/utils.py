import re

def slugify(text: str) -> str:
    """Convert text into a safe Bicep identifier (camelCase-ish)."""
    # Remove non-alphanumeric characters
    text = re.sub(r'[^a-zA-Z0-9]', '', text)
    if not text:
        return "resource"
    # Ensure it doesn't start with a number
    if text[0].isdigit():
        text = "r" + text
    return text
