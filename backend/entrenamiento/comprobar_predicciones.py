"""Comprueba detecciones al umbral de la API sin escribir en inventario."""

import argparse
import json
from pathlib import Path
import time

from ultralytics import YOLO


def iou(caja_a: list[float], caja_b: list[float]) -> float:
    x1, y1 = max(caja_a[0], caja_b[0]), max(caja_a[1], caja_b[1])
    x2, y2 = min(caja_a[2], caja_b[2]), min(caja_a[3], caja_b[3])
    interseccion = max(0, x2 - x1) * max(0, y2 - y1)
    area_a = (caja_a[2] - caja_a[0]) * (caja_a[3] - caja_a[1])
    area_b = (caja_b[2] - caja_b[0]) * (caja_b[3] - caja_b[1])
    return interseccion / (area_a + area_b - interseccion)


def comprobar(peso: Path, dataset: Path, destino: Path, umbral: float) -> dict:
    if not 0 < umbral < 1:
        raise ValueError("El umbral debe estar entre cero y uno.")
    modelo = YOLO(str(peso))
    destino.mkdir(parents=True, exist_ok=False)
    imagenes = sorted((dataset / "images" / "test").glob("*.jpg"))
    if not imagenes:
        raise ValueError("No hay imagenes de prueba.")
    casos = []
    for imagen in imagenes:
        etiqueta = dataset / "labels" / "test" / f"{imagen.stem}.txt"
        esperadas = []
        for linea in etiqueta.read_text(encoding="ascii").splitlines():
            clase, cx, cy, w, h = map(float, linea.split())
            esperadas.append({"clase": int(clase), "xyxy": [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]})
        inicio = time.perf_counter()
        resultados = modelo.predict(source=str(imagen), conf=umbral, device="cpu", verbose=False)
        duracion = (time.perf_counter() - inicio) * 1000
        cajas = resultados[0].boxes
        detectadas = [
            {"clase": int(c.cls.item()), "confianza": float(c.conf.item()), "xyxy": c.xyxy.tolist()[0]}
            for c in cajas
        ] if cajas is not None else []
        resultados[0].save(filename=str(destino / imagen.name))
        altura, ancho = resultados[0].orig_shape
        usadas = set()
        aciertos = 0
        for deteccion in sorted(detectadas, key=lambda c: c["confianza"], reverse=True):
            x1, y1, x2, y2 = deteccion["xyxy"]
            normalizada = [x1 / ancho, y1 / altura, x2 / ancho, y2 / altura]
            candidatas = [
                (iou(normalizada, e["xyxy"]), i) for i, e in enumerate(esperadas)
                if i not in usadas and e["clase"] == deteccion["clase"]
            ]
            if candidatas:
                coincidencia, indice = max(candidatas)
                if coincidencia >= 0.5:
                    usadas.add(indice)
                    aciertos += 1
        casos.append({
            "imagen": imagen.name,
            "esperadas": esperadas,
            "detecciones": detectadas,
            "aciertos_iou_05": aciertos,
            "falsos_positivos": len(detectadas) - aciertos,
            "omisiones": len(esperadas) - aciertos,
            "conteo_y_localizacion_correctos": len(detectadas) == len(esperadas) == aciertos,
            "tiempo_total_cpu_ms": duracion,
        })
    informe = {
        "peso": str(peso.resolve()),
        "umbral": umbral,
        "clases": modelo.names,
        "casos": casos,
        "correctos": sum(c["conteo_y_localizacion_correctos"] for c in casos),
        "total": len(casos),
        "aciertos": sum(c["aciertos_iou_05"] for c in casos),
        "falsos_positivos": sum(c["falsos_positivos"] for c in casos),
        "omisiones": sum(c["omisiones"] for c in casos),
        "fondos": sum(not c["esperadas"] for c in casos),
        "fondos_con_falsas_detecciones": sum(not c["esperadas"] and bool(c["detecciones"]) for c in casos),
        "advertencia": "Evaluacion sobre muestras con cajas visuales aproximadas. Umbral fijo e IoU>=0.5; no valida camara en vivo ni entorno definitivo.",
    }
    (destino / "predicciones.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(informe, ensure_ascii=False, indent=2))
    return informe


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--peso", type=Path, required=True)
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--destino", type=Path, required=True)
    parser.add_argument("--umbral", type=float, default=0.5)
    args = parser.parse_args()
    comprobar(args.peso, args.dataset, args.destino, args.umbral)
