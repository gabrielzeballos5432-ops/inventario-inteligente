from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario_id: int
    nombre: str
    rol: str


class UsuarioCreado(BaseModel):
    id: int
    nombre: str
    email: EmailStr
    rol: str
    activo: bool

    class Config:
        from_attributes = True


class UsuarioCreate(BaseModel):
    nombre: str
    email: EmailStr
    password: str
    rol: str = "vendedor"
