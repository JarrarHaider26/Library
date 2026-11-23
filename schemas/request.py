from pydantic import BaseModel


class users(BaseModel):
    name:str
    password:str

class books(BaseModel):
    title:str
    author:str
    

class BorrowCreate(BaseModel):
    user_id: int
    book_id: int