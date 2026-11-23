from models.model import user
from schemas.request import users
from schemas.response import userresponse
from sqlalchemy.orm import Session
from cache.cache import user_cache
from fastapi import Depends,HTTPException
from auth import hash_pass
from fastapi import APIRouter
from database.database import get_db
from depoendency import get_current_user

router = APIRouter(tags=["users_routes"])

@router.get("/user",response_model=userresponse)
def read_user(user_id:int=Depends(get_current_user),db:Session=Depends(get_db)):
    cache_key=f"user_id{user_id}"
    if cache_key in user_cache:
        return user_cache[cache_key]
    existing_user=db.query(user).filter(user.id==user_id).first()
    if not existing_user:
        raise HTTPException(status_code=404,detail="User not Found")

    user_cache[cache_key]=existing_user

    return existing_user



@router.put("/user",response_model=userresponse)
def update_user(use:users,user_id:int=Depends(get_current_user),db:Session=Depends(get_db)):
    existing_user=db.query(user).filter(user.id==user_id).first()
    if not existing_user:
        raise HTTPException(status_code=404,detail="User not Found")

    existing_user.name=use.name
    existing_user.password=hash_pass(use.password)

    db.add(existing_user)
    db.commit()
    db.refresh(existing_user)

    cache_key=f"user_id{user_id}"
    user_cache.pop(cache_key,None)

    return existing_user


@router.delete("/delete")
def delete(user_id:int=Depends(get_current_user),db:Session=Depends(get_db)):
    existing_user = db.query(user).filter(user.id==user_id).first()
    if not existing_user:
        raise HTTPException(status_code=404,detail="user not found")

    db.delete(existing_user)
    db.commit()

    cache_key=f"user_id{user_id}"
    user_cache.pop(cache_key,None)

    return{"msg":"User deleted"}

