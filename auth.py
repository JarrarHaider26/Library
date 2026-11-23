import os
from datetime import datetime, timedelta

from dotenv import load_dotenv
from fastapi import HTTPException
from jose import JWTError, jwt
from passlib.context import CryptContext

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

secret_key: str = os.getenv("SECRET_KEY") or os.getenv("secret_key") or "mysecretkey"
Algorithm = os.getenv("ALGORITHM") or os.getenv("Algorithm") or "HS256"


def hash_pass(pas:str):
    return pwd_context.hash(pas)

def verify_pass(pas:str,hash_pass:str):
    return pwd_context.verify(pas,hash_pass)

def create_access_token(user_id:int):
    expire = datetime.utcnow()+timedelta(minutes=5)

    token = jwt.encode({"user_id":user_id,"exp":expire},secret_key,algorithm=Algorithm)
    return token

def create_refresh_token(user_id:int):
    expire = datetime.utcnow()+timedelta(minutes=5)
    token  = jwt.encode({"user_id":user_id,"exp":expire,"type":"refresh"},secret_key,algorithm=Algorithm)
    return token

def verify_resfresh_token(r_token:str):
    try:

        payload = jwt.decode(r_token,secret_key,algorithms=[Algorithm])
        if payload.get("type")!="refresh":
            return None
        user_id = payload.get("user_id")
        return user_id

    except JWTError:
        return None

    
