from app.core.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password


def test_password_hash_and_verify() -> None:
    password_hash = hash_password("Cambiar123!")

    assert password_hash != "Cambiar123!"
    assert verify_password("Cambiar123!", password_hash)
    assert not verify_password("Incorrecta123!", password_hash)


def test_jwt_access_and_refresh_tokens_have_expected_type() -> None:
    access = create_access_token("usuario-1")
    refresh = create_refresh_token("usuario-1")

    assert decode_token(access, expected_type="access")["sub"] == "usuario-1"
    assert decode_token(refresh, expected_type="refresh")["sub"] == "usuario-1"