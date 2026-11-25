from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from cache.cache import book_cache
from database.database import get_db
from dependencies import get_current_user
from models.model import book
from schemas.request import books
from schemas.response import bookresponse

router = APIRouter(tags=["Book_routes"])


@router.post("/books", response_model=bookresponse)
def create_book(boo: books, user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    existing_book = (
        db.query(book)
        .filter(book.title == boo.title, book.author == boo.author, book.user_id == user_id)
        .first()
    )
    if existing_book:
        raise HTTPException(status_code=400, detail="BOOK Already exist")

    new_book = book(title=boo.title, author=boo.author, user_id=user_id)
    db.add(new_book)
    db.commit()
    db.refresh(new_book)
    return new_book


@router.get("/books/{book_id}", response_model=bookresponse)
def read_book(book_id: int, user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    cache_key = f"user_{user_id}_book_{book_id}"
    if cache_key in book_cache:
        return book_cache[cache_key]

    existing_book = db.query(book).filter(book.id == book_id, book.user_id == user_id).first()
    if not existing_book:
        raise HTTPException(status_code=404, detail="Book not Found")

    book_cache[cache_key] = existing_book
    return existing_book


@router.put("/books/{book_id}", response_model=bookresponse)
def update_book(boo: books, book_id: int, user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    existing_book = db.query(book).filter(book.id == book_id, book.user_id == user_id).first()
    if not existing_book:
        raise HTTPException(status_code=404, detail="BOOK not Found")

    existing_book.author = boo.author
    existing_book.title = boo.title
    db.add(existing_book)
    db.commit()
    db.refresh(existing_book)

    cache_key = f"user_{user_id}_book_{book_id}"
    book_cache.pop(cache_key, None)
    return existing_book


@router.delete("/books/{book_id}")
def delete_book(book_id: int, user_id: int = Depends(get_current_user), db: Session = Depends(get_db)):
    existing_book = db.query(book).filter(book.id == book_id, book.user_id == user_id).first()
    if not existing_book:
        raise HTTPException(status_code=404, detail="BOOK not found")

    db.delete(existing_book)
    db.commit()

    cache_key = f"user_{user_id}_book_{book_id}"
    book_cache.pop(cache_key, None)
    return {"msg": "BOOK deleted"}

