"""Conservative contrast and skew correction; input/output coordinates are explicit."""
import cv2
import numpy as np
from PIL import Image


def enhance_label(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    lab[:, :, 0] = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8)).apply(lab[:, :, 0])
    rgb = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 80, 180)
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 80, minLineLength=max(60, image.width // 5), maxLineGap=15)
    angles = []
    if lines is not None:
        for x1, y1, x2, y2 in lines[:, 0]:
            angle = np.degrees(np.arctan2(y2-y1, x2-x1))
            if abs(angle) <= 12:
                angles.append(angle)
    if len(angles) >= 4:
        angle = float(np.median(angles))
        if 0.5 < abs(angle) < 12:
            matrix = cv2.getRotationMatrix2D((image.width / 2, image.height / 2), angle, 1)
            rgb = cv2.warpAffine(rgb, matrix, image.size, borderMode=cv2.BORDER_REPLICATE)
    return Image.fromarray(rgb)
