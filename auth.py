import os
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv
from jose import JWTError, jwt
from passlib.context import CryptContext

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

secret_key: str = os.getenv("SECRET_KEY", "mysecretkey")
Algorithm = os.getenv("ALGORITHM", "HS256")


def hash_pass(pas: str) -> str:
    return pwd_context.hash(pas)


def verify_pass(pas: str, hashed_password: str) -> bool:
    return pwd_context.verify(pas, hashed_password)


def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=30)
    token = jwt.encode({"user_id": user_id, "exp": expire}, secret_key, algorithm=Algorithm)
    return token


def create_refresh_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=7)
    token = jwt.encode(
        {"user_id": user_id, "exp": expire, "type": "refresh"},
        secret_key,
        algorithm=Algorithm,
    )
    return token


def verify_resfresh_token(r_token: str):
    try:
        payload = jwt.decode(r_token, secret_key, algorithms=[Algorithm])
        if payload.get("type") != "refresh":
            return None
        return payload.get("user_id")
    except JWTError:
        return None


