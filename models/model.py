from sqlalchemy import ForeignKey
from sqlalchemy.orm import mapped_column,Mapped
from database.database import Base


class user(Base):
    __tablename__ = "user"

    id:Mapped[int]=mapped_column(primary_key=True)
    name:Mapped[str]=mapped_column()
    password:Mapped[str]=mapped_column()

class book(Base):
    __tablename__= "book"

    id:Mapped[int]=mapped_column(primary_key=True)
    title:Mapped[str]=mapped_column(unique=True)
    author:Mapped[str]=mapped_column()
    user_id:Mapped[int]=mapped_column(ForeignKey("user.id"))

class borrow(Base):
    __tablename__= "borrow"

    id:Mapped[int]=mapped_column(primary_key=True)
    user_id:Mapped[int]=mapped_column(ForeignKey("user.id"))
    book_id:Mapped[int]=mapped_column(ForeignKey("book.id"))

