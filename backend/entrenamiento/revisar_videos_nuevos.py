"""Prepara muestras originales de cada grabacion para revisar clases y cajas."""

import argparse
import hashlib
import json
import math
from pathlib import Path

import cv2

from preparar_fotogramas import escribir_jpg, hoja_contacto


RAIZ = Path(__file__).resolve().parents[2]
CLASES = {
    "iluminador": [0],
    "sombra": [1],
    "ambos": [0, 1],
    "sin_productos": [],
}


def revisar(destino: Path) -> None:
    videos = sorted(p for p in RAIZ.glob("*.mp4") if p.stem.startswith(tuple(CLASES)))
    if not videos:
        raise FileNotFoundError("No hay grabaciones reconocibles en la raiz.")
    destino.mkdir(parents=True, exist_ok=False)
    registros = []
    for video in videos:
        prefijo = next(c for c in CLASES if video.stem.startswith(c))
        cap = cv2.VideoCapture(str(video))
        try:
            if not cap.isOpened():
                raise RuntimeError(f"No se pudo abrir {video}")
            fps = cap.get(cv2.CAP_PROP_FPS)
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            if not math.isfinite(fps) or fps <= 0 or total <= 0:
                raise ValueError(f"Metadatos invalidos: {video}")
            carpeta = destino / video.stem
            carpeta.mkdir()
            fotos = []
            for segundo in range(math.ceil(total / fps)):
                indice = round(segundo * fps)
                if indice >= total:
                    break
                cap.set(cv2.CAP_PROP_POS_FRAMES, indice)
                correcto, imagen = cap.read()
                if not correcto:
                    raise RuntimeError(f"No se pudo leer {video.name}, segundo {segundo}")
                alto, ancho = imagen.shape[:2]
                if ancho > 1280:
                    imagen = cv2.resize(imagen, (1280, round(alto * 1280 / ancho)))
                foto = carpeta / f"f{indice:06d}.jpg"
                escribir_jpg(foto, imagen)
                fotos.append(foto)
                registros.append({
                    "video": video.name,
                    "imagen": str(foto.relative_to(destino)),
                    "segundo": segundo,
                    "fotograma": indice,
                    "huella_pixeles": hashlib.sha256(imagen.tobytes()).hexdigest(),
                    "clases_declaradas_por_nombre": CLASES[prefijo],
                    "anotacion": "pendiente_revision",
                })
            resumen = [fotos[round(i * (len(fotos) - 1) / 7)] for i in range(8)]
            hoja_contacto(resumen, destino / f"resumen_{video.stem}.jpg")
            print(f"{video.name}: {len(fotos)} muestras", flush=True)
        finally:
            cap.release()
    (destino / "manifiesto.json").write_text(
        json.dumps({"imagenes": registros, "estado": "Clases, cajas y particiones pendientes de revision."},
                   ensure_ascii=False, indent=2), encoding="utf-8",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destino", type=Path, required=True)
    args = parser.parse_args()
    revisar(args.destino.resolve())
