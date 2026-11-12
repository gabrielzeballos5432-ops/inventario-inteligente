from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.repositories.sesion_repository import SesionRepository
from app.repositories.deteccion_repository import DeteccionRepository
from app.yolo.inference_service import InferenceService
from app.schemas.inferencia import InferenciaResponse, DeteccionOut
from app.schemas.movimiento import (
    MovimientoLoteItem,
    MovimientoLoteResultado,
    MovimientoOut,
    movimiento_out,
)
from app.schemas.producto import ProductoStockOut
from app.models.movimiento import Movimiento
from app.models.razon_movimiento import RazonMovimiento, razon_sistema
from app.models.sucursal import Sucursal


class MovimientoValidationError(Exception):
    """Error de la operación completa (razón, sucursal destino), no de una
    fila: el router lo devuelve como 400 con el mensaje tal cual."""


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

    @property
    def db(self):
        return self.movimiento_repo.db

    async def procesar_inferencia(
        self,
        image_bytes: bytes,
        usuario_id: int,
        sucursal_id: int,
        imagen_url: str | None = None,
        tipo_operacion: str = "entrada",
        registrar: bool = True,
    ) -> InferenciaResponse:
        detecciones_raw = self.yolo.detectar(image_bytes)

        tipo_movimiento = "entrada" if tipo_operacion == "entrada" else "salida"
        # Un conteo solo informa lo que hay: nunca mueve el stock (antes se
        # registraba como salida).
        mover_stock = registrar and tipo_operacion != "conteo"

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
                    cajas=det.get("cajas", []),
                )
            )

            if self.deteccion_repo is not None and sesion_id is not None:
                await self.deteccion_repo.crear(
                    sesion_id=sesion_id,
                    producto_id=det["producto_id"],
                    confianza=det["confianza"],
                    imagen_url=imagen_url,
                )

            if not mover_stock:
                continue
            await self.movimiento_repo.crear_movimiento(
                producto_id=det["producto_id"],
                usuario_id=usuario_id,
                tipo=tipo_movimiento,
                cantidad=det["cantidad"],
                sucursal_id=sucursal_id,
                razon_movimiento_id=razon_sistema(f"deteccion_ia_{tipo_movimiento}"),
                origen="ia",
                sesion_id=sesion_id,
            )
            movimientos_creados += 1

        if sesion_id is not None and self.sesion_repo is not None:
            # Unidades detectadas, se registren o no (en "solo detectar" el
            # usuario confirma despues y la sesion igual debe reflejarlas).
            await self.sesion_repo.incrementar_detectados(
                sesion_id, sum(d.cantidad for d in detecciones_out)
            )
            # Las detecciones y el conteo solo hacen flush: sin este commit se
            # perdian cuando no se registraba ningun movimiento.
            await self.db.commit()

        return InferenciaResponse(
            detecciones=detecciones_out,
            total_productos=len(detecciones_out),
            movimientos_creados=movimientos_creados,
            sesion_id=sesion_id,
        )

    async def _resolver_razon(
        self,
        tipo: str,
        razon_movimiento_id: int | None,
        origen: str,
        sucursal_id: int,
        sucursal_destino_id: int | None,
    ) -> tuple[object, Sucursal | None]:
        """Valida la razón y, si es un traspaso, la sucursal destino.

        Devuelve el valor para `razon_movimiento_id` (id o subconsulta de una
        razón del sistema) y la sucursal destino cuando corresponde.
        """
        if razon_movimiento_id is None:
            if origen == "ia" and tipo in ("entrada", "salida"):
                if sucursal_destino_id is not None:
                    raise MovimientoValidationError(
                        "La detección por IA no registra traspasos entre sucursales."
                    )
                return razon_sistema(f"deteccion_ia_{tipo}"), None
            raise MovimientoValidationError("La razón del movimiento es obligatoria.")

        razon = await self.db.get(RazonMovimiento, razon_movimiento_id)
        if razon is None or not razon.activo:
            raise MovimientoValidationError("La razón no existe o está desactivada.")
        if razon.sistema:
            raise MovimientoValidationError(
                f"La razón '{razon.nombre}' la asigna el sistema y no se elige a mano."
            )
        if razon.tipo_movimiento != tipo:
            raise MovimientoValidationError(
                f"La razón '{razon.nombre}' es de {razon.tipo_movimiento}, "
                f"no de {tipo}."
            )

        if not razon.requiere_sucursal_destino:
            if sucursal_destino_id is not None:
                raise MovimientoValidationError(
                    f"La razón '{razon.nombre}' no envía mercadería a otra sucursal."
                )
            return razon.id, None

        if sucursal_destino_id is None:
            raise MovimientoValidationError(
                f"Elige la sucursal destino para '{razon.nombre}'."
            )
        if sucursal_destino_id == sucursal_id:
            raise MovimientoValidationError(
                "La sucursal destino tiene que ser distinta de la sucursal actual."
            )
        destino = await self.db.get(Sucursal, sucursal_destino_id)
        if destino is None or not destino.activo:
            raise MovimientoValidationError(
                "La sucursal destino no existe o está desactivada."
            )
        return razon.id, destino

    async def registrar_lote(
        self,
        tipo: str,
        items: list[MovimientoLoteItem],
        usuario_id: int,
        sucursal_id: int,
        origen: str = "manual",
        sesion_id: int | None = None,
        razon_movimiento_id: int | None = None,
        sucursal_destino_id: int | None = None,
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

        Si la razón envía a otra sucursal ("Salida a sucursal"), en la misma
        transacción se registra la entrada en la sucursal destino.
        """
        razon_valor, destino = await self._resolver_razon(
            tipo, razon_movimiento_id, origen, sucursal_id, sucursal_destino_id
        )

        ids_con_orden = list(dict.fromkeys(item.producto_id for item in items))
        productos = await self.producto_repo.obtener_por_ids(ids_con_orden)
        por_id = {p.id: p for p in productos}
        stocks = await self.producto_repo.obtener_stocks(ids_con_orden, sucursal_id)

        # La entrada que confirma el usuario tras la deteccion IA reactiva el
        # producto dado de baja: si la camara lo reconoce y alguien confirma
        # que llego, vuelve a venderse. A mano se sigue rechazando, para no
        # devolver un producto dado de baja por un descuido.
        reactiva = origen == "ia" and tipo == "entrada"

        resultados: list[MovimientoLoteResultado] = []
        vistos: set[int] = set()
        for indice, item in enumerate(items, start=1):
            producto = por_id.get(item.producto_id)
            nombre = producto.nombre if producto else None
            detalle: str | None = None
            if producto is None:
                detalle = f"Fila {indice}: el producto {item.producto_id} no existe"
            elif not producto.activo and not reactiva:
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
                    reactivado=(
                        detalle is None and producto is not None and not producto.activo
                    ),
                )
            )

        if any(r.detalle is not None for r in resultados):
            # Nada se crea: devolvemos los rechazos para que el router muestre
            # de que se corregiria en cada fila.
            return resultados, []

        # En la misma transaccion que los movimientos: crear_lote hace el
        # commit, y si falla tampoco queda reactivado.
        for resultado in resultados:
            if resultado.reactivado:
                por_id[resultado.producto_id].activo = True

        lineas = [(i.producto_id, i.cantidad) for i in items]
        movimientos = await self.movimiento_repo.crear_lote(
            productos_y_cantidades=lineas,
            usuario_id=usuario_id,
            tipo=tipo,
            sucursal_id=sucursal_id,
            razon_movimiento_id=razon_valor,
            origen=origen,
            sesion_id=sesion_id,
            sucursal_relacionada_id=destino.id if destino else None,
            confirmar=destino is None,
        )
        if destino is not None:
            await self.movimiento_repo.crear_lote(
                productos_y_cantidades=lineas,
                usuario_id=usuario_id,
                tipo="entrada",
                sucursal_id=destino.id,
                razon_movimiento_id=razon_sistema("traspaso_entrada"),
                origen=origen,
                sesion_id=sesion_id,
                sucursal_relacionada_id=sucursal_id,
            )
        # El orden de creacion respeta al de las filas, asi que queda en pareja
        # directo y cada resultado lleva el id de su movimiento.
        for resultado, movimiento in zip(resultados, movimientos):
            resultado.movimiento_id = movimiento.id
        return resultados, movimientos

    async def registrar_movimiento(
        self,
        producto_id: int,
        tipo: str,
        cantidad: int,
        usuario_id: int,
        sucursal_id: int,
        origen: str = "manual",
        sesion_id: int | None = None,
        razon_movimiento_id: int | None = None,
        sucursal_destino_id: int | None = None,
    ) -> MovimientoOut:
        """Un movimiento suelto: mismas reglas que una fila del lote."""
        razon_valor, destino = await self._resolver_razon(
            tipo, razon_movimiento_id, origen, sucursal_id, sucursal_destino_id
        )
        producto = await self.producto_repo.obtener_por_id(producto_id)
        if producto is None:
            raise MovimientoValidationError("Producto no encontrado.")
        if not producto.activo:
            raise MovimientoValidationError(f"'{producto.nombre}' está dado de baja.")
        # Una salida no puede dejar el stock en negativo: se rechaza con un
        # mensaje que dice cuánto hay disponible en esta sucursal.
        if tipo == "salida":
            stock = await self.producto_repo.obtener_stock(producto_id, sucursal_id)
            if cantidad > stock:
                raise MovimientoValidationError(
                    f"No hay stock suficiente: disponible {stock}"
                )

        movimientos = await self.movimiento_repo.crear_lote(
            productos_y_cantidades=[(producto_id, cantidad)],
            usuario_id=usuario_id,
            tipo=tipo,
            sucursal_id=sucursal_id,
            razon_movimiento_id=razon_valor,
            origen=origen,
            sesion_id=sesion_id,
            sucursal_relacionada_id=destino.id if destino else None,
            confirmar=destino is None,
        )
        if destino is not None:
            await self.movimiento_repo.crear_lote(
                productos_y_cantidades=[(producto_id, cantidad)],
                usuario_id=usuario_id,
                tipo="entrada",
                sucursal_id=destino.id,
                razon_movimiento_id=razon_sistema("traspaso_entrada"),
                origen=origen,
                sesion_id=sesion_id,
                sucursal_relacionada_id=sucursal_id,
            )
        detalle = await self.movimiento_repo.obtener_detalle([movimientos[0].id])
        return movimiento_out(detalle[0])

    async def obtener_inventario(self, sucursal_id: int | None) -> list[ProductoStockOut]:
        datos = await self.producto_repo.listar_con_stock(sucursal_id)
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
                    precio_mayor=prod.precio_mayor,
                    stock_minimo=prod.stock_minimo,
                    activo=prod.activo,
                    stock_actual=d["stock_actual"],
                    stock_bajo=d["stock_bajo"],
                )
            )
        return resultado

    async def obtener_historial(
        self, limite: int = 50, sucursal_id: int | None = None
    ) -> list[MovimientoOut]:
        movs = await self.movimiento_repo.listar_historial(limite, sucursal_id)
        return [movimiento_out(m) for m in movs]
