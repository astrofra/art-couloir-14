import cv2
import numpy as np
import os
from PIL import Image

def print_progress_bar(iteration, total, prefix='', suffix='', length=50, fill='█'):
    percent = ("{0:.1f}").format(100 * (iteration / float(total)))
    filled_length = int(length * iteration // total)
    bar = fill * filled_length + '-' * (length - filled_length)
    print(f'\r{prefix} |{bar}| {percent}% {suffix}', end="\r")
    if iteration == total:
        print()


def downsize_image_naive(image, steps=3):
    for _ in range(steps):
        image = cv2.pyrDown(image)
    return image

# weighted implementation
def downsize_image_weighted(image, steps=3):
    # Convert to YUV color space
    yuv_image = cv2.cvtColor(image, cv2.COLOR_BGR2YUV)
    y, u, v = cv2.split(yuv_image)

    for _ in range(steps):
        # Calculate weights based on luminance
        weights = y / 255.0

        # Weighted average for downsizing (for simplicity, a 2x2 block is considered)
        for row in range(0, y.shape[0], 2):
            for col in range(0, y.shape[1], 2):
                if row + 1 < y.shape[0] and col + 1 < y.shape[1]:
                    block_weights = weights[row:row+2, col:col+2]
                    block_sum = np.sum(block_weights)
                    if block_sum > 0:
                        for channel in [y, u, v]:
                            weighted_avg = np.sum(channel[row:row+2, col:col+2] * block_weights) / block_sum
                            channel[row//2, col//2] = weighted_avg
                    else:
                        for channel in [y, u, v]:
                            channel[row//2, col//2] = 0

        # Resize each channel
        y = cv2.resize(y, (y.shape[1] // 2, y.shape[0] // 2))
        u = cv2.resize(u, (u.shape[1] // 2, u.shape[0] // 2))
        v = cv2.resize(v, (v.shape[1] // 2, v.shape[0] // 2))

    # Merge channels and convert back to BGR
    yuv_image = cv2.merge([y, u, v])
    resized_image = cv2.cvtColor(yuv_image, cv2.COLOR_YUV2BGR)

    return resized_image


def downsize_image(image, frame_index, steps=5, kernel_size=(3, 3), debug_folder='tmp'):
    # Create the debug folder if it doesn't exist
    if not os.path.exists(debug_folder):
        os.makedirs(debug_folder)

    # Crop the image to keep only the middle portion (25% to 75% in both X and Y)
    height, width = image.shape[:2]
    fmin = 0.1
    fmax = 1.0 - fmin
    yoffset = 0.0 # -0.15
    start_x, end_x = int(width * fmin), int(width * fmax)
    start_y, end_y = int(height * fmin + height * yoffset), int(height * fmax + height * yoffset)
    image = image[start_y:end_y, start_x:end_x]

    for step in range(steps):
        # Apply a maximum filter
        max_filtered = cv2.dilate(image, np.ones(kernel_size, np.uint8))
        # Downsize the image
        image = cv2.pyrDown(max_filtered)

    # Save the downsized image for debugging
    debug_image_path = os.path.join(debug_folder, f'frame_{frame_index}_step_{step}.png')
    cv2.imwrite(debug_image_path, image)

    return image


def extract_average_colors_and_metadata(video_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise Exception(f"Could not open video {video_path}")

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    duration_seconds = total_frames / fps
    colors = []

    for frame_idx in range(total_frames):
        ret, frame = cap.read()
        if not ret:
            break

        small_frame = downsize_image(frame, frame_idx)
        small_frame_rgb = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)

        # Get frame dimensions
        height, width = small_frame.shape[:2]

        # Calculate positions for sampling
        sy = 0.30 # how far from the borders of the image ?
        px0, px1, px2, px3 = int(width * 0.1), int(width * 0.3333), int(width * 0.6666), int(width * 0.9)
        py0 = int(height * sy)

        frame_colors = [
            [int(val) for val in small_frame_rgb[py0, px0]],  # Position 0.1
            [int(val) for val in small_frame_rgb[py0, px1]],  # Position 0.3333
            [int(val) for val in small_frame_rgb[py0, px2]],  # Position 0.6666
            [int(val) for val in small_frame_rgb[py0, px3]]   # Position 0.9
        ]

        colors.append(frame_colors)
        print_progress_bar(frame_idx + 1, total_frames, prefix='Progress:', suffix='Complete', length=50)

    cap.release()
    return {
        "colors": colors,
        "metadata": {
            "total_frames": total_frames,
            "duration_seconds": duration_seconds,
            "fps": fps
        }
    }


def generate_debug_image(colors, output_image_file):
    # Each frame will be represented as a single row of pixels, with 4 columns
    img_height = len(colors)
    img_width = 64
    debug_image = Image.new('RGB', (img_width, img_height))

    for i, frame_colors in enumerate(colors):
        # Each color in its own column
        for j, color in enumerate(frame_colors):
            for x in range(j * img_width // 4, (j + 1) * img_width // 4):
                debug_image.putpixel((x, i), tuple(color))

    debug_image.save(output_image_file)


def process_video(video_filename, folder_path, output_lua_file):
    video_file = os.path.join(folder_path, video_filename)
    video_data = extract_average_colors_and_metadata(video_file)

    lua_filename = os.path.join(output_lua_file, video_filename.replace('.mp4', '.lua'))
    lua_data = 'video_data = ' + str(video_data).replace('[', '{').replace(']', '}').replace('\'', '').replace(':', ' =')

    with open(lua_filename, 'w') as lua_file:
        lua_file.write(lua_data)

    # Generate debug image
    debug_image_filename = os.path.join(output_lua_file, video_filename.replace('.mp4', '_debug.png'))
    generate_debug_image(video_data["colors"], debug_image_filename)
    print(f"Debug image saved in {debug_image_filename}")

    return lua_filename

# Path to the folder containing the videos
video_folder = "../../assets/videos"
# Path to the Lua output file
output_lua_file = "../../"

# Process videos and save data
processed_file = process_video("dashcam_day_night.mp4", video_folder, output_lua_file)
print(f"Processed video data saved in {processed_file}")
