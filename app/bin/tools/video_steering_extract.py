import cv2
import numpy as np
import os

def process_video(video_filename, folder_path, output_lua_file):
    video_file = os.path.join(folder_path, video_filename)

    # Estimate steering angles
    steering_angles = estimate_steering_angles(video_file)

    # Prepare Lua filename
    lua_filename = os.path.join(output_lua_file, video_filename.replace('.mp4', '_steering.lua'))

    # Save data to Lua file
    lua_data = 'steering_angles = ' + str(steering_angles).replace('[', '{').replace(']', '}')

    with open(lua_filename, 'w') as lua_file:
        lua_file.write(lua_data)

    return lua_filename

def estimate_steering_angles(video_path):
    # Parameters for ShiTomasi corner detection
    feature_params = dict(maxCorners=100, qualityLevel=0.3, minDistance=7, blockSize=7)

    # Parameters for Lucas-Kanade optical flow
    lk_params = dict(winSize=(15, 15), maxLevel=2, criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03))

    # Load video
    cap = cv2.VideoCapture(video_path)
    ret, old_frame = cap.read()
    if not ret:
        raise Exception("Failed to read video")

    # Convert to grayscale
    old_gray = cv2.cvtColor(old_frame, cv2.COLOR_BGR2GRAY)
    p0 = cv2.goodFeaturesToTrack(old_gray, mask=None, **feature_params)

    steering_angles = []

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Calculate optical flow
        p1, st, err = cv2.calcOpticalFlowPyrLK(old_gray, frame_gray, p0, None, **lk_params)

        # Select good points and calculate movement
        if p1 is not None:
            good_new = p1[st == 1]
            good_old = p0[st == 1]
            dx = np.mean(good_new[:, 0] - good_old[:, 0])  # Average horizontal movement

            # Estimate steering angle (this is a very rough approximation)
            steering_angle = np.arctan2(dx, frame.shape[1])  # Using arctan2 as a simple example
            steering_angles.append(steering_angle)

        # Update the previous frame and previous points
        old_gray = frame_gray.copy()
        p0 = good_new.reshape(-1, 1, 2)

    cap.release()
    return steering_angles

def save_steering_angles_to_lua(angles, lua_filename):
    lua_data = 'steering_angles = ' + str(angles).replace('[', '{').replace(']', '}')

    with open(lua_filename, 'w') as lua_file:
        lua_file.write(lua_data)

# Path to the folder containing the videos
video_folder = "../../assets/videos"
# Path to the Lua output file
output_lua_file = "../../"

# Process videos and save data
processed_file = process_video("dashcam_day_night.mp4", video_folder, output_lua_file)
print(f"Processed video data saved in {processed_file}")
