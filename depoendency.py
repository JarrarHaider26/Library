from fastapi.security import OAuth2PasswordBearer
from jose import jwt,JWTError
from fastapi import Depends,HTTPException
from sqlalchemy.orm import Session
from auth import secret_key,Algorithm
auth = OAuth2PasswordBearer(tokenUrl="/login")

def get_current_user(token:str=Depends(auth)):
    try:

        payload = jwt.decode(token,secret_key,algorithms=[Algorithm])
        user_id = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=404,detail="user_not_found")

        return user_id

    except JWTError:
        return None

    

    


