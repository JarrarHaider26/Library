from cachetools import TTLCache

user_cache = TTLCache(maxsize=60,ttl=60)

book_cache =TTLCache(maxsize=60,ttl=60)
