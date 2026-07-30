from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.yolo.inference_service import InferenceService
from app.schemas.inferencia import InferenciaResponse, DeteccionOut
from app.schemas.movimiento import MovimientoOut
from app.schemas.producto import ProductoStockOut


class InventarioService:
    def __init__(
        self,
        producto_repo: ProductoRepository,
        movimiento_repo: MovimientoRepository,
        yolo: InferenceService,
    ):
        self.producto_repo = producto_repo
        self.movimiento_repo = movimiento_repo
        self.yolo = yolo

    async def procesar_inferencia(
        self, image_bytes: bytes, usuario_id: int
    ) -> InferenciaResponse:
        detecciones_raw = self.yolo.detectar(image_bytes)
        detecciones_out: list[DeteccionOut] = []
        movimientos_creados = 0

        for det in detecciones_raw:
            producto = await self.producto_repo.obtener_por_id(
                det["producto_id"]
            )
            if not producto:
                continue

            detecciones_out.append(
                DeteccionOut(
                    producto_id=det["producto_id"],
                    producto_nombre=producto.nombre,
                    confianza=det["confianza"],
                    cantidad=det["cantidad"],
                )
            )

            await self.movimiento_repo.crear_movimiento(
                producto_id=det["producto_id"],
                usuario_id=usuario_id,
                tipo="salida",
                cantidad=det["cantidad"],
                origen="ia",
            )
            movimientos_creados += 1

        return InferenciaResponse(
            detecciones=detecciones_out,
            total_productos=len(detecciones_out),
            movimientos_creados=movimientos_creados,
        )

    async def obtener_inventario(self) -> list[ProductoStockOut]:
        datos = await self.producto_repo.listar_con_stock()
        return [
            ProductoStockOut(
                **{
                    **d["producto"].__dict__,
                    "stock_actual": d["stock_actual"],
                    "stock_bajo": d["stock_bajo"],
                }
            )
            for d in datos
        ]

    async def obtener_historial(
        self, limite: int = 50
    ) -> list[MovimientoOut]:
        movs = await self.movimiento_repo.listar_historial(limite)
        return [
            MovimientoOut(
                id=m.id,
                producto_id=m.producto_id,
                producto_nombre=m.producto.nombre if m.producto else None,
                usuario_id=m.usuario_id,
                usuario_nombre=m.usuario.nombre if m.usuario else None,
                tipo=m.tipo,
                cantidad=m.cantidad,
                stock_resultante=m.stock_resultante,
                origen=m.origen,
                creado_en=m.creado_en,
            )
            for m in movs
        ]
