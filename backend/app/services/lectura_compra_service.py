import io
import json
import logging
import os
from pathlib import Path
import re
import subprocess
import tempfile
import threading
from decimal import Decimal, InvalidOperation

from PIL import Image, ImageOps, UnidentifiedImageError

from app.schemas.lectura_compra import LecturaCompraOut, LineaCompraLeida


logger = logging.getLogger(__name__)
RAIZ_BACKEND = Path(__file__).resolve().parents[2]
_OCUPADO = threading.Lock()
_IMPORTE = r"\d+(?:[.,]\d+)*"
_LINEA = re.compile(
    rf"(?P<cantidad>{_IMPORTE})\s*[xX×]\s*(?P<costo>{_IMPORTE})"
    rf"(?:\s*=\s*(?P<subtotal>{_IMPORTE}))?"
)


class LecturaCompraError(Exception):
    def __init__(self, mensaje: str, estado: int = 422):
        super().__init__(mensaje)
        self.estado = estado


def importe_impreso(texto: str) -> Decimal:
    valor = texto.strip()
    if "," in valor:
        valor = valor.replace(".", "").replace(",", ".")
    elif "." in valor:
        grupos = valor.split(".")
        if all(len(grupo) == 3 for grupo in grupos[1:]):
            valor = "".join(grupos)
    return Decimal(valor)


def agrupar_renglones(lineas: list[dict]) -> list[str]:
    filas: list[list[dict]] = []
    for linea in sorted(lineas, key=lambda item: item["caja"][1]):
        centro = (linea["caja"][1] + linea["caja"][3]) / 2
        if filas:
            referencia = filas[-1][0]["caja"]
            centro_anterior = (referencia[1] + referencia[3]) / 2
            tolerancia = max(3, (referencia[3] - referencia[1]) * 0.5)
            if abs(centro - centro_anterior) <= tolerancia:
                filas[-1].append(linea)
                continue
        filas.append([linea])
    return [
        " ".join(item["texto"] for item in sorted(fila, key=lambda item: item["caja"][0]))
        for fila in filas
    ]


def interpretar_comprobante(renglones: list[str]) -> LecturaCompraOut:
    texto = "\n".join(renglones)
    detalles = []
    advertencias = [
        "Revisa cada producto, cantidad y costo. La lectura no registra inventario.",
        "Confirma la moneda y escribe los tipos de cambio; no se deducen de la foto.",
        "Confirma si las cantidades representan piezas o paquetes.",
    ]
    descripcion: list[str] = []
    total = None
    numero = None
    proveedor = None
    moneda = None
    for renglon in renglones:
        limpio = renglon.strip()
        documento = re.search(
            r"(?:DOCUMENTO\s*#|FACTURA\s*(?:N[°ºO.]*)?\s*[:#])\s*:?\s*([\w-]+)",
            limpio, re.IGNORECASE,
        )
        if documento:
            numero = documento.group(1)
        if re.search(r"\b(?:SPA|S\.?A\.?|S\.?R\.?L\.?|LTDA)\s*$", limpio, re.IGNORECASE):
            proveedor = limpio
        codigo_moneda = re.search(r"\b(CLP|USD|BOB)\b", limpio, re.IGNORECASE)
        if codigo_moneda:
            moneda = codigo_moneda.group(1).upper()
        total_match = re.search(
            rf"^\s*TOTAL\s*:?\s*(?:CLP|USD|BOB|\$|Bs\.?)?\s*({_IMPORTE})\s*$",
            limpio, re.IGNORECASE,
        )
        if total_match:
            try:
                total = importe_impreso(total_match.group(1))
            except InvalidOperation:
                advertencias.append(f"Total ilegible: {limpio}. Compruébalo manualmente.")
            descripcion.clear()
            continue
        coincidencia = _LINEA.search(limpio)
        if coincidencia:
            try:
                cantidad = importe_impreso(coincidencia["cantidad"])
                costo = importe_impreso(coincidencia["costo"])
                subtotal = (
                    importe_impreso(coincidencia["subtotal"])
                    if coincidencia["subtotal"] else None
                )
            except InvalidOperation:
                advertencias.append(f"Importe ilegible: {limpio}. Completa esta línea manualmente.")
                descripcion.clear()
                continue
            if cantidad <= 0 or cantidad != cantidad.to_integral_value() or costo < 0:
                advertencias.append(f"Cantidad o costo no válido: {limpio}. Completa esta línea manualmente.")
                descripcion.clear()
                continue
            nombre = " ".join(descripcion).strip() or "Producto sin descripción"
            codigo = re.match(r"^([A-Z0-9]+-[A-Z0-9-]+)\b", nombre, re.IGNORECASE)
            detalles.append(LineaCompraLeida(
                descripcion=nombre,
                codigo=codigo.group(1) if codigo else None,
                cantidad=int(cantidad),
                costo_unitario_moneda=costo,
                subtotal_impreso=subtotal,
            ))
            if subtotal is not None and abs(cantidad * costo - subtotal) > Decimal("0.01"):
                advertencias.append(f"No coincide cantidad × costo con el subtotal de: {nombre}.")
            descripcion.clear()
        elif limpio and not re.search(
            r"DOCUMENTO|RESP[.:]|ENTIDAD|FECHA|HORA|DESCRIPCI|BOD\s|\bCANT\.?\b|PRECIO|CANCELADO|^[-_]+$",
            limpio, re.IGNORECASE,
        ):
            descripcion.append(limpio)
            descripcion = descripcion[-3:]
        else:
            descripcion.clear()
    calculado = sum(
        (Decimal(item.cantidad) * item.costo_unitario_moneda for item in detalles),
        Decimal("0"),
    )
    if not detalles:
        raise LecturaCompraError(
            "No se identificaron líneas de cantidad × costo. Usa una foto más nítida o registra los datos manualmente."
        )
    if total is None:
        advertencias.append("No se identificó el total del comprobante.")
    elif abs(calculado - total) > Decimal("0.01"):
        advertencias.append(
            f"La suma leída ({calculado}) no coincide con el total impreso ({total}). "
            "Revisa líneas faltantes, descuentos y envío."
        )
    return LecturaCompraOut(
        numero_factura=numero, proveedor_nombre=proveedor, moneda_codigo=moneda,
        total_impreso=total, subtotal_calculado=calculado, detalles=detalles,
        advertencias=advertencias, texto_detectado=texto,
    )


