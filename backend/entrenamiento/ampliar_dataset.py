"""Amplia el entrenamiento propagando las cajas revisadas a mano con seguimiento.

Parte de un dataset existente y lo copia completo: validacion y prueba quedan
intactas, para que el modelo nuevo se compare con la misma vara que el
anterior. Solo se agregan imagenes a `train`:

- Positivos: entre dos fotogramas revisados a mano (8 por video), cada caja
  se sigue con CSRT hacia adelante desde el primero y hacia atras desde el
  segundo. Solo se acepta un fotograma si ambos recorridos coinciden
  (IoU >= --iou-acuerdo); la caja guardada es el promedio. La clase es la de
  la caja revisada. Un tramo cuyo objeto sale de cuadro se corta solo,
  porque los recorridos dejan de coincidir.
- Negativos: fotogramas de `sin_productos_otros` (ya era de entrenamiento) y
  copias oscurecidas, para que un fondo oscuro vacio no se confunda con un
  producto. `sin_productos_oscuro` es de prueba: no se toca.
- Rotaciones: una copia girada 90 o 270 grados de cada positivo (y de pie
  de cada negativo). Las grabaciones estan de costado (se leen sin aplicar la
  marca de rotacion, igual que las revisadas a mano) y la app manda la foto
  derecha: sin estas copias el modelo solo veria productos acostados.

Requiere opencv-contrib-python (CSRT); no necesita ultralytics ni GPU.
Deja hojas revision_*.jpg con las cajas dibujadas para revisarlas a ojo.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import random
import shutil

import cv2
from PIL import Image, ImageDraw, ImageEnhance, ImageOps

RAIZ = Path(__file__).resolve().parents[2]


def abrir_video(ruta: Path) -> cv2.VideoCapture:
    """Abre el video SIN aplicar la marca de rotacion del celular.

    Las grabaciones traen una rotacion de 90 grados en sus metadatos. Los
    fotogramas revisados a mano se extrajeron sin aplicarla (de costado), asi
    que para que las cajas coincidan hay que leer igual. OpenCV reciente la
    aplica por defecto y devolveria otra orientacion.
    """
    cap = cv2.VideoCapture(str(ruta))
    cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 0)
    return cap
ANCHO, ALTO = 1280, 549
ESCALA_SEGUIMIENTO = 0.5  # se sigue a 640x274: mas rapido y suficiente
VIDEO_NEGATIVOS = "sin_productos_otros.mp4"


def iou(a, b) -> float:
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def yolo_a_xyxy(c):
    clase, cx, cy, w, h = c
    return int(clase), [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]


def seguir(cuadros, caja_inicial):
    """Sigue una caja normalizada xyxy por `cuadros` (lista BGR pequenos).

    Devuelve una caja normalizada por cuadro, o None donde se perdio.
    """
    alto, ancho = cuadros[0].shape[:2]
    x1, y1, x2, y2 = caja_inicial
    rect = (int(x1 * ancho), int(y1 * alto), max(2, int((x2 - x1) * ancho)), max(2, int((y2 - y1) * alto)))
    rastreador = cv2.TrackerCSRT_create()
    rastreador.init(cuadros[0], rect)
    salida = [list(caja_inicial)]
    perdido = False
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


def leer_tramo(cap, inicio: int, fin: int, cada: int):
    """Cuadros pequenos [inicio..fin] para seguir, y los de muestra a 1280."""
    cap.set(cv2.CAP_PROP_POS_FRAMES, inicio)
    pequenos, muestras = [], {}
    for indice in range(inicio, fin + 1):
        ok, cuadro = cap.read()
        if not ok:
            break
        pequenos.append(cv2.resize(cuadro, None, fx=ESCALA_SEGUIMIENTO * ANCHO / cuadro.shape[1],
                                   fy=ESCALA_SEGUIMIENTO * ALTO / cuadro.shape[0],
                                   interpolation=cv2.INTER_AREA))
        if (indice - inicio) % cada == 0 and inicio < indice < fin:
            grande = cv2.resize(cuadro, (ANCHO, ALTO), interpolation=cv2.INTER_AREA)
            muestras[indice] = Image.fromarray(cv2.cvtColor(grande, cv2.COLOR_BGR2RGB))
    return pequenos, muestras


def propagar_video(video: Path, claves: list[dict], cada: int, iou_acuerdo: float):
    """Fotogramas nuevos {indice: (imagen, [(clase, xyxy)])} de un video."""
    cap = abrir_video(video)
    claves = sorted(claves, key=lambda c: c["fotograma"])
    nuevos, rechazos = {}, Counter()
    for actual, siguiente in zip(claves, claves[1:]):
        inicio, fin = actual["fotograma"], siguiente["fotograma"]
        pequenos, muestras = leer_tramo(cap, inicio, fin, cada)
        if len(pequenos) < fin - inicio + 1:
            rechazos["tramo_incompleto"] += 1
            continue
        cajas_ini = [yolo_a_xyxy(c) for c in actual["cajas"]]
        cajas_fin = [yolo_a_xyxy(c) for c in siguiente["cajas"]]
        por_cuadro: dict[int, list] = defaultdict(list)
        incompletos = set()
        for clase, caja in cajas_ini:
            # La misma clase en el fotograma revisado siguiente (la mas cercana).
            candidatas = [c for k, c in cajas_fin if k == clase]
            if not candidatas:
                incompletos.update(muestras)  # el objeto sale de cuadro: tramo dudoso
                rechazos["sin_par_en_siguiente"] += 1
                continue
            destino = max(candidatas, key=lambda c: iou(c, caja))
            adelante = seguir(pequenos, caja)
            atras = list(reversed(seguir(list(reversed(pequenos)), destino)))
            for indice in muestras:
                i = indice - inicio
                a, b = adelante[i], atras[i]
                if a is None or b is None or iou(a, b) < iou_acuerdo:
                    incompletos.add(indice)
                    continue
                por_cuadro[indice].append((clase, [(p + q) / 2 for p, q in zip(a, b)]))
        for indice, imagen in muestras.items():
            # Se guarda solo si TODAS las cajas del cuadro son fiables: una caja
            # faltante convertiria un producto visible en "fondo".
            if indice in incompletos or len(por_cuadro[indice]) != len(cajas_ini):
                rechazos["desacuerdo_o_perdido"] += 1
                continue
            nuevos[indice] = (imagen, por_cuadro[indice])
    cap.release()
    return nuevos, rechazos


def oscurecer(imagen: Image.Image) -> Image.Image:
    # Gamma alta + menos brillo: parecido a la grabacion con poca luz, sin
    # usar esa grabacion (es de prueba).
    oscura = imagen.point(lambda v: round(255 * (v / 255) ** 2.2))
    return ImageEnhance.Contrast(ImageEnhance.Brightness(oscura).enhance(0.75)).enhance(0.85)


def rotar(imagen: Image.Image, cajas, grados: int):
    """Gira la imagen y sus cajas normalizadas 90 o 270 grados (antihorario)."""
    girada = imagen.rotate(grados, expand=True)
    salida = []
    for clase, (x1, y1, x2, y2) in cajas:
        if grados == 90:   # (x, y) -> (y, 1 - x)
            salida.append((clase, [y1, 1 - x2, y2, 1 - x1]))
        else:              # 270: (x, y) -> (1 - y, x)
            salida.append((clase, [1 - y2, x1, 1 - y1, x2]))
    return girada, salida


def guardar(destino: Path, nombre: str, imagen: Image.Image, cajas) -> None:
    imagen.save(destino / "images" / "train" / f"{nombre}.jpg", quality=92)
    (destino / "labels" / "train" / f"{nombre}.txt").write_text(
        "".join(f"{c} {(x1 + x2) / 2:.8f} {(y1 + y2) / 2:.8f} {x2 - x1:.8f} {y2 - y1:.8f}\n"
                for c, (x1, y1, x2, y2) in cajas),
        encoding="ascii",
    )


def hoja_revision(destino: Path, nombre: str, imagenes) -> None:
    filas = (len(imagenes) + 5) // 6
    hoja = Image.new("RGB", (6 * 320, max(1, filas) * 140), "white")
    for i, (imagen, cajas) in enumerate(imagenes):
        muestra = imagen.copy()
        dibujo = ImageDraw.Draw(muestra)
        for clase, (x1, y1, x2, y2) in cajas:
            dibujo.rectangle((x1 * muestra.width, y1 * muestra.height, x2 * muestra.width, y2 * muestra.height),
                             outline="orange" if clase == 0 else "lime", width=6)
        hoja.paste(ImageOps.contain(muestra, (320, 140)), (i % 6 * 320, i // 6 * 140))
    hoja.save(destino / f"revision_{nombre}.jpg", quality=85)


def ampliar(base: Path, destino: Path, videos: Path, cada: int, iou_acuerdo: float,
            cada_negativos: int, fraccion_rotada: float) -> None:
    if destino.exists():
        raise FileExistsError(destino)
    manifiesto_base = json.loads((base / "manifiesto.json").read_text(encoding="utf-8"))
    claves_por_video = defaultdict(list)
    for registro in manifiesto_base["imagenes"]:
        if registro["particion"] == "train" and registro["cajas"] and registro["video"].endswith(".mp4"):
            claves_por_video[registro["video"]].append(registro)
    shutil.copytree(base, destino, ignore=shutil.ignore_patterns("cajas_*.jpg", "*.cache"))

    random.seed(2026)
    conteo, rechazos_totales = Counter(), {}
    agregadas, positivos = [], []
    for video, claves in sorted(claves_por_video.items()):
        nuevos, rechazos = propagar_video(videos / video, claves, cada, iou_acuerdo)
        rechazos_totales[video] = dict(rechazos)
        muestras_revision = []
        for indice, (imagen, cajas) in sorted(nuevos.items()):
            nombre = f"ampl_{Path(video).stem}_f{indice:06d}"
            guardar(destino, nombre, imagen, cajas)
            positivos.append((nombre, imagen, cajas))
            agregadas.append({"video": video, "fotograma": indice, "archivo": nombre,
                              "cajas": [[c, *xy] for c, xy in cajas], "origen": "seguimiento"})
            muestras_revision.append((imagen, cajas))
            conteo[video] += 1
        if muestras_revision:
            hoja_revision(destino, Path(video).stem, muestras_revision)
        print(f"{video}: {conteo[video]} agregadas, rechazos {dict(rechazos)}", flush=True)

    # Rotaciones de una parte de los positivos (nuevos y revisados a mano).
    for foto in sorted((base / "images" / "train").glob("*.jpg")):
        etiqueta = base / "labels" / "train" / f"{foto.stem}.txt"
        cajas = [yolo_a_xyxy([float(v) for v in linea.split()])
                 for linea in etiqueta.read_text().splitlines() if linea.strip()]
        if cajas:
            positivos.append((foto.stem, Image.open(foto).convert("RGB"), cajas))
    for nombre, imagen, cajas in positivos:
        if random.random() >= fraccion_rotada:
            continue
        grados = random.choice((90, 270))
        girada, cajas_giradas = rotar(imagen, cajas, grados)
        guardar(destino, f"{nombre}_rot{grados}", girada, cajas_giradas)
        conteo["rotadas"] += 1
        agregadas.append({"video": "rotacion", "archivo": f"{nombre}_rot{grados}", "origen": nombre})

    if not any(r["video"] == VIDEO_NEGATIVOS and r["particion"] == "train" for r in manifiesto_base["imagenes"]):
        raise ValueError(f"{VIDEO_NEGATIVOS} no es de entrenamiento: no se usa como negativo")
    cap = abrir_video(videos / VIDEO_NEGATIVOS)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    for indice in range(0, total, cada_negativos):
        cap.set(cv2.CAP_PROP_POS_FRAMES, indice)
        ok, cuadro = cap.read()
        if not ok:
            continue
        imagen = Image.fromarray(cv2.cvtColor(cv2.resize(cuadro, (ANCHO, ALTO), interpolation=cv2.INTER_AREA),
                                              cv2.COLOR_BGR2RGB))
        nombre = f"ampl_{Path(VIDEO_NEGATIVOS).stem}_f{indice:06d}"
        guardar(destino, nombre, imagen, [])
        guardar(destino, f"{nombre}_oscuro", oscurecer(imagen), [])
        # Tambien de pie: las fotos de la app llegan derechas.
        guardar(destino, f"{nombre}_rot90", imagen.rotate(90, expand=True), [])
        conteo["negativos"] += 3
    cap.release()

    recuentos = {p: len(list((destino / "images" / p).glob("*.jpg"))) for p in ("train", "val", "test")}
    informe = {
        **{k: v for k, v in manifiesto_base.items() if k != "imagenes"},
        "base": base.name,
        "recuentos": recuentos,
        "ampliacion": {
            "metodo": "Cajas revisadas a mano propagadas con CSRT en ambos sentidos entre fotogramas "
                      "revisados; solo se aceptan cuadros donde ambos recorridos coinciden. "
                      "Validacion y prueba sin cambios.",
            "cada_fotogramas": cada,
            "iou_acuerdo": iou_acuerdo,
            "negativos_cada_fotogramas": cada_negativos,
            "fraccion_rotada": fraccion_rotada,
            "agregadas": dict(conteo),
            "rechazos": rechazos_totales,
        },
        "limites": manifiesto_base.get("limites", []) + [
            "Cajas propagadas por seguimiento desde cajas aproximadas: heredan su imprecision.",
            "Fotogramas del mismo video estan correlacionados.",
        ],
        "imagenes": manifiesto_base["imagenes"] + [{**a, "particion": "train"} for a in agregadas],
    }
    (destino / "manifiesto.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    (destino / "data.yaml").write_text(
        f"path: {destino.as_posix()}\ntrain: images/train\nval: images/val\ntest: images/test\n"
        "names:\n  0: iluminador_liquido\n  1: sombra_ojos_liquida\n", encoding="utf-8",
    )
    print(json.dumps({"recuentos": recuentos, "agregadas": dict(conteo)}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--destino", type=Path, required=True)
    parser.add_argument("--videos", type=Path, default=RAIZ)
    parser.add_argument("--cada", type=int, default=20, help="fotogramas entre muestras positivas")
    parser.add_argument("--iou-acuerdo", type=float, default=0.6)
    parser.add_argument("--cada-negativos", type=int, default=20)
    parser.add_argument("--fraccion-rotada", type=float, default=1.0)
    a = parser.parse_args()
    ampliar(a.base.resolve(), a.destino.resolve(), a.videos.resolve(), a.cada, a.iou_acuerdo,
            a.cada_negativos, a.fraccion_rotada)
