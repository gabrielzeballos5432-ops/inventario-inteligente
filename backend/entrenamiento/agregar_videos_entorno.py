"""Agrega grabaciones del entorno real (vitrina de la tienda) a un dataset.

Las grabaciones anteriores eran de costado, oscuras y sobre madera; en la
vitrina clara de la tienda el modelo casi no reconocia el iluminador. Este
script parte de un dataset existente, lo copia entero (validacion y prueba
intactas, para comparar con la misma vara) y agrega:

- Entrenamiento: los primeros segundos de cada grabacion (hasta
  --hasta-segundo). Las cajas revisadas a mano (una por segundo, en
  `anotaciones.json`) se guardan tal cual y entre cada par se propagan con
  CSRT hacia adelante y hacia atras. A diferencia de `ampliar_dataset.py`,
  del seguimiento solo se toma el CENTRO: CSRT se pega a la textura de la
  botella y achica la caja (cortaba la tapa y la base), lo que ensenaria al
  modelo a marcar medio producto. El tamano se interpola entre las dos cajas
  revisadas, y el cuadro se acepta solo si el centro de ida y el de vuelta
  coinciden (distancia <= --desvio-maximo del tamano de la caja).
- Prueba aparte (--prueba): desde --desde-segundo hasta el final, solo con
  las cajas revisadas a mano. Los segundos entre ambos tramos no se usan,
  para que la prueba no tenga casi el mismo cuadro que el entrenamiento.

Las grabaciones ya vienen derechas (sin marca de rotacion), igual que las
fotos de la app, asi que no se agregan copias giradas.

Requiere opencv-contrib-python (CSRT): correr con `backend/venv-ocr`.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import shutil

import cv2
from PIL import Image, ImageDraw, ImageOps

ESCALA_SEGUIMIENTO = 0.5


def seguir(cuadros, caja):
    """Sigue una caja normalizada xyxy; None donde se pierde."""
    alto, ancho = cuadros[0].shape[:2]
    x1, y1, x2, y2 = caja
    rastreador = cv2.TrackerCSRT_create()
    rastreador.init(cuadros[0], (int(x1 * ancho), int(y1 * alto),
                                 max(2, int((x2 - x1) * ancho)), max(2, int((y2 - y1) * alto))))
    salida, perdido = [list(caja)], False
    for cuadro in cuadros[1:]:
        if perdido:
            salida.append(None)
            continue
        ok, (x, y, w, h) = rastreador.update(cuadro)
        if not ok or w <= 1 or h <= 1:
            perdido = True
            salida.append(None)
            continue
        salida.append([max(0, x / ancho), max(0, y / alto), min(1, (x + w) / ancho), min(1, (y + h) / alto)])
    return salida


def centro(caja):
    return ((caja[0] + caja[2]) / 2, (caja[1] + caja[3]) / 2)


def propagada(inicial, final, ida, vuelta, t: float, desvio_maximo: float):
    """Caja del cuadro intermedio, o None si ida y vuelta no coinciden.

    Centro: el de la caja revisada mas el desplazamiento que midio el
    seguimiento (ida desde la inicial, vuelta desde la final), promediados.
    Tamano: interpolado entre las dos cajas revisadas.
    """
    if ida is None or vuelta is None:
        return None
    (ci, cf), (ca, cb) = (centro(inicial), centro(final)), (centro(ida), centro(vuelta))
    # Desplazamiento medido por el tracker respecto de su propia caja de partida.
    x1 = ci[0] + (ca[0] - ci[0]); y1 = ci[1] + (ca[1] - ci[1])
    x2 = cf[0] + (cb[0] - cf[0]); y2 = cf[1] + (cb[1] - cf[1])
    ancho = inicial[2] - inicial[0] + t * ((final[2] - final[0]) - (inicial[2] - inicial[0]))
    alto = inicial[3] - inicial[1] + t * ((final[3] - final[1]) - (inicial[3] - inicial[1]))
    if abs(x1 - x2) > desvio_maximo * ancho or abs(y1 - y2) > desvio_maximo * alto:
        return None
    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    return [max(0, cx - ancho / 2), max(0, cy - alto / 2), min(1, cx + ancho / 2), min(1, cy + alto / 2)]


def leer(cap, inicio: int, fin: int):
    cap.set(cv2.CAP_PROP_POS_FRAMES, inicio)
    cuadros = []
    for _ in range(inicio, fin + 1):
        ok, cuadro = cap.read()
        if not ok:
            break
        cuadros.append(cuadro)
    return cuadros


def a_pil(cuadro) -> Image.Image:
    return Image.fromarray(cv2.cvtColor(cuadro, cv2.COLOR_BGR2RGB))


def guardar(carpeta: Path, particion: str, nombre: str, imagen: Image.Image, clase: int, caja) -> None:
    (carpeta / "images" / particion).mkdir(parents=True, exist_ok=True)
    (carpeta / "labels" / particion).mkdir(parents=True, exist_ok=True)
    imagen.save(carpeta / "images" / particion / f"{nombre}.jpg", quality=92)
    x1, y1, x2, y2 = caja
    (carpeta / "labels" / particion / f"{nombre}.txt").write_text(
        f"{clase} {(x1 + x2) / 2:.8f} {(y1 + y2) / 2:.8f} {x2 - x1:.8f} {y2 - y1:.8f}\n", encoding="ascii")


def hoja(destino: Path, imagenes) -> None:
    filas = (len(imagenes) + 9) // 10
    lienzo = Image.new("RGB", (10 * 116, max(1, filas) * 208), "white")
    for i, (imagen, caja) in enumerate(imagenes):
        muestra = imagen.copy()
        x1, y1, x2, y2 = caja
        ImageDraw.Draw(muestra).rectangle((x1 * muestra.width, y1 * muestra.height,
                                           x2 * muestra.width, y2 * muestra.height), outline="lime", width=5)
        lienzo.paste(ImageOps.contain(muestra, (116, 208)), (i % 10 * 116, i // 10 * 208))
    lienzo.save(destino, quality=85)


def agregar(base: Path, destino: Path, prueba: Path, videos: Path, hasta: int, desde: int,
            cada: int, desvio_maximo: float) -> None:
    for carpeta in (destino, prueba):
        if carpeta.exists():
            raise FileExistsError(carpeta)
    if desde <= hasta + 1:
        raise ValueError("Debe quedar al menos un segundo sin usar entre entrenamiento y prueba.")
    anotaciones = json.loads((videos / "anotaciones.json").read_text(encoding="utf-8"))
    shutil.copytree(base, destino, ignore=shutil.ignore_patterns("*.cache", "revision_*.jpg"))
    conteo, rechazos, agregadas = Counter(), Counter(), []

    for video, info in anotaciones.items():
        clase = info["clase"]
        claves = sorted(info["muestras"], key=lambda m: m["fotograma"])
        cap = cv2.VideoCapture(str(videos / f"{video}.mp4"))
        revision = []
        entrenamiento = [m for m in claves if m["segundo"] <= hasta]
        for m in entrenamiento:  # las revisadas a mano, tal cual
            cuadro = leer(cap, m["fotograma"], m["fotograma"])[0]
            nombre = f"entorno_{video}_f{m['fotograma']:05d}"
            guardar(destino, "train", nombre, a_pil(cuadro), clase, m["caja"])
            agregadas.append({"video": video, "fotograma": m["fotograma"], "archivo": nombre,
                              "caja": m["caja"], "origen": "revisada_a_mano"})
            conteo[f"{video}_revisadas"] += 1
        for actual, siguiente in zip(entrenamiento, entrenamiento[1:]):
            inicio, fin = actual["fotograma"], siguiente["fotograma"]
            cuadros = leer(cap, inicio, fin)
            pequenos = [cv2.resize(c, None, fx=ESCALA_SEGUIMIENTO, fy=ESCALA_SEGUIMIENTO,
                                   interpolation=cv2.INTER_AREA) for c in cuadros]
            adelante = seguir(pequenos, actual["caja"])
            atras = list(reversed(seguir(list(reversed(pequenos)), siguiente["caja"])))
            for i in range(cada, fin - inicio - cada // 2, cada):
                caja = propagada(actual["caja"], siguiente["caja"], adelante[i], atras[i],
                                 i / (fin - inicio), desvio_maximo)
                if caja is None:
                    rechazos[video] += 1
                    continue
                imagen = a_pil(cuadros[i])
                nombre = f"entorno_{video}_f{inicio + i:05d}"
                guardar(destino, "train", nombre, imagen, clase, caja)
                agregadas.append({"video": video, "fotograma": inicio + i, "archivo": nombre,
                                  "caja": caja, "origen": "seguimiento"})
                revision.append((imagen, caja))
                conteo[f"{video}_propagadas"] += 1
        for m in claves:
            if m["segundo"] >= desde:
                cuadro = leer(cap, m["fotograma"], m["fotograma"])[0]
                guardar(prueba, "test", f"entorno_{video}_f{m['fotograma']:05d}", a_pil(cuadro), clase, m["caja"])
                conteo[f"{video}_prueba"] += 1
        cap.release()
        hoja(destino / f"revision_entorno_{video}.jpg", revision)
        print(f"{video}: {dict((k, v) for k, v in conteo.items() if k.startswith(video))}, "
              f"rechazados {rechazos[video]}", flush=True)

    nombres = "names:\n  0: iluminador_liquido\n  1: sombra_ojos_liquida\n"
    (destino / "data.yaml").write_text(
        f"path: {destino.as_posix()}\ntrain: images/train\nval: images/val\ntest: images/test\n{nombres}",
        encoding="utf-8")
    (prueba / "data.yaml").write_text(
        f"path: {prueba.as_posix()}\ntrain: images/test\nval: images/test\ntest: images/test\n{nombres}",
        encoding="utf-8")
    manifiesto = json.loads((base / "manifiesto.json").read_text(encoding="utf-8"))
    recuentos = {p: len(list((destino / "images" / p).glob("*.jpg"))) for p in ("train", "val", "test")}
    manifiesto.update({
        "base": base.name,
        "recuentos": recuentos,
        "entorno_real": {
            "metodo": "Cajas revisadas a mano (1 por segundo) y propagadas con CSRT en ambos sentidos; "
                      f"entrenamiento hasta el segundo {hasta}, prueba aparte desde el {desde}.",
            "cada_fotogramas": cada,
            "desvio_maximo": desvio_maximo,
            "agregadas": dict(conteo),
            "rechazos": dict(rechazos),
            "prueba_aparte": prueba.name,
        },
        "limites": manifiesto.get("limites", []) + [
            "Entorno real: una grabacion por producto; la prueba es el final de la misma grabacion "
            "(misma vitrina y luz), no un entorno independiente.",
        ],
    })
    manifiesto["imagenes"] = manifiesto.get("imagenes", []) + [{**a, "particion": "train"} for a in agregadas]
    (destino / "manifiesto.json").write_text(json.dumps(manifiesto, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"recuentos": recuentos, "prueba_aparte": conteo_prueba(prueba)}, ensure_ascii=False))


def conteo_prueba(prueba: Path) -> int:
    return len(list((prueba / "images" / "test").glob("*.jpg")))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--destino", type=Path, required=True)
    parser.add_argument("--prueba", type=Path, required=True)
    parser.add_argument("--videos", type=Path, required=True,
                        help="carpeta con los .mp4 (nombres sin acentos) y anotaciones.json")
    parser.add_argument("--hasta-segundo", type=int, default=12)
    parser.add_argument("--desde-segundo", type=int, default=14)
    parser.add_argument("--cada", type=int, default=6, help="fotogramas entre muestras propagadas")
    parser.add_argument("--desvio-maximo", type=float, default=0.15)
    a = parser.parse_args()
    agregar(a.base.resolve(), a.destino.resolve(), a.prueba.resolve(), a.videos.resolve(),
            a.hasta_segundo, a.desde_segundo, a.cada, a.desvio_maximo)