def leer_comprobante(contenido: bytes) -> LecturaCompraOut:
    if not _OCUPADO.acquire(blocking=False):
        raise LecturaCompraError("Ya se está leyendo un comprobante. Intenta nuevamente en un momento.", 429)
    try:
        ejecutable = Path(os.environ.get(
            "OCR_PYTHON",
            str(RAIZ_BACKEND / "venv-ocr" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")),
        ))
        if not ejecutable.is_file():
            raise LecturaCompraError(
                "PaddleOCR no está instalado. Prepara backend/venv-ocr con requirements-ocr.txt y reinicia el backend.",
                503,
            )
        try:
            with Image.open(io.BytesIO(contenido)) as original:
                if original.width * original.height > 25_000_000:
                    raise LecturaCompraError("La imagen supera 25 megapíxeles. Reduce su tamaño.", 413)
                imagen = ImageOps.exif_transpose(original).convert("RGB")
        except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
            raise LecturaCompraError("El archivo no es una imagen válida (JPEG, PNG o WebP).") from exc
        imagen.thumbnail((3500, 5000))
        with tempfile.TemporaryDirectory(prefix="lectura_compra_") as temporal:
            ruta = Path(temporal) / "comprobante.jpg"
            imagen.save(ruta, quality=95)
            try:
                resultado = subprocess.run(
                    [str(ejecutable), str(RAIZ_BACKEND / "app" / "ocr" / "leer_imagen.py"), str(ruta)],
                    capture_output=True, text=True, encoding="utf-8", timeout=240,
                    env={**os.environ, "PYTHONIOENCODING": "utf-8"},
                )
            except subprocess.TimeoutExpired as exc:
                logger.warning("PaddleOCR superó el tiempo de lectura.")
                raise LecturaCompraError("La lectura tardó demasiado. Intenta con una imagen más pequeña.", 504) from exc
            except OSError as exc:
                logger.exception("No se pudo iniciar el proceso local PaddleOCR.")
                raise LecturaCompraError("No se pudo iniciar PaddleOCR. Revisa OCR_PYTHON en el servidor.", 503) from exc
            if resultado.returncode:
                logger.error("PaddleOCR no pudo leer el comprobante: %s", resultado.stderr[-4000:])
                raise LecturaCompraError(
                    "PaddleOCR no pudo procesar la imagen. Revisa su instalación y los modelos en el servidor.", 503,
                )
            try:
                lineas = json.loads(resultado.stdout)
                renglones = agrupar_renglones(lineas)
            except (json.JSONDecodeError, KeyError, TypeError, IndexError) as exc:
                logger.exception("Respuesta no válida del proceso PaddleOCR.")
                raise LecturaCompraError("El lector devolvió una respuesta no válida.", 502) from exc
            lectura = interpretar_comprobante(renglones)
            if any(linea["confianza"] < 0.85 for linea in lineas):
                lectura.advertencias.append("Hay texto de baja confianza. Comprueba los datos con la foto.")
            return lectura
    finally:
        _OCUPADO.release()
