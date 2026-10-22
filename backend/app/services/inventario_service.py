from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.repositories.sesion_repository import SesionRepository
from app.repositories.deteccion_repository import DeteccionRepository
from app.yolo.inference_service import InferenceService
from app.schemas.inferencia import InferenciaResponse, DeteccionOut
from app.schemas.movimiento import MovimientoLoteItem, MovimientoLoteResultado, MovimientoOut
from app.schemas.producto import ProductoStockOut
from app.models.movimiento import Movimiento


class InventarioService:
    def __init__(
        self,
        producto_repo: ProductoRepository,
        movimiento_repo: MovimientoRepository,
        yolo: InferenceService,
        sesion_repo: SesionRepository | None = None,
        deteccion_repo: DeteccionRepository | None = None,
    ):
        self.producto_repo = producto_repo
        self.movimiento_repo = movimiento_repo
        self.yolo = yolo
        self.sesion_repo = sesion_repo
        self.deteccion_repo = deteccion_repo

    async def procesar_inferencia(
        self,
        image_bytes: bytes,
        usuario_id: int,
        imagen_url: str | None = None,
        tipo_operacion: str = "entrada",
    ) -> InferenciaResponse:
        detecciones_raw = self.yolo.detectar(image_bytes)

        tipo_movimiento = "entrada" if tipo_operacion == "entrada" else "salida"

        sesion_id = None
        if self.sesion_repo is not None and detecciones_raw:
            sesion = await self.sesion_repo.crear(usuario_id, tipo_operacion)
            sesion_id = sesion.id

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

            if self.deteccion_repo is not None and sesion_id is not None:
                await self.deteccion_repo.crear(
                    sesion_id=sesion_id,
                    producto_id=det["producto_id"],
                    confianza=det["confianza"],
                    imagen_url=imagen_url,
                )

            await self.movimiento_repo.crear_movimiento(
                producto_id=det["producto_id"],
                usuario_id=usuario_id,
                tipo=tipo_movimiento,
                cantidad=det["cantidad"],
                origen="ia",
                sesion_id=sesion_id,
            )
            movimientos_creados += 1

        if sesion_id is not None and self.sesion_repo is not None:
            await self.sesion_repo.incrementar_detectados(sesion_id, movimientos_creados)

        return InferenciaResponse(
            detecciones=detecciones_out,
            total_productos=len(detecciones_out),
            movimientos_creados=movimientos_creados,
            sesion_id=sesion_id,
        )

    async def registrar_lote(
        self,
        tipo: str,
        items: list[MovimientoLoteItem],
        usuario_id: int,
        origen: str = "manual",
        sesion_id: int | None = None,
    ) -> tuple[list[MovimientoLoteResultado], list[Movimiento]]:
        """Registra varios movimientos del mismo tipo en una sola operacion.

        Es el mismo nucleo que usara la IA en RF-10: una captura detecta varios
        productos y guarda todas sus entradas de una vez con origen "ia"; el
        modo manual (recepcion de mercaderia) llama a este metodo con origen
        "manual" desde POST /api/inventario/movimientos/lote.

        Devuelve el resultado fila a fila y los movimientos creados. Si alguna
        linea es rechazada NO se crea ninguna: la recepcion es un documento, no
        debe quedar guardada a medias. El router traduce los rechazos en un 400
        con el detalle de cada fila para que se corrijan todos de una vez.
        """
        ids_con_orden = list(dict.fromkeys(item.producto_id for item in items))
        productos = await self.producto_repo.obtener_por_ids(ids_con_orden)
        por_id = {p.id: p for p in productos}
        stocks = await self.producto_repo.obtener_stocks(ids_con_orden)

        resultados: list[MovimientoLoteResultado] = []
        vistos: set[int] = set()
        for indice, item in enumerate(items, start=1):
            producto = por_id.get(item.producto_id)
            nombre = producto.nombre if producto else None
            detalle: str | None = None
            if producto is None:
                detalle = f"Fila {indice}: el producto {item.producto_id} no existe"
            elif not producto.activo:
                detalle = f"Fila {indice}: '{nombre}' esta dado de baja"
            elif item.producto_id in vistos:
                detalle = f"Fila {indice}: '{nombre}' esta repetido en el lote"
            elif tipo != "ajuste" and item.cantidad <= 0:
                detalle = f"Fila {indice}: la cantidad debe ser mayor a 0"
            elif tipo == "salida" and item.cantidad > stocks.get(item.producto_id, 0):
                disponible = stocks.get(item.producto_id, 0)
                detalle = (
                    f"Fila {indice} ({nombre}): no hay stock suficiente: "
                    f"disponible {disponible}"
                )
            vistos.add(item.producto_id)
            resultados.append(
                MovimientoLoteResultado(
                    fila=indice,
                    producto_id=item.producto_id,
                    producto_nombre=nombre,
                    correcto=detalle is None,
                    detalle=detalle,
                )
            )

        if any(r.detalle is not None for r in resultados):
            # Nada se crea: devolvemos los rechazos para que el router muestre
            # de que se corregiria en cada fila.
            return resultados, []

        movimientos = await self.movimiento_repo.crear_lote(
            productos_y_cantidades=[(i.producto_id, i.cantidad) for i in items],
            usuario_id=usuario_id,
            tipo=tipo,
            origen=origen,
            sesion_id=sesion_id,
        )
        # El orden de creacion respeta al de las filas, asi que queda en pareja
        # directo y cada resultado lleva el id de su movimiento.
        for resultado, movimiento in zip(resultados, movimientos):
            resultado.movimiento_id = movimiento.id
        return resultados, movimientos

    async def obtener_inventario(self) -> list[ProductoStockOut]:
        datos = await self.producto_repo.listar_con_stock()
        resultado = []
        for d in datos:
            prod = d["producto"]
            resultado.append(
                ProductoStockOut(
                    id=prod.id,
                    sku=prod.sku,
                    codigo_barras=prod.codigo_barras,
                    nombre=prod.nombre,
                    descripcion=prod.descripcion,
                    categoria_id=prod.categoria_id,
                    categoria=prod.categoria,
                    marca_id=prod.marca_id,
                    proveedor_id=prod.proveedor_id,
                    precio_compra=prod.precio_compra,
                    precio_venta=prod.precio_venta,
                    stock_minimo=prod.stock_minimo,
                    activo=prod.activo,
                    stock_actual=d["stock_actual"],
                    stock_bajo=d["stock_bajo"],
                )
            )
        return resultado

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
                sesion_id=m.sesion_id,
                tipo=m.tipo,
                cantidad_anterior=m.cantidad_anterior,
                cantidad=m.cantidad,
                stock_resultante=m.stock_resultante,
                origen=m.origen,
                creado_en=m.creado_en,
            )
            for m in movs
        ]