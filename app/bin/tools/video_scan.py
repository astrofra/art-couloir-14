import os
from moviepy.editor import VideoFileClip

# Extract the length of each video

# Path to the folder containing the videos
video_folder = "../../assets/videos"
# Path to the Lua output file
output_lua_file = "../../video_data.lua"

# Dictionary to store video data
video_data = {}

# Iterate over the folder to find .MP4 files
for filename in os.listdir(video_folder):
    if filename.lower().endswith(".mp4"):
        full_path = os.path.join(video_folder, filename)
        try:
            # Calculate the video duration
            with VideoFileClip(full_path) as video:
                duration = video.duration
            # Add the data to the dictionary
            video_data[filename] = duration
            print(f"Processed {filename}: Duration = {duration} seconds")
        except Exception as e:
            print(f"Error processing file {filename}: {e}")

# Write the data to a Lua file
with open(output_lua_file, 'w') as lua_file:
    lua_file.write("video_data = {\n")
    for video_name, length in video_data.items():
        lua_file.write(f"\t['{video_name}'] = {length},\n")
    lua_file.write("}\n")

print("Video data has been written to", output_lua_file)
