from __future__ import annotations

import hashlib
from dataclasses import dataclass
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError


class ImageValidationError(ValueError):
    pass


@dataclass(frozen=True)
class PreparedImage:
    original_hash: str
    bytes: bytes
    image_format: str
    width: int
    height: int
    original_size_bytes: int
    processed_size_bytes: int
    compressed: bool


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def prepare_image(
    image_bytes: bytes,
    max_upload_mb: int,
    max_image_mb: int,
    max_long_edge: int,
    jpeg_quality: int,
) -> PreparedImage:
    if not image_bytes:
        raise ImageValidationError("empty image")

    max_upload_bytes = max_upload_mb * 1024 * 1024
    if len(image_bytes) > max_upload_bytes:
        raise ImageValidationError(f"upload too large: max {max_upload_mb}MB")

    original_hash = sha256_bytes(image_bytes)
    try:
        image = Image.open(BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image)
        image.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise ImageValidationError("unsupported or broken image file") from exc

    if image.width < 32 or image.height < 32:
        raise ImageValidationError("image is too small")

    image = image.convert("RGB")
    scale = min(1.0, max_long_edge / max(image.width, image.height))
    compressed = scale < 1.0
    if scale < 1.0:
        image = image.resize(
            (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
            Image.Resampling.LANCZOS,
        )

    quality = jpeg_quality
    max_image_bytes = max_image_mb * 1024 * 1024
    output = BytesIO()
    image.save(output, format="JPEG", quality=quality, optimize=True)
    processed = output.getvalue()

    while len(processed) > max_image_bytes and quality > 55:
        quality -= 10
        output = BytesIO()
        image.save(output, format="JPEG", quality=quality, optimize=True)
        processed = output.getvalue()
        compressed = True

    if len(processed) > max_image_bytes:
        raise ImageValidationError(f"processed image too large for OCR: max {max_image_mb}MB")

    return PreparedImage(
        original_hash=original_hash,
        bytes=processed,
        image_format="jpg",
        width=image.width,
        height=image.height,
        original_size_bytes=len(image_bytes),
        processed_size_bytes=len(processed),
        compressed=compressed or len(processed) != len(image_bytes),
    )
