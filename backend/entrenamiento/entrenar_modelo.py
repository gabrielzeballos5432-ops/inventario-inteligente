"""Entrena y evalua un candidato YOLOv8 sin instalarlo en la API."""

import argparse
import hashlib
import json
from pathlib import Path

import torch
from ultralytics import YOLO


RAIZ = Path(__file__).resolve().parents[2]


def entrenar(datos: Path, nombre: str, epocas: int) -> None:
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA no esta disponible; usar el entorno de entrenamiento, no el de la API.")
    salida = RAIZ / "dataset" / "runs" / nombre
    if salida.exists():
        raise FileExistsError(f"La ejecucion ya existe: {salida}")
    modelo = YOLO(str(RAIZ / "backend" / "yolov8s.pt"))
    modelo.train(
        data=str(datos),
        project=str(salida.parent),
        name=nombre,
        epochs=epocas,
        patience=30,
        imgsz=640,
        batch=4,
        device=0,
        workers=0,
        seed=2026,
        deterministic=True,
        pretrained=True,
        optimizer="AdamW",
        lr0=0.001,
        cos_lr=True,
        mosaic=0.5,
        close_mosaic=15,
        degrees=12,
        translate=0.15,
        scale=0.35,
        fliplr=0,
        flipud=0,
        hsv_h=0.01,
        hsv_s=0.15,
        hsv_v=0.3,
        mixup=0,
        cache=False,
        plots=True,
        amp=False,
    )
    peso = salida / "weights" / "best.pt"
    candidato = YOLO(str(peso))
    validacion = candidato.val(data=str(datos), split="val", device=0, workers=0, plots=True,
                               project=str(salida), name="evaluacion_val")
    prueba = candidato.val(data=str(datos), split="test", device=0, workers=0, plots=True,
                           project=str(salida), name="evaluacion_test")
    informe = {
        "peso": str(peso),
        "sha256": hashlib.sha256(peso.read_bytes()).hexdigest(),
        "gpu": torch.cuda.get_device_name(0),
        "torch": torch.__version__,
        "clases": candidato.names,
        "validacion": validacion.results_dict,
        "prueba": prueba.results_dict,
        "limites": [
            "Cajas visuales aproximadas; no hay evaluacion de anotadores independientes.",
            "Evaluacion limitada a las grabaciones aportadas; entorno definitivo de la app no evaluado.",
            "El modelo no se instala automaticamente ni registra movimientos de inventario.",
        ],
    }
    manifiesto = datos.parent / "manifiesto.json"
    if manifiesto.exists():
        preparacion = json.loads(manifiesto.read_text(encoding="utf-8"))
        informe["preparacion_dataset"] = {
            "sha256": hashlib.sha256(manifiesto.read_bytes()).hexdigest(),
            "particion": preparacion.get("particion", "bloques temporales del mismo video"),
            "recuentos": preparacion["recuentos"],
            "limites": preparacion.get("limites", [preparacion.get("advertencia")]),
        }
    (salida / "evaluacion_preliminar.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(informe, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--datos", type=Path, required=True)
    parser.add_argument("--nombre", default="dos_productos_s_20261030")
    parser.add_argument("--epocas", type=int, default=100)
    args = parser.parse_args()
    if args.epocas <= 0:
        parser.error("Las epocas deben ser mayores que cero.")
    entrenar(args.datos.resolve(), args.nombre, args.epocas)
