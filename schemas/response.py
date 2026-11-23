from pydantic import BaseModel

class userresponse(BaseModel):
    id:int
    name:str
    model_config = {"from_attributes": True}

class login_response(BaseModel):
    access_token:str
    refresh_token:str
    model_config = {"from_attributes": True}


class bookresponse(BaseModel):
    id:int
    title:str
    author:str
    model_config = {"from_attributes": True}

class BorrowResponse(BaseModel):
    id: int
    user_id: int
    book_id: int

    model_config = {"from_attributes": True}



