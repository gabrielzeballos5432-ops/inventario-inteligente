"""Extrae muestras para anotacion manual; no genera cajas ni resultados de IA."""

import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageOps


RAIZ = Path(__file__).resolve().parents[2]
VIDEOS = [
    ("iluminador líquido.mp4", "iluminador_liquido"),
    ("sombra de ojos liquida.mp4", "sombra_ojos_liquida"),
]


def validar_frecuencia(valor: float) -> float:
    if not math.isfinite(valor) or valor <= 0:
        raise ValueError("La frecuencia debe ser finita y mayor que cero.")
    return valor


def escribir_jpg(ruta: Path, imagen: np.ndarray) -> None:
    correcto, datos = cv2.imencode(".jpg", imagen, [cv2.IMWRITE_JPEG_QUALITY, 95])
    if not correcto:
        raise RuntimeError(f"No se pudo codificar la imagen: {ruta}")
    with ruta.open("xb") as archivo:
        archivo.write(datos.tobytes())


def hoja_contacto(rutas: list[Path], destino: Path) -> None:
    columnas, ancho, alto = 4, 300, 210
    hoja = Image.new("RGB", (columnas * ancho, math.ceil(len(rutas) / columnas) * alto), "white")
    texto = ImageDraw.Draw(hoja)
    for i, ruta in enumerate(rutas):
        x, y = (i % columnas) * ancho, (i // columnas) * alto
        with Image.open(ruta) as original:
            miniatura = ImageOps.contain(original, (ancho - 8, alto - 30))
            hoja.paste(miniatura, (x + (ancho - miniatura.width) // 2, y))
        texto.text((x + 4, y + alto - 25), ruta.stem, fill="black")
    hoja.save(destino)


def preparar(destino: Path, frecuencia: float = 2.0) -> dict:
    frecuencia = validar_frecuencia(frecuencia)
    for nombre, _ in VIDEOS:
        if not (RAIZ / nombre).is_file():
            raise FileNotFoundError(RAIZ / nombre)
    destino.mkdir(parents=True, exist_ok=False)
    registros = []
    resumen = []
    for clase_id, (nombre, clase) in enumerate(VIDEOS):
        video = RAIZ / nombre
        cap = cv2.VideoCapture(str(video))
        rutas = []
        try:
            if not cap.isOpened():
                raise RuntimeError(f"No se pudo abrir el video: {video}")
            fps = cap.get(cv2.CAP_PROP_FPS)
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            if not math.isfinite(fps) or fps <= 0 or total <= 0:
                raise ValueError(f"Metadatos de video invalidos: {video}")
            if frecuencia > fps:
                raise ValueError(f"La frecuencia solicitada supera los FPS del video: {video}")
            carpeta = destino / "imagenes" / clase
            carpeta.mkdir(parents=True)
            indice, siguiente, muestra = 0, 0, 0
            while indice < total:
                ok, marco = cap.read()
                if not ok:
                    raise RuntimeError(f"Video incompleto al leer el fotograma {indice}: {video}")
                if indice >= siguiente:
                    ruta = carpeta / f"{clase}_f{indice:06d}.jpg"
                    escribir_jpg(ruta, marco)
                    rutas.append(ruta)
                    registros.append({
                        "imagen": str(ruta.relative_to(destino)),
                        "video": nombre,
                        "clase_id": clase_id,
                        "clase": clase,
                        "fotograma": indice,
                        "segundo": round(indice / fps, 4),
                        "anotacion": "pendiente",
                        "particion": "sin_asignar",
                    })
                    muestra += 1
                    siguiente = round(muestra * fps / frecuencia)
                indice += 1
            resumen.append({"video": nombre, "fps": fps, "duracion_s": total / fps, "extraidas": len(rutas)})
        finally:
            cap.release()
        for inicio in range(0, len(rutas), 20):
            hoja_contacto(rutas[inicio:inicio + 20], destino / f"revision_{clase}_{inicio // 20 + 1}.jpg")
    informe = {
        "frecuencia_muestreo": frecuencia,
        "clases": [clase for _, clase in VIDEOS],
        "videos": resumen,
        "imagenes": registros,
        "estado": "Pendiente de cajas revisadas y particion por escenas; no apto aun para entrenamiento.",
    }
    (destino / "manifiesto.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    return informe


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destino", type=Path, required=True)
    parser.add_argument("--fps", type=float, default=2.0)
    args = parser.parse_args()
    informe = preparar(args.destino.resolve(), args.fps)
    for video in informe["videos"]:
        print(f"{video['video']}: {video['extraidas']} imagenes")
    print(informe["estado"])
