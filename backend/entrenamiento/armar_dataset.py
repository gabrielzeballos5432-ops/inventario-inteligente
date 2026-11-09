"""Construye un dataset preliminar con cajas visuales y bloques temporales."""

import argparse
from collections import Counter
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageOps


def particion_temporal(segundo: float) -> str | None:
    if 5.5 <= segundo < 8.5:
        return "val"
    if 14.5 <= segundo < 17.5:
        return "test"
    if 5 <= segundo < 9 or 14 <= segundo < 18:
        return None
    return "train"


def normalizar_caja(caja: list[int]) -> tuple[float, float, float, float]:
    x1, y1, x2, y2 = caja
    x1, x2 = x1 / 400, x2 / 400
    y1, y2 = y1 / 171, y2 / 171
    if not 0 <= x1 < x2 <= 1 or not 0 <= y1 < y2 <= 1:
        raise ValueError(f"Caja invalida: {caja}")
    return (x1 + x2) / 2, (y1 + y2) / 2, x2 - x1, y2 - y1


def armar(origen: Path, destino: Path) -> None:
    manifiesto = json.loads((origen / "manifiesto.json").read_text(encoding="utf-8"))
    cajas = json.loads((origen / "cajas_revisadas.json").read_text(encoding="utf-8"))
    registros = manifiesto["imagenes"]
    for clase in manifiesto["clases"]:
        if len(cajas[clase]) != sum(r["clase"] == clase for r in registros):
            raise ValueError(f"No coincide el numero de cajas para {clase}")
        for caja in cajas[clase]:
            normalizar_caja(caja)
    destino.mkdir(parents=True, exist_ok=False)
    indices = Counter()
    recuentos = Counter()
    muestras = []
    hojas = []
    for r in registros:
        caja = cajas[r["clase"]][indices[r["clase"]]]
        indices[r["clase"]] += 1
        cx, cy, w, h = normalizar_caja(caja)
        particion = particion_temporal(r["segundo"])
        foto = origen / r["imagen"]
        with Image.open(foto) as im:
            im = im.convert("RGB")
            dibujo = ImageDraw.Draw(im)
            dibujo.rectangle(
                ((cx - w / 2) * im.width, (cy - h / 2) * im.height,
                 (cx + w / 2) * im.width, (cy + h / 2) * im.height),
                outline="lime", width=8,
            )
            hojas.append((foto.stem, ImageOps.contain(im, (400, 171))))
        if particion:
            imagenes = destino / "images" / particion
            etiquetas = destino / "labels" / particion
            imagenes.mkdir(parents=True, exist_ok=True)
            etiquetas.mkdir(parents=True, exist_ok=True)
            shutil.copy2(foto, imagenes / foto.name)
            (etiquetas / f"{foto.stem}.txt").write_text(
                f"{r['clase_id']} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}\n", encoding="ascii",
            )
            recuentos[(particion, r["clase"])] += 1
        muestras.append({**r, "particion": particion or "separacion_temporal", "caja": [cx, cy, w, h]})
    for inicio in range(0, len(hojas), 16):
        hoja = Image.new("RGB", (1600, 800), "white")
        dibujo = ImageDraw.Draw(hoja)
        for i, (nombre, im) in enumerate(hojas[inicio:inicio + 16]):
            x, y = i % 4 * 400, i // 4 * 200
            hoja.paste(im, (x, y))
            dibujo.text((x + 4, y + 175), nombre, fill="black")
        hoja.save(destino / f"revision_cajas_{inicio // 16 + 1}.jpg")
    (destino / "data.yaml").write_text(
        f"path: {destino.as_posix()}\ntrain: images/train\nval: images/val\ntest: images/test\n"
        "names:\n  0: iluminador_liquido\n  1: sombra_ojos_liquida\n", encoding="utf-8",
    )
    informe = {
        "advertencia": "Evaluacion preliminar de bloques del mismo video, no escenas independientes. Cajas visuales aproximadas.",
        "recuentos": {f"{p}/{c}": n for (p, c), n in recuentos.items()},
        "imagenes": muestras,
    }
    (destino / "manifiesto.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(informe["recuentos"], ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--origen", type=Path, required=True)
    parser.add_argument("--destino", type=Path, required=True)
    args = parser.parse_args()
    armar(args.origen.resolve(), args.destino.resolve())
