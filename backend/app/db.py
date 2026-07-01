from contextlib import contextmanager

import mysql.connector

from .config import settings


@contextmanager
def get_connection():
    connection = mysql.connector.connect(
        host=settings.mysql_host,
        port=settings.mysql_port,
        database=settings.mysql_database,
        user=settings.mysql_user,
        password=settings.mysql_password,
        autocommit=False,
    )
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
