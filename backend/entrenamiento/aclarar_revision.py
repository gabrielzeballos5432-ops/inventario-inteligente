"""Aclara solo las hojas de revision; no cambia las imagenes de entrenamiento."""

from pathlib import Path

from PIL import Image, ImageEnhance


RAIZ = Path(__file__).resolve().parents[2]
carpeta = RAIZ / "dataset" / "videos_nuevos_20261031"
for nombre in ["iluminador_oscuro", "sombra_negro"]:
    origen = carpeta / f"resumen_{nombre}.jpg"
    with Image.open(origen) as imagen:
        imagen = imagen.point(lambda valor: round(255 * (valor / 255) ** 0.45))
        imagen = ImageEnhance.Contrast(imagen).enhance(1.2)
        imagen.save(carpeta / f"resumen_aclarado_{nombre}.jpg")
