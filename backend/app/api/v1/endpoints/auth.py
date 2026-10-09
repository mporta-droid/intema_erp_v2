from uuid import UUID

import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshRequest, TokenResponse
from app.services.audit import write_audit
from app.services.auth import authenticate_user
from app.services.serializers import user_to_read

router = APIRouter()
logger = logging.getLogger("intema.auth")


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)) -> TokenResponse:
    logger.info("LOGIN: request recibida username_or_email=%s", payload.username_or_email)
    try:
        logger.info("LOGIN: buscando usuario")
        user = authenticate_user(db, payload.username_or_email, payload.password)
        logger.info("LOGIN: usuario %s", "encontrado" if user else "no encontrado o password invalido")

        if user is None:
            logger.info("LOGIN: registrando intento fallido")
            write_audit(
                db,
                actor=None,
                action="login_failed",
                entity_type="users",
                detail={"username_or_email": payload.username_or_email},
                request=request,
            )
            db.commit()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario o contraseña incorrectos.")

        logger.info("LOGIN: password correcto")
        logger.info("LOGIN: registrando auditoria exitosa")
        write_audit(db, actor=user, action="login_success", entity_type="users", entity_id=str(user.id), request=request)
        db.commit()
        db.refresh(user)
        logger.info("LOGIN: generando token")
        response = TokenResponse(
            access_token=create_access_token(str(user.id)),
            refresh_token=create_refresh_token(str(user.id)),
            user=user_to_read(user),
        )
        logger.info("LOGIN: respuesta enviada")
        return response
    except HTTPException:
        raise
    except SQLAlchemyError as exc:
        logger.exception("LOGIN: error de base de datos")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudo validar el usuario porque la base de datos no respondió a tiempo.",
        ) from exc


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(payload: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    decoded = decode_token(payload.refresh_token, expected_type="refresh")
    try:
        user_id = UUID(str(decoded.get("sub")))
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token sin usuario válido.") from exc
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario inactivo o no encontrado.")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=user_to_read(user),
    )


@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return user_to_read(current_user)
