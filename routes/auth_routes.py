from fastapi import APIRouter, Body, Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from auth import create_access_token, create_refresh_token, hash_pass, verify_pass, verify_resfresh_token
from database.database import get_db
from models.model import user
from ratelimiting.rate_limiting import limiter
from schemas.request import users
from schemas.response import login_response, userresponse

router = APIRouter(tags=["Authentication"])


@router.post("/register", response_model=userresponse)
def create_user(use: users, db: Session = Depends(get_db)):
    existing_user = db.query(user).filter(user.name == use.name).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="user Already exist")

    new_use = user(name=use.name, password=hash_pass(use.password))
    db.add(new_use)
    db.commit()
    db.refresh(new_use)
    return new_use


@router.post("/login", response_model=login_response)
@limiter.limit("5/minute")
def login(request: Request, use: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    existing_user = db.query(user).filter(user.name == use.username).first()
    if not existing_user or not verify_pass(use.password, existing_user.password):
        raise HTTPException(status_code=401, detail="invalid username or password")

    token = create_access_token(existing_user.id)
    r_token = create_refresh_token(existing_user.id)
    return {"access_token": token, "refresh_token": r_token}


@router.post("/refresh")
def refresh_access_token(r_token: str = Body(..., embed=True)):
    use_id = verify_resfresh_token(r_token)
    if use_id is None:
        raise HTTPException(status_code=401, detail="invalid or expired refresh token")

    new_access_token = create_access_token(use_id)
    return {"access_token": new_access_token}


