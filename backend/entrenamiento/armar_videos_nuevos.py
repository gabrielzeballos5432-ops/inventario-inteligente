"""Ensambla muestras revisadas y negativos con particiones por video completo."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageOps


def convertir_caja(caja: list[int], tamano: tuple[int, int]) -> list[float]:
    clase, x1, y1, x2, y2 = caja
    if clase not in (0, 1):
        raise ValueError(f"Clase desconocida: {clase}")
    ancho, alto = tamano
    if ancho <= 0 or alto <= 0:
        raise ValueError(f"Tamano invalido: {tamano}")
    escala = min(292 / ancho, 180 / alto)
    mini_ancho, mini_alto = int(ancho * escala), int(alto * escala)
    margen = (300 - mini_ancho) // 2
    x1, x2 = max(0, (x1 - margen) / mini_ancho), min(1, (x2 - margen) / mini_ancho)
    y1, y2 = max(0, y1 / mini_alto), min(1, y2 / mini_alto)
    if not 0 <= x1 < x2 <= 1 or not 0 <= y1 < y2 <= 1:
        raise ValueError(f"Caja invalida: {caja}")
    return [clase, (x1 + x2) / 2, (y1 + y2) / 2, x2 - x1, y2 - y1]


def armar(origen: Path, anterior: Path, destino: Path) -> None:
    datos = json.loads((origen / "manifiesto.json").read_text(encoding="utf-8"))
    anotaciones = json.loads((origen / "anotaciones_muestras.json").read_text(encoding="utf-8"))
    pendientes = []
    for video, especificacion in anotaciones["videos"].items():
        muestras = [r for r in datos["imagenes"] if r["video"] == video]
        if not muestras:
            raise ValueError(f"No hay muestras para {video}")
        if especificacion["particion"] not in ("train", "val", "test"):
            raise ValueError(f"Particion invalida: {video}")
        negativos = especificacion.get("negativo_confirmado", False)
        if not negativos and len(muestras) < 8:
            raise ValueError(f"Se necesitan al menos ocho muestras: {video}")
        elegidas = muestras if negativos else [muestras[round(i * (len(muestras) - 1) / 7)] for i in range(8)]
        if not negativos and len(especificacion["cajas"]) != len(elegidas):
            raise ValueError(f"Anotaciones incompletas: {video}")
        for i, muestra in enumerate(elegidas):
            foto = origen / muestra["imagen"]
            with Image.open(foto) as im:
                cajas = [] if negativos else [convertir_caja(caja, im.size) for caja in especificacion["cajas"][i]]
            pendientes.append((foto, especificacion["particion"], cajas, muestra))
    for foto in sorted((anterior / "images" / "train").glob("*.jpg")):
        etiqueta = anterior / "labels" / "train" / f"{foto.stem}.txt"
        cajas = [[float(v) for v in linea.split()] for linea in etiqueta.read_text().splitlines()]
        pendientes.append((foto, "train", cajas, {"video": "grabaciones_originales", "imagen": foto.name}))
    if destino.exists():
        raise FileExistsError(destino)
    huellas = {}
    for foto, particion, _, _ in pendientes:
        with Image.open(foto) as im:
            huella = hashlib.sha256(im.convert("RGB").tobytes()).hexdigest()
        if huella in huellas and huellas[huella] != particion:
            raise ValueError(f"Imagen duplicada entre particiones: {foto}")
        huellas[huella] = particion
    destino.mkdir(parents=True)
    conteos = Counter()
    manifiesto = []
    revisiones = {}
    for foto, particion, cajas, muestra in pendientes:
        nombre = f"{foto.parent.name}_{foto.name}"
        if muestra["video"] == "grabaciones_originales":
            nombre = foto.name
        carpeta = destino / "images" / particion
        carpeta.mkdir(parents=True, exist_ok=True)
        etiquetas = destino / "labels" / particion
        etiquetas.mkdir(parents=True, exist_ok=True)
        shutil.copy2(foto, carpeta / nombre)
        (etiquetas / f"{Path(nombre).stem}.txt").write_text(
            "".join(f"{int(c[0])} " + " ".join(f"{v:.8f}" for v in c[1:]) + "\n" for c in cajas), encoding="ascii",
        )
        conteos[particion] += 1
        manifiesto.append({**muestra, "archivo_dataset": nombre, "particion": particion, "cajas": cajas})
        if muestra["video"] != "grabaciones_originales" and cajas:
            with Image.open(foto) as im:
                im = im.convert("RGB")
                dibujo = ImageDraw.Draw(im)
                for clase, cx, cy, w, h in cajas:
                    color = "orange" if clase == 0 else "lime"
                    dibujo.rectangle(((cx - w / 2) * im.width, (cy - h / 2) * im.height,
                                      (cx + w / 2) * im.width, (cy + h / 2) * im.height), outline=color, width=5)
                revisiones.setdefault(muestra["video"], []).append(ImageOps.contain(im, (400, 180)))
    for video, imagenes in revisiones.items():
        hoja = Image.new("RGB", (1600, 400), "white")
        for i, im in enumerate(imagenes):
            hoja.paste(im, (i % 4 * 400, i // 4 * 200))
        hoja.save(destino / f"cajas_{Path(video).stem}.jpg")
    (destino / "data.yaml").write_text(
        f"path: {destino.as_posix()}\ntrain: images/train\nval: images/val\ntest: images/test\n"
        "names:\n  0: iluminador_liquido\n  1: sombra_ojos_liquida\n", encoding="utf-8",
    )
    informe = {
        "particion": "por grabacion completa; originales solo en entrenamiento",
        "recuentos": dict(conteos),
        "metodo_anotacion": anotaciones["metodo"],
        "limites": ["Entorno definitivo de la app no evaluado.", "Cajas visuales aproximadas; no certificadas.",
                   "8 muestras positivas por video; negativos a 1 FPS. Prueba reservada, sin aumentacion."],
        "imagenes": manifiesto,
    }
    (destino / "manifiesto.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(informe["recuentos"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--origen", type=Path, required=True)
    parser.add_argument("--anterior", type=Path, required=True)
    parser.add_argument("--destino", type=Path, required=True)
    args = parser.parse_args()
    armar(args.origen.resolve(), args.anterior.resolve(), args.destino.resolve())
