from PIL import Image
import numpy as np

# Load image
img = Image.open('scripts/logo-converter/runner.png').convert('L')
img = img.resize((49,49))  # normalize grid

arr = np.array(img)

threshold = 98

dots = []
for y in range(arr.shape[0]):
    for x in range(arr.shape[1]):
        if arr[y,x] < threshold:
            dots.append((x,y))

# SVG params
dot_size = 4
spacing = 8
width = arr.shape[1]*spacing
height = arr.shape[0]*spacing

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">']
svg.append(f'<rect width="100%" height="100%" fill="black"/>')

for x,y in dots:
    cx = x*spacing + spacing/2
    cy = y*spacing + spacing/2
    svg.append(f'<circle cx="{cx}" cy="{cy}" r="{dot_size}" fill="white"/>')

svg.append('</svg>')

svg_content = "\n".join(svg)

file_path = "runner.svg"
with open(file_path, "w") as f:
    f.write(svg_content)

file_path