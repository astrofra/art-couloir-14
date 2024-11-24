import os
import json
import numpy as np
from PIL import Image, ImageDraw

# Path to folders
folders_path = "../../assets/photos/"
output_lua_path = "output_colors.lua"

# Coordinates and radius for sampling
areas = [
    (230, 1200),
    (1060, 1400),
    (600, 1140),
    (750, 750),
]
radius = 64

def circle_mask(image_shape, center, radius):
    """Generate a circular mask for a given center and radius."""
    mask = np.zeros(image_shape[:2], dtype=bool)
    y, x = np.ogrid[:image_shape[0], :image_shape[1]]
    distance = (x - center[0])**2 + (y - center[1])**2
    mask[distance <= radius**2] = True
    return mask

def process_image(image_path, debug_folder):
    """Process a single PNG image."""
    with Image.open(image_path) as img:
        img = img.convert("RGB")  # Ensure the image is in RGB mode
        np_img = np.array(img)
        colors = []

        # Create debug image (resized 512x512)
        debug_img = Image.new("RGB", (512, 512), "black")
        draw = ImageDraw.Draw(debug_img)
        scale_factor = 512 / img.width

        for idx, (x, y) in enumerate(areas):
            mask = circle_mask(np_img.shape, (x, y), radius)
            sampled_pixels = np_img[mask]

            # Calculate mean and median
            mean_color = sampled_pixels.mean(axis=0).astype(int)
            median_color = np.median(sampled_pixels, axis=0).astype(int)
            mixed_color = (mean_color + median_color) // 2

            colors.append(tuple(mixed_color))

            # Draw the circle on the debug image
            debug_x, debug_y = int(x * scale_factor), int(y * scale_factor)
            debug_radius = int(radius * scale_factor)
            draw.ellipse(
                [
                    (debug_x - debug_radius, debug_y - debug_radius),
                    (debug_x + debug_radius, debug_y + debug_radius),
                ],
                fill=tuple(mixed_color)
            )

        # Save debug image
        debug_image_path = os.path.join(debug_folder, os.path.basename(image_path))
        debug_img.save(debug_image_path)

        return colors

def main():
    lua_table = {}

    # Iterate through each folder
    for folder_name in os.listdir(folders_path):
        folder_path = os.path.join(folders_path, folder_name)
        if not os.path.isdir(folder_path):
            continue

        lua_table[folder_name] = {}

        debug_folder = os.path.join(folder_path, "debug")
        os.makedirs(debug_folder, exist_ok=True)

        # Iterate through each PNG file in the folder
        for file_name in os.listdir(os.path.join(folder_path, "slides")):
            if file_name.lower().endswith(".png"):
                file_path = os.path.join(folder_path, "slides", file_name)

                # Process the image and store its colors
                colors = process_image(file_path, debug_folder)
                lua_table[folder_name][file_name] = colors

    # Write the Lua table to a file
    with open(output_lua_path, "w") as lua_file:
        lua_file.write("return ")
        lua_file.write(json.dumps(lua_table, indent=4))

if __name__ == "__main__":
    main()
