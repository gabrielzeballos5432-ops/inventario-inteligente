"""Proceso local aislado para evitar conflictos entre PaddleOCR y FastAPI."""

import contextlib
import json
import sys


def main() -> None:
    with contextlib.redirect_stdout(sys.stderr):
        from paddleocr import PaddleOCR

        motor = PaddleOCR(
            text_detection_model_name="PP-OCRv5_mobile_det",
            text_recognition_model_name="latin_PP-OCRv5_mobile_rec",
            device="cpu",
            enable_mkldnn=False,
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
        )
        resultados = list(motor.predict(sys.argv[1]))
        lineas = []
        for resultado in resultados:
            for texto, confianza, caja in zip(
                resultado["rec_texts"],
                resultado["rec_scores"],
                resultado["rec_boxes"],
                strict=True,
            ):
                lineas.append({
                    "texto": texto,
                    "confianza": float(confianza),
                    "caja": [float(coordenada) for coordenada in caja],
                })
    print(json.dumps(lineas, ensure_ascii=False))


if __name__ == "__main__":
    main()
