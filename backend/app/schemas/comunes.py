"""Validaciones compartidas por los schemas de catalogos."""


def nombre_obligatorio(valor: str) -> str:
    """Quita los espacios de los extremos y rechaza un nombre en blanco.

    `Field(min_length=1)` deja pasar "   ": la marca se guardaba con nombre
    vacio y el proveedor fallaba con NOT NULL (respondia "el valor ya esta en
    uso", que no tiene nada que ver con el problema).
    """
    texto = valor.strip()
    if not texto:
        raise ValueError("El nombre no puede quedar en blanco")
    return texto
